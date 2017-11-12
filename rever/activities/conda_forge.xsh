"""Activity for updating conda-forge feedstocks."""
import re
import sys

from rever import vcsutils
from rever import github
from rever.activity import Activity
from rever.tools import eval_version, indir, hash_url


def feedstock_url(feedstock, protocol='ssh'):
    """Returns the URL for a conda-forge feedstock."""
    if feedstock is None:
        feedstock = $PROJECT + '-feedstock.git'
    elif feedstock.startswith('https://github.com/')
        return feedstock
    elif feedstock.startswith('git@github.com:')
        return feedstock
    protocol = protocol.lower()
    if protocol == 'http':
        url = 'http://github.com/conda-forge/' + feedstock
    elif protocol == 'https':
        url = 'https://github.com/conda-forge/' + feedstock
    elif protocol == 'ssh':
        url = 'git@github.com:conda-forge/' + feedstock
    else:
        msg = 'Unrecognized github protocol {0!r}, must be ssh, http, or https.'
        raise ValueError(msg.format(protocol))
    return url


def feedstock_repo(feedstock):
    if feedstock is None:
        repo = $PROJECT + '-feedstock'
    else:
        repo = feedstock
    repo = repo.rsplit('/', 1)[-1]
    if repo.endswith('.git'):
        repo = repo[:-4]
    return repo


DEFAULT_PATTERNS = (
    # filename, pattern, new
    ('meta.yaml', '  version:[^{]*', '  version: "$VERSION"'),
    ('meta.yaml', '{% set version = ".*" %}', '{% set version = "$VERSION" %}'),
    ('meta.yaml', '  build:.*', '  build: 0'),
    ('meta.yaml', '{% set $HASH_TYPE = "[0-9A-Fa-f]+" %}',
                  '{% set $HASH_TYPE = "$HASH" %}'),
    ('meta.yaml', '  $HASH_TYPE:\s*[0-9A-Fa-f]+', '  $HASH_TYPE: $HASH'),
    )


class CondaForge(Activity):
    """Updates conda-forge feedstocks.
    """

    def __init__(self, *, deps=frozenset(('version_bump', 'changelog'))):
        super().__init__(name='conda_forge', deps=deps, func=self._func,
                         desc="Updates conda-forge feedstocks")

    def _func(self, feedstock=None, protocol='ssh',
              source_url=('https://github.com/$GITHUB_ORG/$GITHUB_REPO/archive/'
                          '$VERSION.tar.gz'),
              hash_type='sha256', patterns=DEFAULT_PATTERNS):
        # first, let's grab the feedstock locally
        origin = feedstock_url(feedstock, protocol=protocol)
        feedstock_dir = os.path.join($REVER_DIR, 'feedstock')
        recipe_dir = os.path.join(feedstock_dir, 'recipe')
        if not os.path.isdir(feedstock_dir):
            git clone @(origin) @(feedstock)
        with indir(feedstock_dir):
            # make sure feedstock is up to date
            git checkout master
            git pull @(origin) master
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
            git push --set-upstream @(origin) $VERSION
        # lastly make a PR for the feedstock
        gh = github.login()
        feedstock_reponame = feedstock_repo(feedstock)
        repo = gh.repository('conda-forge', feedstock_reponame)
        print('Creating conda-forge feedstock pull request...', file=sys.stderr)
        title = $PROJECT + ' v' + ver
        head = 'conda-forge:' + $VERSION
        body = 'Merge only after success.'
        pr = repo.create_pull(title, 'master', head, body=body)
        if pr is None:
            print_color('{RED}Failed to create pull request!{NO_COLOR}')
        else:
            print_color('{GREEN}Pull request created at ' + pr.html_url + \
                        '{NO_COLOR}')
