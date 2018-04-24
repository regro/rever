"""Tests the changelog activity."""
import os

from rever import vcsutils
from rever.logger import current_logger
from rever.main import env_main


REVER_XSH = """
$ACTIVITIES = ['changelog']

$DAG['changelog'].kwargs = {
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
TEMPLATE_RST = """**Added:**

* <add entry>

**Changed:**

* <add entry>

**Deprecated:**

* <add entry>

**Removed:**

* <add entry>

**Fixed:**

* <add entry>

**Security:**

* <add entry>
"""
N0_RST = """**Added:**

* from n0

**Changed:**

* <add entry>

**Deprecated:**

* <add entry>

**Removed:**

* here
* and here

**Fixed:**

* <add entry>

**Security:**

* <add entry>
"""
N1_RST = """**Added:**

* from n1

**Changed:**

* But what martial arts are they mixing?

**Deprecated:**

* <add entry>

**Removed:**

* There

**Fixed:**

* <add entry>

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



SETUP_XSH = """
$PROJECT = 'castlehouse'
$ACTIVITIES = ['changelog']
$REVER_DIR = 'rvr'

$CHANGELOG_FILENAME = 'CHANGELOG.rst'
$CHANGELOG_NEWS = 'nuws'
$CHANGELOG_TEMPLATE = 'TEMPLATE.rst'
"""

def test_changelog_setup(gitrepo):
    os.makedirs('nuws', exist_ok=True)
    files = [('rever.xsh', SETUP_XSH),
             ]
    for filename, body in files:
        with open(filename, 'w') as f:
            f.write(body)
    vcsutils.track('.')
    vcsutils.commit('initial changelog')
    env_main(['setup'])
    # now see if this worked
    newsfiles = os.listdir('nuws')
    assert 'TEMPLATE.rst' in newsfiles
    basefiles = os.listdir('.')
    assert 'CHANGELOG.rst' in basefiles
    with open('CHANGELOG.rst') as f:
        cl = f.read()
    assert 'castlehouse' in cl
    assert '.gitignore' in basefiles
    with open('.gitignore') as f:
        gi = f.read()
    assert '\n# Rever\nrvr/\n' in gi


