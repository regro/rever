"""Activity for bumpimg version."""
import re

from rever import vcsutils
from rever.activity import Activity
from rever.tools import eval_version


class Tag(Activity):
    """Tags the current version and pushes the tag up to a remote
    repository.

    This activity takes the following parameters:

    :template: str, the template string to tag the version with,
               by default this is '$VERSION'
    :push: bool, flag for whether or not the current head and tag
           sould be pushed, default True.
    :remote: str or None, remote URL to push tags to. The default
             is None, which is only valid whrn push=False.
    :target: str or None, remote branch target to push tags to. The default
             is None, which uses the current branch.
    """

    def __init__(self, *, deps=frozenset(('version_bump', 'changelog'))):
        super().__init__(name='tag', deps=deps, func=self._func,
                         desc="Tags the current version.")

    def _func(self, template='$VERSION', push=True, remote=None,
              target=None):
        tag = eval_version(template)
        vcsutils.tag(tag)
        if not push:
            return
        if remote is None:
            raise ValueError('tag remote cannot be None to push up tags, '
                             'try setting $TAG_REMOTE in rever.xsh')
        if target is None:
            target = vcsutils.current_branch()
        vcsutils.push(remote, target)
        vcsutils.push_tags(remote)

    def undo(self):
        """Undoes the tagging operation."""
        kwargs = self.all_kwargs()
        template = kwargs.get('template', '$VERSION')
        push = kwargs.get('push', True)
        remote = kwargs.get('remote', None)
        tag = eval_version(template)
        vcsutils.del_tag(tag)
        if push:
            if remote is None:
                raise ValueError('tag remote cannot be None to remove remote '
                                 'tags, try setting $TAG_REMOTE in rever.xsh')
            vcsutils.del_remote_tag(tag, remote)
        msg = 'Removed tag {0!r}'.format(tag)
        log -a @(self.name) -c activity-undo @(msg)
