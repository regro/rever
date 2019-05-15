"""Some version control utilities for rever"""
import os
import re
import datetime

from lazyasd import lazyobject
from xonsh.lib.os import rmtree, indir


def make_vcs_dispatcher(vcsfuncs, name='vcs_dispatcher',
                        doc='dispatches to a version control function',
                        err='no func for handling the version contol system !{r}'):
    """Creates a function that dispatches to different version control systems,
    depending on the users setting for $REVER_VCS.

    Parameters
    ----------
    vcsfuncs : dict
        Maps the string names of version control systems (e.g. 'git' or 'hg') to
        a function for handling that particular action.
    name : str, optional
        Dispatcher funtion name.
    doc : str, optional
        Doctring for the dispatcher.
    err : str, optional
        Error message if the version control system name is not found in vcsfuncs.
        This is formatted with the value of $REVER_VCS.

    Returns
    -------
    vcs_dispatcher : function
    """
    def vcs_dispatcher(*args, **kwargs):
        func = vcsfuncs.get($REVER_VCS, None)
        if func is None:
            raise RuntimeError(err.format($REVER_VCS))
        return func(*args, **kwargs)
    vcs_dispatcher.__name__ = name
    vcs_dispatcher.__doc__ = doc
    return vcs_dispatcher


def git_current_branch():
    """Returns the current branch for git"""
    return $(git rev-parse --abbrev-ref HEAD).strip()


CURRENT_BRANCH = {'git': git_current_branch}
current_branch = make_vcs_dispatcher(CURRENT_BRANCH, name='current_branch',
    doc="Returns the current branch for the user's version control system.",
    err = 'no way to get the branch for version control system {!r}')


def git_current_rev():
    """Obtains the current git revison hash for storage and rewinding purposes."""
    return $(git rev-parse HEAD).strip()


CURRENT_REV = {'git': git_current_rev}
current_rev = make_vcs_dispatcher(CURRENT_REV, name='current_rev',
    doc="Returns the current revision for the user's version control system.",
    err = 'no way to get the revision for version control system {!r}')


def git_reset_hard(rev):
    """Performs a git reset --hard to a revision."""
    git reset --hard @(rev)


REWIND = {'git': git_reset_hard}
rewind = make_vcs_dispatcher(REWIND, name='rewind',
    doc="Returns the version control system to a previous state.",
    err = 'no way to rewind the version control system {!r}')


def git_merge(src, into):
    """Merges commits from a src branch into another branch."""
    curr = git_current_branch()
    if curr != into:
        git_checkout(into)
    git merge --no-ff @(src)
    if curr != into:
        git_checkout(curr)


MERGE = {'git': git_merge}
merge = make_vcs_dispatcher(MERGE, name='merge',
    doc="Merges one revision into another.",
    err = 'no way to merge for {!r}')


def git_checkout(rev):
    """Checks out a branch name, tag, or other revision."""
    git checkout @(rev)


CHECKOUT = {'git': git_checkout}
checkout = make_vcs_dispatcher(CHECKOUT, name='checkout',
    doc="Checks out a revision.",
    err = 'no way to checkout for {!r}')


def git_tag(tag):
    """Tags the current head, forcibly."""
    git tag -f @(tag)

TAG = {'git': git_tag}
tag = make_vcs_dispatcher(TAG, name='tag',
    doc="Tags the current head.",
    err = 'no way to tag for {!r}')


def git_track(files):
    """Adds a list of files to the repo."""
    git add @(files)


TRACK = {'git': git_track}
track = make_vcs_dispatcher(TRACK, name='track',
    doc="Specify files to track in the repo.",
    err = 'no way to track files for {!r}')


def git_commit(message="Rever commit"):
    """Commits to the repo."""
    git commit --allow-empty -am @(message)


COMMIT = {'git': git_commit}
commit = make_vcs_dispatcher(COMMIT, name='commit',
    doc="Commits a revision to the repo.",
    err = 'no way to commit for {!r}')


def git_push(remote, target):
    """Pushes up to a remote and target branch"""
    args = [remote, target]
    if $REVER_FORCED:
        args.insert(0, '--force')
    git push @(args)


push = make_vcs_dispatcher({'git': git_push},
    name='push',
    doc="Pushes up to a remote URL a target branch or revision.",
    err = 'no way to push for {!r}')


def git_push_tags(remote):
    """Pushes up tags to a remote"""
    args = [remote]
    if $REVER_FORCED:
        args.insert(0, '--force')
    git push --tags @(args)


push_tags = make_vcs_dispatcher({'git': git_push_tags},
    name='push_tags',
    doc="Pushes up tags to a remote URL.",
    err = 'no way to push tags for {!r}')


def git_del_tag(tag):
    """Deletes a tag from the local repo"""
    git tag -d @(tag)


