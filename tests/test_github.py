"""Github Tests"""
import os
import builtins
import tempfile

import pytest

from rever import environ
from rever.github import credfilename, read_credfile, credfile_new_format


@pytest.fixture
def githubenv(request):
    with environ.context():
        env = builtins.__xonsh__.env
        env['GITHUB_ORG'] = 'wakka'
        env['GITHUB_REPO'] = 'jawaka'
        yield env


def test_credfilename(githubenv):
    credfile = credfilename('what.cred')
    assert credfile == os.path.abspath('what.cred')


CREDFILE = """zappa
45463104f006ccb3a512fb20e31b9a50f10ba38b
"""


def test_read_credfile(githubenv):
    with tempfile.NamedTemporaryFile('w+t') as f:
        f.write(CREDFILE)
        f.flush()
        username, token = read_credfile(f.name)
        new_format = credfile_new_format(f.name)

    assert username == 'zappa'
    assert token == '45463104f006ccb3a512fb20e31b9a50f10ba38b'
    assert new_format
