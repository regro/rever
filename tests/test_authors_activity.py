"""Tests the changelog activity."""
import os
import json

from rever import vcsutils
from rever.logger import current_logger
from rever.main import env_main


REVER_XSH = """
$ACTIVITIES = ['authors']
$PROJECT = "WAKKA"
$AUTHORS_FILENAME = "AUTHORS.md"
$AUTHORS_METADATA = "authors.yaml"
$AUTHORS_MAILMAP = "Mailmap"
$AUTHORS_LATEST = "latest.json"
"""


def test_authors(gitrepo):
    vcsutils.tag('42.1.0')
    files = [('rever.xsh', REVER_XSH),
             ]
    for filename, body in files:
        with open(filename, 'w') as f:
            f.write(body)
    vcsutils.track('.')
    vcsutils.commit('initial authors')
    env_main(['42.1.1'])
    # now see if this worked
    files = os.listdir('.')
    assert 'AUTHORS.md' in files
    assert 'authors.yaml' in files
    assert 'Mailmap' in files
    assert 'latest.json' in files
    # test authors file
    with open('AUTHORS.md') as f:
        auth = f.read()
    assert auth.startswith("All of the people who have made at least one contribution to WAKKA.\n"
                           "Authors are sorted by number of commits.\n")
    # test latest file
    with open("latest.json") as f:
        latest = json.load(f)
    assert isinstance(latest, list)
    assert len(latest) == 1
    assert isinstance(latest[0], str)
    assert '@' in latest[0]
    # ensure that the updates were commited
    logger = current_logger()
    entries = logger.load()
    assert entries[-2]['rev'] != entries[-1]['rev']



SETUP_XSH = """
$PROJECT = 'castlehouse'
$ACTIVITIES = ['authors']
$AUTHORS_FILENAME = "AUTHORS.md"
$AUTHORS_METADATA = "authors.yaml"
$AUTHORS_MAILMAP = "Mailmap"
$AUTHORS_TEMPLATE = "My project is $PROJECT"
"""

def test_changelog_setup(gitrepo):
    files = [('rever.xsh', SETUP_XSH),
             ]
    for filename, body in files:
        with open(filename, 'w') as f:
            f.write(body)
    vcsutils.track('.')
    vcsutils.commit('initial authors')
    env_main(['setup'])
    # now see if this worked
    files = os.listdir('.')
    assert 'AUTHORS.md' in files
    assert 'Mailmap' in files
    with open('AUTHORS.md') as f:
        auth = f.read()
    assert 'My project is castlehouse\n' == auth
