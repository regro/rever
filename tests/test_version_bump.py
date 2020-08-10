"""Tests the version bumper activity."""
from rever import vcsutils
from rever.logger import current_logger
from rever.main import env_main


REVER_XSH = """
$ACTIVITIES = ['version_bump']

$DAG['version_bump'].args = [[
    ('init.py', r'__version__\s*=.*', "__version__ = '$VERSION'"),
    ('appveyor.yml', r'version:\s*', (lambda ver: 'version: {0}.{{build}}'.format(ver))),
]]
"""
INIT_PY = "__version__='42.1.0'\n"
APPVEYOR_YML = "version: 42.1.0\n"


def test_version_bump(gitrepo):
    files = [('rever.xsh', REVER_XSH), ('init.py', INIT_PY),
             ('appveyor.yml', APPVEYOR_YML)]
    for filename, body in files:
        with open(filename, 'w') as f:
            f.write(body)
    vcsutils.track('.')
    vcsutils.commit('Some versioned files')
    env_main(['42.1.1'])
    # now see if this worked
    with open('init.py') as f:
        init = f.read()
    assert "__version__ = '42.1.1'\n" == init
    with open('appveyor.yml') as f:
        appveyor = f.read()
    assert appveyor == "version: 42.1.1.{build}\n"
    # ensure that the updates were commited
    logger = current_logger()
    entries = logger.load()
    assert entries[-2]['rev'] != entries[-1]['rev']