del_tag = make_vcs_dispatcher({'git': git_del_tag},
    name='del_tag',
    doc="Deletes a tag from the local repository.",
    err = 'no way to remove a tag for {!r}')


def git_del_remote_tag(tag, remote):
    """Deletes a tag from a remote repo"""
    refspec = ':refs/tags/' + tag
    git push @(remote) @(refspec)


del_remote_tag = make_vcs_dispatcher({'git': git_del_remote_tag},
    name='del_remote_tag',
    doc="Deletes a tag from the remote repository.",
    err = 'no way to remove a remote tag for {!r}')


def git_latest_tag():
    """Returns the most recent tag in the repo."""
    tag = $(git describe --abbrev=0 --tags)
    return tag.strip()


latest_tag = make_vcs_dispatcher({'git': git_latest_tag},
    name='latest_tag',
    doc="Returns the most recent tag in the repo.",
    err = 'no way to find the most recent tag for {!r}')


def git_root():
    """Returns the root repository directory from git"""
    root = $(git rev-parse --show-toplevel)
    return root.strip()


root = make_vcs_dispatcher({'git': git_root},
    name='root',
    doc="Returns the root repository directory.",
    err = 'no way to find the root repository directory from {!r}')


def git_authors_emails():
    """Returns a set of (author, email) tuples"""
    lines = $(git log "--format=%aN<%aE>").strip().splitlines()
    tups = {line[:-1].partition('<')[::2] for line in lines}
    return tups


authors_emails = make_vcs_dispatcher({'git': git_authors_emails},
    name='authors_emails',
    doc="Returns a set of (author, email) tuples",
    err='no way to compute the author/email combos from {!r}')


@lazyobject
def RE_GIT_CPA():
    return re.compile(r"\s+(\d+)\s+(.*)")


def git_commits_per_author(since=None):
    """Returns a dictionary mapping author names to commits"""
    cpa = {}
    args = ['-s', '-e', '--no-merges']
    if since:
        args.append(since + "...HEAD")
    for line in $(git shortlog @(args)).splitlines():
        m = RE_GIT_CPA.match(line)
        if m is None:
            continue
        n, name = m.groups()
        cpa[name] = int(n)
    return cpa


commits_per_author = make_vcs_dispatcher({'git': git_commits_per_author},
    name='commits_per_author',
    doc="Returns a dictionary mapping author names to commits",
    err='no way to compute the author commits from {!r}')


@lazyobject
def RE_GIT_CPE():
    return re.compile(r"\s+(\d+)\s+[^<]*<([^>]*)>")


def git_commits_per_email(since=None):
    """Returns a dictionary mapping emails to commits.
    Accepts a "since" argument, which specifies the lower boundary.
    """
    cpe = {}
    args = ['-s', '-e', '--no-merges']
    if since:
        args.append(since + "...HEAD")
    for line in $(git shortlog @(args)).splitlines():
        n, email = RE_GIT_CPE.match(line).groups()
        cpe[email] = int(n)
    return cpe


commits_per_email = make_vcs_dispatcher({'git': git_commits_per_email},
    name='commits_per_email',
    doc="Returns a dictionary mapping emails to commits",
    err='no way to compute the email commits from {!r}')


def git_first_commit_per_email():
    """Returns a dictionary mapping emails to the datetime of its first commit"""
    fcpe = {}
    for line in $(git log --encoding=utf-8 --full-history --reverse "--format=format:%ae:%at").splitlines():
        email, _, t = line.rpartition(':')
        if '@' not in email:
            # not a real email address
            continue
        elif not t:
            # appearently, you can have a commit without a timestamp
            continue
        elif email not in fcpe:
            fcpe[email] = datetime.datetime.fromtimestamp(int(t))
    return fcpe


first_commit_per_email = make_vcs_dispatcher({'git': git_first_commit_per_email},
    name='first_commit_per_email',
    doc="Returns a dictionary mapping emails to the datetime of its first commit",
    err='no way to compute the email first commits from {!r}')


def git_have_push_permissions(remote):
    """Checks that we have push permission to a remote repository."""
    tempd = os.path.join($REVER_DIR, 'git-have-push-perm')
    if os.path.exists(tempd):
        rmtree(tempd, force=True)
    ![git init @(tempd)]
    with indir(tempd):
        try:
            ![git checkout -b __rever__]
            ![git commit --allow-empty -m 'Checking rever permissions']
            ![git push --force @(remote) __rever__:__rever__]
            ![git push --force @(remote) :__rever__]
        except Exception:
            return False
    rmtree(tempd, force=True)
    return True


have_push_permissions = make_vcs_dispatcher({'git': git_have_push_permissions},
    name='have_push_permissions',
    doc="Checks that we have push permission to a remote repository.",
    err='Cannot tell if we have push permisions from {!r}')
