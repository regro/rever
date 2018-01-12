"""Activity for pushing remote tags."""
import re

from rever import vcsutils
from rever.activity import Activity
from rever.tools import eval_version


class PushTag(Activity):
    """Pushes the current tag up to a remote repository.

    This activity takes the following parameters:

    :$PUSH_TAG_REMOTE: str or None, remote URL to push tags to. If ``$REVER_VCS`` is
        set to ``'git'`` and both ``$GITHUB_ORG`` and ``$GITHUB_REPO`` are also set,
        this variable will default to ``git@github.com:$GITHUB_ORG/$GITHUB_REPO.git``.
    :$PUSH_TAG_TARGET: str or None, remote branch to push to once the tag has been made.
        The default is None, which uses the current branch.

    Other environment variables that affect the behavior are:

    :$REVER_VCS: str or None, is used to help specify default remote URLs.
    :$GITHUB_ORG: str or None, GitHub org to push to if no ``$PUSH_TAG_REMOTE``
    :$GITHUB_REPO: str or None GitHub repo to push to if no ``$PUSH_TAG_REMOTE``
    :$TAG_TEMPLATE: str, the template string to tag the version with,
        by default this is '$VERSION'. This is used in undoing remote tags
    """

    def __init__(self, *, deps=frozenset(('tag', ))):
        super().__init__(name='push_tag', deps=deps, func=self._func,
                         desc="Tags the current version.")

    def _func(self, remote=None, target=None):
        if remote is None:
            # Pull from the org and repo
            org = ${...}.get('GITHUB_ORG', None)
            repo = ${...}.get('GITHUB_REPO', None)
            if org and repo and ${...}.get('REVER_VCS', None) == 'git':
                remote = 'git@github.com:{org}/{repo}.git'.format(org=org,
                                                                  repo=repo)
            else:
                raise ValueError('tag remote cannot be None to push up tags, '
                                 'try setting $TAG_REMOTE or $GITHUB_ORG and '
                                 '$GITHUB_REPO in rever.xsh')
        if target is None:
            target = vcsutils.current_branch()
        vcsutils.push(remote, target)
        vcsutils.push_tags(remote)

    def undo(self):
        """Undoes the tagging operation."""
        kwargs = self.all_kwargs()
        remote = kwargs.get('remote', None)
        if remote is None:
            org = ${...}.get('GITHUB_ORG', None)
            repo = ${...}.get('GITHUB_REPO', None)
            if org and repo:
                remote = 'git@github.com:{org}/{repo}.git'.format(org=org,
                                                                  repo=repo)
            else:
                raise ValueError('push tag remote cannot be None to remove remote '
                                 'tags, try setting $PUSH_TAG_REMOTE or '
                                 '$GITHUB_ORG and $GITHUB_REPO in rever.xsh')
        template = ${...}.get('TAG_TEMPLATE', '$VERSION')
        tag = eval_version(template)

        vcsutils.del_remote_tag(tag, remote)
        msg = 'Removed remote tag {0!r}'.format(tag)
        log -a @(self.name) -c activity-undo @(msg)
