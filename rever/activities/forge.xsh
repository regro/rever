"""Activity for updating a forge feedstock."""
import os
import sys

from lazyasd import lazyobject
from xonsh.tools import print_color

from rever import vcsutils
from rever import github
from rever.activity import Activity
from rever.tools import eval_version, indir, hash_url, replace_in_file


@lazyobject
def github3():
    import github3 as gh3
    return gh3


def get_feedstock_url(feedstock, feedstock_org, protocol='ssh'):
    """Returns the URL for a forge feedstock."""
    if feedstock is None:
        feedstock = $PROJECT + '-feedstock'
    elif feedstock.startswith('http://github.com/'):
        return feedstock
    elif feedstock.startswith('https://github.com/'):
        return feedstock
    elif feedstock.startswith('git@github.com:'):
        return feedstock

    protocol = protocol.lower()
    if protocol == 'http':
        url = 'http://github.com/{}/'.format(feedstock_org) + feedstock + '.git'
    elif protocol == 'https':
        url = 'https://github.com/{}/'.format(feedstock_org) + feedstock + '.git'
    elif protocol == 'ssh':
        url = 'git@github.com:{}/'.format(feedstock_org) + feedstock + '.git'
    else:
        msg = 'Unrecognized github protocol {0!r}, must be ssh, http, or https.'
        raise ValueError(msg.format(protocol))

    return url


def get_feedstock_repo_name(feedstock):
    """Gets the name of the feedstock repository."""
    if feedstock is None:
        repo = $PROJECT + '-feedstock'
    else:
        repo = feedstock
    repo = repo.rsplit('/', 1)[-1]
    if repo.endswith('.git'):
        repo = repo[:-4]
    return repo


def get_fork_url(feedstock_url, username, feedstock_org):
    """Creates the URL of the user's fork."""
    beg, end = feedstock_url.rsplit('/', 1)
    beg = beg.replace(feedstock_org, '')  # chop off `feedstock_org`
    url = beg + username + '/' + end
    return url


def get_source_url(source_url):
    # Get source url for the recipe
    if source_url is None:
        version_tag = ${...}.get('TAG_TEMPLATE', $VERSION)
        release_fn = $GITHUB_REPO + '-' + version_tag + '.tar.gz'
        if release_fn in os.listdir($REVER_DIR):
            source_url=('https://github.com/$GITHUB_ORG/$GITHUB_REPO'
                        '/releases/download/{}/{}'.format(
                        version_tag, release_fn))
        else:
            source_url = ('https://github.com/$GITHUB_ORG/$GITHUB_REPO/'
                        'archive/{}.tar.gz'.format(version_tag))
    return source_url


DEFAULT_PATTERNS = (
    # filename, pattern, new
    # set the version
    ('meta.yaml', r'  version:\s*[A-Za-z0-9._-]+', '  version: "$VERSION"'),
    ('meta.yaml', '{% set version = ".*" %}', '{% set version = "$VERSION" %}'),
    # reset the build number to 0
    ('meta.yaml', '  number:.*', '  number: 0'),
    # set the hash of the source url
    ('meta.yaml', '{% set $HASH_TYPE = "[0-9A-Fa-f]+" %}', '{% set $HASH_TYPE = "$HASH" %}'),
    ('meta.yaml', r'  $HASH_TYPE:\s*[0-9A-Fa-f]+', '  $HASH_TYPE: $HASH'),
)


