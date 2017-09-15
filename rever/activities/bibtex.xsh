"""Activity for bumping version."""
import re

from rever import vcsutils
from rever.activity import Activity
from rever.tools import eval_version
import bibtexparser
import datetime


def render_authors(authors):
    """Parse a list of of tuples of authors into valid bibtex

    Parameters
    ----------
    authors: list of str
        The authors eg ['Your name in nicely formatted bibtex'].
        Please see ``<http://nwalsh.com/tex/texhelp/bibtx-23.html>`` for
        information about how to format your name for bibtex

    Returns
    -------
    str:
        Valid bibtex authors
    """
    if len(authors) == 1:
        return ' '.join(authors[0])
    else:
        return ' and '.join(authors)


class BibTex(Activity):
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

    def __init__(self, *, deps=frozenset('version_bump'),
                 bibfile='bibtex.bib'):
        super().__init__(name='version_bump', deps=deps, func=self._func,
                         desc="Changes the version to the value of $VERSION.")
        self.bibfile = bibfile

    def _func(self, patterns=()):
        with open(self.bibfile) as bibtex_file:
            bibtex_str = bibtex_file.read()
        db = bibtexparser.loads(bibtex_str)
        e = db.entries
        bibtex_entry = {
            'title': $PROJECT_NAME,
            'ID': $PROJECT_NAME + $VERSION,
            'author': render_authors('$AUTHORS'),
            'url': $URL,
            'version': $VERSION,
            'date': str(datetime.date.today()),
            'ENTRYTYPE': 'software'}
        e.extend(bibtex_entry)
        writer = bibtexparser.BibTexWriter()
        with open(self.bibfile, 'w') as b:
            b.write(writer.write(db))
        vcsutils.git_track(self.bibfile)
        vcsutils.commit('bibtex entry created at ' + self.bibfile)
