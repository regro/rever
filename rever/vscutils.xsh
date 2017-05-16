"""Some version control utilities for rever"""

def git_current_branch():
    """Returns the current branch for git"""
    return $(git rev-parse --abbrev-ref HEAD).strip()


CURRENT_BRANCH = {'git': git_current_branch}

def current_branch():
    """Returns the current branch for the user's version control system."""
    func = CURRENT_BRANCH.get($REVER_VCS, None)
    if func is None:
        msg = 'no way to get branch for version control system {!r}'
        raise RuntimeError(msg.format($REVER_VCS))
    return func()

