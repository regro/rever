"""Tests the bibtex activity activity."""
import os

from rever import vcsutils
from rever.logger import current_logger
from rever.main import env_main

REVER_XSH = """
from rever.activities.bibtex import BibTex
$ACTIVITIES = ['bibtex']
$PROJECT_NAME = 'my_project'  # The name of your project
$AUTHORS = ['Name1', 'Name2']  # The name of the authors
$URL = 'URL/to/Project'  # A URL to the code
"""


def test_bibtex_activity(gitrepo):
    files = [('rever.xsh', REVER_XSH), ]
    for filename, body in files:
        with open(filename, 'w') as f:
            f.write(body)
    env_main(['42.1.1'])
    # now see if this worked
    assert 'bibtex.bib' in os.listdir('.')
