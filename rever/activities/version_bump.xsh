"""Activity for bumping version."""
import re

from rever import vcsutils
from rever.activity import Activity
from rever.tools import eval_version, replace_in_file


class VersionBump(Activity):
    r"""Changes the version to the value of $VERSION.

    This activity is parameterized by the following environment
    variable:

    :$VERSION_BUMP_PATTERNS: list of 3-tuples of str,
        This activity is only usefule if replacement patterns are supplied to it.
        This argument is an iterable of 3-tuples consisting of:

        * filename, str - file to update the version in
        * pattern, str - A Python regular expression that specifies
          how to find matching lines for the replacement string.
          Leading whitespace will be captured and replaced. The pattern
          here can start at the first non-whitespace character.
        * new, str or function returning a string - the replacement
          template as a string or a simple callable that accepts the
          version. If it is a string, it is expanded with environment
          variables.

        For example::

            $VERSION_BUMP_PATTERNS = [
                # replace __version__ in init file
                ('src/__init__.py', r'__version__\s*=.*', "__version__ = '$VERSION'"),

                # replace version in appveyor
                ('.appveyor.yml', r'version:\s*',
                  (lambda ver: 'version: {0}.{{build}}'.format(ver))),
              ...
            ]

    """

    def __init__(self, *, deps=frozenset()):
        super().__init__(name='version_bump', deps=deps, func=self._func,
                         desc="Changes the version to the value of $VERSION.")

    def _func(self, patterns=()):
        for f, p, n in patterns:
            n = eval_version(n)
            replace_in_file(p, n, f)
        vcsutils.commit('bumped version to ' + $VERSION)
