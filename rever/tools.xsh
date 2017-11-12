"""Some special rever tools"""
import os
from contextlib import contextmanager

from xonsh.tools import expand_path

def eval_version(v):
    """Evalauates the argument either as a template string which contains
    $VERSION (or other environment variables) or a callable which
    takes a single argument (that is $VERSION) and returns a string.
    """
    if callable(v):
        rtn = v($VERSION)
    else:
        rtn = expand_path(v)
    return rtn


@contextmanager
def indir(d):
    """Context manager for temporarily entering into a directory."""
    old_d = os.getcwd()
    ![cd @(d)]
    yield
    ![cd @(old_d)]


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
    if isinstance(authors, str):
        authors = (authors, )
    if len(authors) == 1:
        return ''.join(authors[0])
    else:
        return ' and '.join(authors)
