"""Tests the pypi activity."""
import tempfile
import builtins
import subprocess

from rever.logger import current_logger
from rever.main import env_main
from rever import vcsutils
from rever.activities.pypi import create_rc, validate_rc


REVER_XSH = """
$ACTIVITIES = ['version_bump', 'pypi']
$PYPI_RC = 'pypirc'
$PYPI_BUILD_COMMANDS = ['--version']
$PYPI_UPLOAD = False
$VERSION_BUMP_PATTERNS = [
    ('setup.py', '    version\s*=.*', "    version='$VERSION'"),
    ]
"""

VALID_RC = """[distutils]
index-servers =
    pypi

[pypi]
username:MisterT
password:JibberJabber
"""


INVALID_RC = """[distutils]
index-servers =
    pypi

[pypi]
repository:https://pypi.python.org/pypi
username:MisterT
password:JibberJabber
"""

SETUP_PY = """
from distutils.core import setup
setup(
    version='42.1.0',
)
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
           'username=zappa\n'
           'password=WakkaJawaka\n\n')
    assert exp == obs


def test_valid_rc():
    with tempfile.NamedTemporaryFile('w+t') as f:
        f.write(VALID_RC)
        f.flush()
        valid, msg = validate_rc(f.name)
    assert valid, msg
    assert len(msg) == 0, msg


def test_invalid_rc_username():
    rc = ''.join(VALID_RC.splitlines(keepends=True)[:-2])
    with tempfile.NamedTemporaryFile('w+t') as f:
        f.write(rc)
        f.flush()
        valid, msg = validate_rc(f.name)
    assert not valid, msg
    assert len(msg) > 0, msg
    assert 'username' in msg


def test_invalid_rc_repository():
    rc = ''.join(INVALID_RC.splitlines(keepends=True)[:-2])
    with tempfile.NamedTemporaryFile('w+t') as f:
        f.write(rc)
        f.flush()
        valid, msg = validate_rc(f.name)
    assert not valid, msg
    assert len(msg) > 0, msg
    assert 'repository' in msg


def test_pypi_activity(gitrepo):
    files = [('rever.xsh', REVER_XSH),
             ('pypirc', VALID_RC),
             ('setup.py', SETUP_PY)]
    for filename, body in files:
        with open(filename, 'w') as f:
            f.write(body)
    vcsutils.track('.')
    vcsutils.commit('Some versioned files')
    env_main(['42.1.1'])
    env = builtins.__xonsh__.env
    python = env.get('PYTHON')
    out = subprocess.check_output([python, 'setup.py', '--version'],
                                  universal_newlines=True)
    out = out.strip()
    assert '42.1.1' == out
