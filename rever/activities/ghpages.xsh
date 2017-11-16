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
    """Activity for pushing documentation up to GitHub pages."""

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
            # check if changes are needed
            p = !(git diff --exit-code)            # check for unstaged changes
            q = !(git diff --cached --exit-code)   # check for staged changes
            if p.rtn == 0 and q.rtn == 0:
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
