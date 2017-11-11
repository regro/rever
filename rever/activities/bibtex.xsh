"""Activity for bumping version."""
import datetime
import os

from rever import vcsutils
from rever.activity import Activity
try:
    import bibtexparser
except ImportError:
    bibtexparser = None


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
        return ''.join(authors[0])
    else:
        return ' and '.join(authors)


class BibTex(Activity):
    """Writes a BibTex reference for the version of software

    Minimal ``rever.xsh``::
        '''
        $BIBTEX_PROJECT_NAME = <my_project>  # The name of your project
        $BIBTEX_AUTHORS = ['Name1', 'Name2']  # The name of the authors
        $BIBTEX_URL = <URL to Project>  # A URL to the code
        '''
    """

    def __init__(self, *, deps=frozenset(('version_bump', )),
                 ):
        super().__init__(name='bibtex', deps=deps, func=self._func,
                         desc="Write BibTex file for version")

    def _func(self, bibfile='bibtex.bib', project_name=None, authors=(),
              url=None):
        if bibtexparser is None:
            return None
        if os.path.exists(bibfile):
            with open(bibfile) as bibtex_file:
                bibtex_str = bibtex_file.read()
            db = bibtexparser.loads(bibtex_str)
        else:
            db = bibtexparser.bibdatabase.BibDatabase()
        bibtex_entry = {
            'title': project_name,
            'ID': project_name + $VERSION,
            'author': render_authors(authors),
            'url': url,
            'version': $VERSION,
            'date': str(datetime.date.today()),
            'ENTRYTYPE': 'software'}
        db.entries.append(bibtex_entry)
        writer = bibtexparser.bwriter.BibTexWriter()

        with open(bibfile, 'w') as b:
            b.write(writer.write(db))
        vcsutils.track(bibfile)
        vcsutils.commit('bibtex entry created at ' + bibfile)

$DAG['bibtex'] = BibTex()
