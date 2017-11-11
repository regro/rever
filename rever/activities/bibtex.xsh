"""Activity for bumping version."""
import datetime

from rever import vcsutils
from rever.activity import Activity, activity
try:
    import bibtexparser
except ImportError:
    pass

# $ACTIVITIES = ['bibtex']

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
    """Writes a BibTex reference for the version of software

    Minimal ``rever.xsh``::
        '''
        $PROJECT_NAME = <my_project>  # The name of your project
        $AUTHORS = ['Name1', 'Name2']  # The name of the authors
        $URL = <URL to Project>  # A URL to the code
        '''
    """

    def __init__(self, *, deps=frozenset('version_bump'),
                 bibfile='bibtex.bib'):
        super().__init__(name='bibtex', deps=deps, func=self._func,
                         desc="Write BibTex file for version")
        self.bibfile = bibfile

    def _func(self):
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

$DAG['bibtex'] = BibTex()

@activity(deps={'version_bump'})
def bibtex(output_file='bibtex.bib'):
    with open(output_file) as bibtex_file:
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

    with open(output_file, 'w') as b:
        b.write(writer.write(db))
    vcsutils.git_track(output_file)
    vcsutils.commit('bibtex entry created at ' + output_file)