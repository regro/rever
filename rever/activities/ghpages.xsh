"""Activity for pushing documentation to GitHub pages."""
import os
from distutils.dir_util import copy_tree
from distutils.file_util import copy_file

from xonsh.tools import expand_path

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
    ('$SPHINX_HOST_DIR/html', '.'),
    ('$REVER_DIR/sphinx-build/html', '.'),
    )


def expand_copy(copy):
    """Expands a list or (src, dst) tuples into a deduplicated list where
    the src is guaranteed to exist, and src and dst are returned as absolute
    paths.
    """
    pairs = set()
    for src, dst in copy:
        src = os.path.abspath(expand_path(src))
        if not os.path.exist(src):
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
        repo_dir = os.path.join($REVER_DIR, 'ghpages-repo')
        branch = branch_name(branch)
        if not os.path.isdir(repo_dir):
            ![git clone @(repo) @(repo_dir)]
        with indir(repo_dir):
            git checkout @(branch)
            git pull @(repo) @(branch)
            copy = expand_copy(copy)
            for src, dst in copy:
                if os.path.isdir(src):
                    copy_tree(src, dst, preserve_symlinks=True, verbose=True)
                else:
                    copy_file(src, dst, verbose=True)
            # no need to use vcsutils here since we know we must be using git
            git add .
            msg = "GitHub pages update for " + $VERSION
            git commit -am @(msg)
            git push @(repo) @(branch)
