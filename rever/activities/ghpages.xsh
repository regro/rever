"""Activity for pushing documentation to GitHub pages."""
import os
from distutils.dir_util import copy_tree
from distutils.file_util import copy_file

from xonsh.tools import expand_path, print_color

from rever.tools import indir
from rever.activity import Activity


def branch_name(repo, branch=None):
    """Computes the gh-pages branch name for a repo."""
    if branch:
        return branch
    org, _, repo = repo.rpartition('/')
    if repo.endswith('.git'):
        repo = repo[:-4]
    _, _, org = org.rpartition('/')
    _, _, org = org.rpartition(':')
    if (org + '.github.io' == repo) or (org + '.github.com') == repo:
        branch = 'master'
    else:
        branch = 'gh-pages'
    return branch


DEFAULT_COPY = (
    ('$SPHINX_HOST_DIR/html', '$GHPAGES_REPO_DIR'),
    ('$REVER_DIR/sphinx-build/html', '$GHPAGES_REPO_DIR'),
    )


def expand_copy(copy):
    """Expands a list or (src, dst) tuples into a deduplicated list where
    the src is guaranteed to exist, and src and dst are returned as absolute
    paths.
    """
    pairs = set()
    for src, dst in copy:
        src = os.path.abspath(expand_path(src))
        if not os.path.exists(src):
            continue
        dst = os.path.abspath(expand_path(dst))
        pairs.add((src, dst))
    return sorted(pairs)


class GHPages(Activity):
    """Activity for pushing documentation up to GitHub pages.

    This activity uses the following environment variable:

    :$GHPAGES_REPO: str, the URL of the GitHUb pages repository.
    :$GHPAGES_BRANCH: str, the GitHub pages branch name, i.e. either
        ``gh-pages`` or ``master``.  If not provided, the activity will
        attempt to deduce it from the repo name.
    :$GHPAGES_COPY: list or str 2-tuples, This is a list of (src, dst)
        pairs of files to copy from the project into the gh-pages repo.
        These pairs will have environment variables expanded and it is
        evaluated in the current directory (where rever was run from).
        src files or directories that don't exist will be skipped.
        After variable expansion, this list will be deduplicated.
        Additionally, the environment variable ``$GHPAGES_REPO_DIR``
        is added to allow easy access to the local clone of the
        repo, which is at ``$REVER_DIR/ghpages-repo``. By default,
        this will look in the sphinx html directory created by the
        sphinx activity.
    """

    def __init__(self):
        super().__init__(name='ghpages', deps=frozenset(),
                         func=self._func, desc="Pushes docs up to GitHub pages.")

    def _func(self, repo, branch=None, copy=DEFAULT_COPY):
        repo_dir = $GHPAGES_REPO_DIR = os.path.join($REVER_DIR, 'ghpages-repo')
        branch = branch_name(repo, branch=branch)
        if not os.path.isdir(repo_dir):
            ![git clone @(repo) @(repo_dir)]
        copy = expand_copy(copy)
        with indir(repo_dir):
            git checkout @(branch)
            git pull @(repo) @(branch)
            for src, dst in copy:
                msg = '{CYAN}Copying{NO_COLOR} from ' + src + ' {GREEN}->{NO_COLOR} ' + dst
                print_color(msg)
                if os.path.isdir(src):
                    copy_tree(src, dst, preserve_symlinks=1, verbose=1)
                else:
                    copy_file(src, dst, verbose=1)
            # check if a commit is needed
            with ${...}.swap(RAISE_SUBPROC_ERROR=False) as env:
                # check for unstaged changes
                p = !(git diff --exit-code --quiet).rtn
                # check for staged changes
                q = !(git diff --cached --exit-code --quiet).rtn
            if p == 0 and q == 0:
                msg = ('{YELLOW}no changes made to GitHub pages repo, already '
                       'up-to-date.{NO_COLOR}')
                print_color(msg)
                return
            # now update the repo and push the changes
            # no need to use vcsutils here since we know we must be using git
            git add .
            msg = "GitHub pages update for " + $VERSION
            git commit -am @(msg)
            git push @(repo) @(branch)
