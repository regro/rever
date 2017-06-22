"""Tests the changelog activity."""
import os

from rever import vcsutils
from rever.logger import current_logger
from rever.main import env_main


REVER_XSH = """
$ACTIVITIES = ['changelog']

$ACTIVITY_DAG['changelog'].kwargs = {
    'filename': 'CHANGELOG.rst',
    'ignore': ['TEMPLATE.rst'],
    'news': 'nuws',
}
"""
CHANGELOG_RST = """.. current developments

v42.1.0
============
* And some other stuff happeneded.
"""
TEMPLATE_RST = """**Added:** None

**Changed:** None

**Deprecated:** None

**Removed:** None

**Fixed:** None

**Security:** None
"""
N0_RST = """**Added:**

* from n0

**Changed:** None

**Deprecated:** None

**Removed:**

* here
* and here

**Fixed:** None

**Security:** None
"""
N1_RST = """**Added:**

* from n1

**Changed:**

* But what martial arts are they mixing?

**Deprecated:** None

**Removed:**

* There

**Fixed:** None

**Security:** None
"""
CHANGELOG_42_1_1 = """.. current developments

v42.1.1
====================

**Added:**

* from n0
* from n1


**Changed:**

* But what martial arts are they mixing?


**Removed:**

* here
* and here
* There




v42.1.0
============
* And some other stuff happeneded.
"""


def test_changelog(gitrepo):
    os.makedirs('nuws', exist_ok=True)
    files = [('rever.xsh', REVER_XSH),
             ('CHANGELOG.rst', CHANGELOG_RST),
             ('nuws/TEMPLATE.rst', TEMPLATE_RST),
             ('nuws/n0.rst', N0_RST),
             ('nuws/n1.rst', N1_RST),
             ]
    for filename, body in files:
        with open(filename, 'w') as f:
            f.write(body)
    vcsutils.track('.')
    vcsutils.commit('initial changelog and news')
    env_main(['42.1.1'])
    # now see if this worked
    newsfiles = os.listdir('nuws')
    assert 'TEMPLATE.rst' in newsfiles
    assert 'n0.rst' not in newsfiles
    assert 'n1.rst' not in newsfiles
    with open('CHANGELOG.rst') as f:
        cl = f.read()
    assert CHANGELOG_42_1_1 == cl
    # ensure that the updates were commited
    logger = current_logger()
    entries = logger.load()
    assert entries[-2]['rev'] != entries[-1]['rev']
