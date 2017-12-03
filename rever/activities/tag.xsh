"""Activity for locally creating tags."""
import re

from rever import vcsutils
from rever.activity import Activity
from rever.tools import eval_version


class Tag(Activity):
    """Locally tags the current version.

    This activity takes the following parameters:

    :$TAG_TEMPLATE: str, the template string to tag the version with,
        by default this is '$VERSION'
    """

    def __init__(self, *, deps=frozenset(('version_bump', 'changelog'))):
        super().__init__(name='tag', deps=deps, func=self._func,
                         desc="Tags the current version.")

    def _func(self, template='$VERSION'):
        tag = eval_version(template)
        vcsutils.tag(tag)

    def undo(self):
        """Undoes the tagging operation."""
        kwargs = self.all_kwargs()
        template = kwargs.get('template', '$VERSION')
        tag = eval_version(template)
        vcsutils.del_tag(tag)
        msg = 'Removed local tag {0!r}'.format(tag)
        log -a @(self.name) -c activity-undo @(msg)