class Forge(Activity):
    """Updates a forge feedstock.

    The behaviour of this activity may be adjusted through the following
    environment variables:

    :$FORGE_FEEDSTOCK: str or None, feedstock name or URL,
        default ``$PROJECT-feedstock``.
    :$FORGE_PROTOCOL: str, one of ``'ssh'``, ``'http'``, or ``'https'``
        that specifies how the activity should interact with github when
        cloning, pulling, or pushing to the feedstock repo. Note that
        ``'ssh'`` requires you to have an SSH key registered with github.
        The default  is ``'ssh'``.
    :$FORGE_SOURCE_URL: str, the URL that the recipe will use to
        download the source code. This is needed so that we may update the
        hash of the downloaded file. This string is evaluated with the current
        environment. Default
        ``'https://github.com/$GITHUB_ORG/$GITHUB_REPO/archive/$VERSION.tar.gz'``.
    :$FORGE_HASH_TYPE: str, the type of hash that the recipe uses, eg
        ``'md5'`` or ``'sha256'``. Default ``'sha256'``.
    :$FORGE_PATTERNS: list or 3-tuples of str, this is list of
        (filename, pattern-regex, replacement) tuples that is evaluated
        inside of the recipe directory. This is similar to the version bump
        pattern structure. Both the pattern-regex str and the replacement str
        will have environment variables expanded. The following environment
        variables are added for this evaluation (only if $FORGE_USE_GIT_URL is False):

        * ``$SOURCE_URL``: the fully expanded source code URL.
        * ``$HASH_TYPE``: the hash type used to hash ``$SOURCE_URL``.
        * ``$HASH``: the hexdigest of ``$SOURCE_URL``.

        The default patterns match most standard recipes.
    :$FORGE_PULL_REQUEST: bool, whether the activity should open
        a pull request to the upstream conda-forge feestock, default True.
    :$FORGE_RERENDER: bool, whether the activity should rerender the
        feedstock using conda-smithy, default True.
    :$FORGE_FEEDSTOCK_ORG: str, specify the feedstock organization. Must be set.
    :$FORGE_FORK: bool, whether the activity should create a new fork of
        the feedstock if it doesn't exist already, default True.
    :$FORGE_FORK_ORG: str, the org to fork the recipe to or which holds
        the fork, if ``''`` use the registered gh username, defaults to ``''``
    :$FORGE_USE_GIT_URL: bool, whether or not to use `git_url` in the recipe source
        url, default True.
    :$FORGE_RECIPE_DIR: str, the name of the recipe folder, default is 'recipe'.

    Other environment variables that affect the behavior are:

    :$GITHUB_CREDFILE: the credential file to use. This should NOT be
        set in the rever.xsh file
    :$GITHUB_ORG: the github organization that the project belongs to.
    :$GITHUB_REPO: the github repository of the project.
    :$TAG_TEMPLATE: str, the template string used to tag the version, by default
        this is '$VERSION'. Used to download project source.
    :$PROJECT: the name of the project being released.
    :$REVER_CONFIG_DIR: the user's config directory for rever, which
      is where the GitHub credential files are stored by default.

    """

    DEFAULT_PROTOCOL = 'ssh'
    DEFAULT_HASH_TYPE = 'sha256'
    DEFAULT_RECIPE_DIR = 'recipe'

    def __init__(self, *, deps=frozenset(('tag', 'push_tag')), **kwargs):
        requires = {"imports": {"github3.exceptions": "github3.py"},
                    "commands": {"conda": "conda", "conda-smithy": "conda-smithy"}}

        super().__init__(name='forge',
                         deps=deps,
                         func=self._func,
                         desc="Updates a forge feedstock",
                         requires=requires,
                         check=self.check_func)

    def _func(self,
              feedstock=None,
              feedstock_org=None,
              protocol=None,
              source_url=None,
              hash_type=None,
              patterns=None,
              pull_request=True,
              rerender=True,
              fork=True,
              fork_org=None,
              use_git_url=False,
              recipe_dir=None):

        if feedstock_org is None:
            raise ValueError("FORGE_FEEDSTOCK_ORG must be set.")

        # Default params
        protocol = protocol or Forge.DEFAULT_PROTOCOL
        hash_type = hash_type or Forge.DEFAULT_HASH_TYPE
        recipe_dir = recipe_dir or Forge.DEFAULT_RECIPE_DIR
        patterns = patterns or DEFAULT_PATTERNS

        # Login to github
        gh, username = github.login(return_username=True)

        # Get the upstream feedstock url
        feedstock_upstream = get_feedstock_url(feedstock=feedstock,
                                               feedstock_org=feedstock_org,
                                               protocol=protocol)

        # Get the name of the feedstock repository
        feedstock_repo_name = get_feedstock_repo_name(feedstock)

        # Get the feedstock repository url to work with (a fork or not).
        if fork:
            feedstock_origin = get_fork_url(feedstock_upstream, username, feedstock_org)
        else:
            feedstock_origin = feedstock_upstream

        # Get the feedstock Github repository
        if pull_request or fork:
            repo = gh.repository(feedstock_org, feedstock_repo_name)

        # Create the fork repository if required
        if fork:
            try:
                fork_repo = gh.repository(fork_org or username,
                                          feedstock_repo_name)
            except github3.exceptions.NotFoundError:
                fork_repo = None

            if fork_repo is None or (hasattr(fork_repo, 'is_null') and
                                     fork_repo.is_null()):
                print("Fork doesn't exist creating feedstock fork...",
                      file=sys.stderr)
                if fork_org:
                    repo.create_fork(fork_org)
                else:
                    repo.create_fork()

        # Get some paths
        feedstock_dir = os.path.join($REVER_DIR, feedstock_repo_name)
        recipe_dir = os.path.join(feedstock_dir, recipe_dir)

        # Clone the feedstock repository locally
        if not os.path.isdir(feedstock_dir):
            p = ![git clone @(feedstock_origin) @(feedstock_dir)]
            if p.rtn != 0:
                raise RuntimeError('Could not clone ' + feedstock_origin)

        # Prepare the local cloned feeedstock
        with indir(feedstock_dir):
            # Checkout to master and pull latest commits from feedstock upstream
            git checkout master
            git pull @(feedstock_origin) master
            git pull @(feedstock_upstream) master

            # Create a new branch if required
            if fork or pull_request:
                with ${...}.swap(RAISE_SUBPROC_ERROR=True):
                    git checkout -b $VERSION master or git checkout $VERSION

        # Get the source url and its hash if required
        if not use_git_url:
            # Get and eval the source url
            source_url = get_source_url(source_url)
            source_url = eval_version(source_url)

            # Get the hash of the source url
            source_url_hash = hash_url(source_url)
        else:
            source_url = None
            source_url_hash = None

        # Modify the files in the recipe folder (build number, version, hash, source_url, etc)
        with indir(recipe_dir), ${...}.swap(HASH_TYPE=hash_type,
                                            HASH=source_url_hash,
                                            SOURCE_URL=source_url):
            for f, p, n in patterns:
                p = eval_version(p)
                n = eval_version(n)
                replace_in_file(p, n, f)

        # Commit the changes
        with indir(feedstock_dir), ${...}.swap(RAISE_SUBPROC_ERROR=True):
            git commit -am @("Bump to " + $VERSION)

        # Regenerate the feedstock if required
        if rerender:
            with indir(feedstock_dir), ${...}.swap(RAISE_SUBPROC_ERROR=True):
                print_color('{YELLOW}Rerendering the feedstock{NO_COLOR}',
                            file=sys.stderr)
                conda smithy regenerate -c auto

        # Push changes
        with indir(feedstock_dir), ${...}.swap(RAISE_SUBPROC_ERROR=True):
            if fork or pull_request:
                git push --set-upstream @(feedstock_origin) $VERSION
            else:
                git push @(feedstock_origin) master

        # Make a pull request if required
        if pull_request:
            print('Creating conda-forge feedstock pull request...', file=sys.stderr)
            title = $PROJECT + ' ' + $VERSION

            if fork:
                head = fork_org or username + ':' + $VERSION
            else:
                head = feedstock_org + ':' + $VERSION

            body = ('Merge only after success.\n\n'
                    'This pull request was auto-generated by '
                    '[rever](https://regro.github.io/rever-docs/)')

            pr = repo.create_pull(title, 'master', head, body=body)

            if pr is None:
                print_color('{RED}Failed to create pull request!{NO_COLOR}')
            else:
                print_color('{GREEN}Pull request created at ' + pr.html_url + '{NO_COLOR}')

    def check_func(self):
        """Checks that we can rerender and login"""
        rerender = ![conda-smithy regenerate --check]
        return rerender and github.can_login()
