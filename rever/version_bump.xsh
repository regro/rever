"""Activity for bumpimg version."""
import re

from xonsh.tools import expand_path

from rever import vcsutils
from rever.activity import Activity


def replace_in_file(pattern, new, fname):
    """Replaces a given pattern in a file"""
    with open(fname, 'r') as f:
        raw = f.read()
    lines = raw.splitlines()
    ptn = re.compile(pattern)
    for i, line in enumerate(lines):
        if ptn.match(line):
            lines[i] = new
    upd = '\n'.join(lines) + '\n'
    with open(fname, 'w') as f:
        f.write(upd)


class VersionBump(Activity):
    """Changes the version to the value of $VERSION.

    This activity requires the 'patterns' argumenent be supplied.
    This argument is an iterable of 3-tuples consisting of:

    * filename, str - file to update the version in
    * pattern, str - A Python regular expression that specifies
      how to find matching lines for the replacement string
    * new, str or function returning a string - the replacement
      template as a string or a simple callable that accepts the
      version. If it is a string, it is expanded with environment
      variables.

    For example::

        patterns = [
            # replace __version__ in init file
            ('src/__init__.py', '__version__\s*=.*', "__version__ = '$VERSION'"),

            # replace version in appveyor
            ('.appveyor.yml', 'version:\s*',
              (lambda ver: 'version: {0}.{{build}}'.format(ver))),
          ...
        ]
    """

    def __init__(self, *, deps=frozenset()):
        super().__init__(name='version_bump', deps=deps, func=self._func,
                         desc="Changes the version to the value of $VERSION.")

    def _func(self, patterns=()):
        for f, p, n in patterns:
            if callable(n):
                n = n($VERSION)
            else:
                n = expand_path(n)
            replace_in_file(p, n, f)
        vcsutils.commit('bumped version to ' + $VERSION)
