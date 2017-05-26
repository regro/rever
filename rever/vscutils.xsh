"""Some version control utilities for rever"""

def make_vsc_dispatcher(vcsfuncs, name='vsc_dispatcher',
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
    vsc_dispatcher : function
    """
    def vsc_dispatcher(*args, **kwargs):
        func = vcsfuncs.get($REVER_VCS, None)
        if func is None:
            raise RuntimeError(err.format($REVER_VCS))
        return func(*args, **kwargs)
    vsc_dispatcher.__name__ = name
    vsc_dispatcher.__doc__ = doc
    return vsc_dispatcher


def git_current_branch():
    """Returns the current branch for git"""
    return $(git rev-parse --abbrev-ref HEAD).strip()


CURRENT_BRANCH = {'git': git_current_branch}
current_branch = make_vsc_dispatcher(CURRENT_BRANCH, name='current_branch',
    doc="Returns the current branch for the user's version control system.",
    err = 'no way to get the branch for version control system {!r}')


def git_current_rev():
    """Obtains the current git revison hash for storage and rewinding purposes."""
    return $(git rev-parse HEAD).strip()


CURRENT_REV = {'git': git_current_rev}
current_rev = make_vsc_dispatcher(CURRENT_REV, name='current_rev',
    doc="Returns the current revision for the user's version control system.",
    err = 'no way to get the revision for version control system {!r}')


def git_reset_hard(rev):
    """Performs a git reset --hard to a revision."""
    git reset --hard @(rev)


REWIND = {'git': git_reset_hard}
rewind = make_vsc_dispatcher(REWIND, name='rewind',
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
merge = make_vsc_dispatcher(MERGE, name='merge',
    doc="Merges one revision into another.",
    err = 'no way to merge for {!r}')


def git_checkout(rev):
    """Checks out a branch name, tag, or other revision."""
    git checkout @(rev)


CHECKOUT = {'git': git_checkout}
checkout = make_vsc_dispatcher(CHECKOUT, name='checkout',
    doc="Checks out a revision.",
    err = 'no way to checkout for {!r}')


def git_tag(tag):
    """Tags the current head, forcibly."""
    git tag -f @(tag)

TAG = {'git': git_tag}
tag = make_vsc_dispatcher(TAG, name='tag',
    doc="Tags the current head.",
    err = 'no way to tag for {!r}')
