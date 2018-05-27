"""Activity for updating conda-forge feedstocks."""
import os
import re
import sys

from xonsh.tools import print_color

from rever import vcsutils
from rever import github
from rever.activity import Activity
from rever.tools import eval_version, indir, hash_url, replace_in_file


def feedstock_url(feedstock, protocol='ssh'):
    """Returns the URL for a conda-forge feedstock."""
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
        url = 'http://github.com/conda-forge/' + feedstock + '.git'
    elif protocol == 'https':
        url = 'https://github.com/conda-forge/' + feedstock + '.git'
    elif protocol == 'ssh':
        url = 'git@github.com:conda-forge/' + feedstock + '.git'
    else:
        msg = 'Unrecognized github protocol {0!r}, must be ssh, http, or https.'
        raise ValueError(msg.format(protocol))
    return url


def feedstock_repo(feedstock):
    """Gets the name of the feedstock repository."""
    if feedstock is None:
        repo = $PROJECT + '-feedstock'
    else:
        repo = feedstock
    repo = repo.rsplit('/', 1)[-1]
    if repo.endswith('.git'):
        repo = repo[:-4]
    return repo


def fork_url(feedstock_url, username):
    """Creates the URL of the user's fork."""
    beg, end = feedstock_url.rsplit('/', 1)
    beg = beg[:-11]  # chop off 'conda-forge'
    url = beg + username + '/' + end
    return url


DEFAULT_PATTERNS = (
    # filename, pattern, new
    # set the version
    ('meta.yaml', '  version:\s*[A-Za-z0-9._-]+', '  version: "$VERSION"'),
    ('meta.yaml', '{% set version = ".*" %}', '{% set version = "$VERSION" %}'),
    # reset the build number to 0
    ('meta.yaml', '  number:.*', '  number: 0'),
    # set the hash
    ('meta.yaml', '{% set $HASH_TYPE = "[0-9A-Fa-f]+" %}',
                  '{% set $HASH_TYPE = "$HASH" %}'),
    ('meta.yaml', '  $HASH_TYPE:\s*[0-9A-Fa-f]+', '  $HASH_TYPE: $HASH'),
    )


