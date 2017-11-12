"""Tests the pypi activity."""
import tempfile

from rever.logger import current_logger
from rever.main import env_main
from rever.activities.pypi import create_rc, validate_rc


REVER_XSH = """
$ACTIVITIES = ['tag']
$TAG_PUSH = False
"""


def test_create_rc():
    with tempfile.NamedTemporaryFile('w+t') as f:
        fname = f.name
        create_rc(fname, username='zappa', password='WakkaJawaka')
        f.seek(0)
        obs = f.read()
    print(obs)
    exp = ('[distutils]\n'
           'index-servers=\n'
           '\tpypi\n\n'
           '[pypi]\n'
           'repository=https://pypi.python.org/pypi\n'
           'username=zappa\n'
           'password=WakkaJawaka\n\n')
    assert exp == obs


VALID_RC = """[distutils]
index-servers =
    pypi

[pypi]
username:MisterT
password:JibberJabber
"""

def test_valid_rc():
    with tempfile.NamedTemporaryFile('w+t') as f:
        f.write(VALID_RC)
        f.flush()
        valid, msg = validate_rc(f.name)
    assert valid, msg
    assert len(msg) == 0, msg


def test_invalid_rc():
    rc = ''.join(VALID_RC.splitlines(keepends=True)[:-2])
    with tempfile.NamedTemporaryFile('w+t') as f:
        f.write(rc)
        f.flush()
        valid, msg = validate_rc(f.name)
    assert not valid, msg
    assert len(msg) > 0, msg
    assert 'username' in msg


def test_pypi_activity(gitrepo):
    return
    vcsutils.tag('42.1.0')
    files = [('rever.xsh', REVER_XSH),]
    for filename, body in files:
        with open(filename, 'w') as f:
            f.write(body)
    vcsutils.track('.')
    vcsutils.commit('Some versioned files')
    env_main(['42.1.1'])
    # now see if this worked
    current = vcsutils.latest_tag()
    assert '42.1.1' == current
    # now try to undo the tag
    env_main(['-u', 'tag', '42.1.1'])
    current = vcsutils.latest_tag()
    assert '42.1.0' == current
    # ensure that the updates were commited
    logger = current_logger()
    entries = logger.load()
    assert entries[-2] != entries[-1]
