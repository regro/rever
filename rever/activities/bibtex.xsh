"""Activity for bumping version."""
import datetime
import os

from xonsh.tools import expand_path

from rever import vcsutils
from rever.activity import Activity
from rever.tools import render_authors
try:
    import bibtexparser
except ImportError:
    bibtexparser = None


class BibTex(Activity):
    """Writes a BibTex reference for the version of software.

    Environment variables that directly affect the behaviour of this
    activity are:

    :$BIBTEX_BIBFILE: str, The filename to create. Defaults to
        ``'bibtex.bib'``.
    :$BIBTEX_PROJECT_NAME: str, The name of the project. This is expanded
        in the current envrionment, default ``$PROJECT``.
    :$BIBTEX_AUTHORS: list of str, The name of the authors to credit
        in the citation. Default has no authors.
    :$BIBTEX_URL: str, URL to the project. This is expanded in the current
        environment, default ``'$WEBSITE_URL'``.

    Other environment variables that affect the behaviour of the bibtex
    activity are:

    :$PROJECT: Used as the default project name.
    :$WEBSITE_URL: Used as the default URL.
    :$VERSION: Used in the bibtex entry as part of the identifier.
    """

    def __init__(self, *, deps=frozenset(('version_bump', )),
                 ):
        super().__init__(name='bibtex', deps=deps, func=self._func,
                         desc="Write BibTex file for version")

    def _func(self, bibfile='bibtex.bib', project_name='$PROJECT', authors=(),
              url='$WEBSITE_URL'):
        project_name = expand_path(project_name)
        url = expand_path(url)
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