class CondaForge(Activity):
    """Updates conda-forge feedstocks.

    The behaviour of this activity may be adjusted through the following
    environment variables:

    :$CONDA_FORGE_FEEDSTOCK: str or None, feedstock name or URL,
        default ``$PROJECT-feedstock``.
    :$CONDA_FORGE_PROTOCOL: str, one of ``'ssh'``, ``'http'``, or ``'https'``
        that specifies how the activity should interact with github when
        cloning, pulling, or pushing to the feedstock repo. Note that
        ``'ssh'`` requires you to have an SSH key registered with github.
        The default  is ``'ssh'``.
    :$CONDA_FORGE_SOURCE_URL: str, the URL that the recipe will use to
        download the source code. This is needed so that we may update the
        hash of the downloaded file. This string is evaluated with the current
        environment. Default
        ``'https://github.com/$GITHUB_ORG/$GITHUB_REPO/archive/$VERSION.tar.gz'``.
    :$CONDA_FORGE_HASH_TYPE: str, the type of hash that the recipe uses, eg
        ``'md5'`` or ``'sha256'``. Default ``'sha256'``.
    :$CONDA_FORGE_PATTERNS: list or 3-tuples of str, this is list of
        (filename, pattern-regex, replacement) tuples that is evaluated
        inside of the recipe directory. This is similar to the version bump
        pattern structure. Both the pattern-regex str and the replacement str
        will have environment variables expanded. The following environment
        variables are added for this evaluation:

        * ``$SOURCE_URL``: the fully expanded source code URL.
        * ``$HASH_TYPE``: the hash type used to hash ``$SOURCE_URL``.
        * ``$HASH``: the hexdigest of ``$SOURCE_URL``.

        The default patterns match most standard recipes.
    :$CONDA_FORGE_PULL_REQUEST: bool, whether the activity should open
        a pull request to the upstream conda-forge feestock, default True.
    :$CONDA_FORGE_RERENDER: bool, whether the activity should rerender the
        feedstock using conda-smithy, default True.
    :$CONDA_FORGE_FORK: bool, whether the activity should create a new fork of
        the feedstock if it doesn't exist already, default True.
    :$CONDA_FORGE_FORK_ORG: str, the org to fork the recipe to or which holds
        the fork, if ``''`` use the registered gh username, defaults to ``''``

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

    def __init__(self, *, deps=frozenset(('tag', 'push_tag'))):
        super().__init__(name='conda_forge', deps=deps, func=self._func,
                         desc="Updates conda-forge feedstocks")

    def _func(self, feedstock=None, protocol='ssh', source_url=None,
              hash_type='sha256', patterns=DEFAULT_PATTERNS,
              pull_request=True, rerender=True, fork=True,
              fork_org=''):
        if source_url is None:
            version_tag = ${...}.get('TAG_TEMPLATE', $VERSION)
            if version_tag + '.tar.gz' in os.listdir($REVER_DIR):
                source_url=('https://github.com/$GITHUB_ORG/$GITHUB_REPO'
                            '/releases/download/{}/'
                            '{}.tar.gz'.format(version_tag, version_tag))
            else:
                source_url = ('https://github.com/$GITHUB_ORG/$GITHUB_REPO/'
                              'archive/{}.tar.gz'.format(version_tag))

        # first, let's grab the feedstock locally
        gh, username = github.login(return_username=True)
        upstream = feedstock_url(feedstock, protocol=protocol)
        origin = fork_url(upstream, username)
        feedstock_reponame = feedstock_repo(feedstock)

        if pull_request or fork:
            repo = gh.repository('conda-forge', feedstock_reponame)

        # Check if fork exists
        if fork:
            fork_repo = gh.repository(fork_org or username, feedstock_reponame)
            if fork_repo is None or (hasattr(fork_repo, 'is_null') and
                                     fork_repo.is_null()):
                print("Fork doesn't exist creating feedstock fork...",
                      file=sys.stderr)
                if fork_org:
                    repo.create_fork(fork_org)
                else:
                    repo.create_fork()

        feedstock_dir = os.path.join($REVER_DIR, $PROJECT + '-feedstock')
        recipe_dir = os.path.join(feedstock_dir, 'recipe')
        if not os.path.isdir(feedstock_dir):
            p = ![git clone @(origin) @(feedstock_dir)]
            if p.rtn != 0:
                msg = 'Could not clone ' + origin
                msg += '. Do you have a personal fork of the feedstock?'
                raise RuntimeError(msg)
        with indir(feedstock_dir):
            # make sure feedstock is up-to-date with origin
            git checkout master
            git pull @(origin) master
            # make sure feedstock is up-to-date with upstream
            git pull @(upstream) master
            # make and modify version branch
            with ${...}.swap(RAISE_SUBPROC_ERROR=False):
                git checkout -b $VERSION master or git checkout $VERSION
        # now, update the feedstock to the new version
        source_url = eval_version(source_url)
        hash = hash_url(source_url)
        with indir(recipe_dir), ${...}.swap(HASH_TYPE=hash_type, HASH=hash,
                                            SOURCE_URL=source_url):
            for f, p, n in patterns:
                p = eval_version(p)
                n = eval_version(n)
                replace_in_file(p, n, f)
        with indir(feedstock_dir), ${...}.swap(RAISE_SUBPROC_ERROR=False):
            git commit -am @("updated v" + $VERSION)
            if rerender:
                print_color('{YELLOW}Rerendering the feedstock{NO_COLOR}',
                            file=sys.stderr)
                conda smithy rerender -c auto
            git push --set-upstream @(origin) $VERSION
        # lastly make a PR for the feedstock
        if not pull_request:
            return
        print('Creating conda-forge feedstock pull request...', file=sys.stderr)
        title = $PROJECT + ' v' + $VERSION
        head = username + ':' + $VERSION
        body = ('Merge only after success.\n\n'
                'This pull request was auto-generated by '
                '[rever](https://regro.github.io/rever-docs/)')
        pr = repo.create_pull(title, 'master', head, body=body)
        if pr is None:
            print_color('{RED}Failed to create pull request!{NO_COLOR}')
        else:
            print_color('{GREEN}Pull request created at ' + pr.html_url + \
                        '{NO_COLOR}')
