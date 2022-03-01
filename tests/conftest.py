import os
import shutil
import tempfile
import builtins
import subprocess

import pytest
import sys

from rever import environ


@pytest.fixture
def gitrepo(request):
    """A test fixture that creates and destroys a git repo in a temporary
    directory.
    This will yield the path to the repo.
    """
    cwd = os.getcwd()
    name = request.node.name
    repo = os.path.join(tempfile.gettempdir(), name)
    if os.path.exists(repo):
        rmtree(repo)
    subprocess.run(['git', 'init', repo])
    os.chdir(repo)
    with open('README', 'w') as f:
        f.write('testing ' + name)
    subprocess.run(['git', 'add', '.'])
    subprocess.run(['git', 'commit', '-am', 'Initial readme'])
    with environ.context():
        yield repo
    os.chdir(cwd)
    rmtree(repo)


@pytest.fixture
def gitecho(request):
    aliases = builtins.aliases
    aliases['git'] = lambda args: 'Would have run: ' + ' '.join(args) + '\n'
    yield None
    del aliases['git']


@pytest.fixture
def gcloudecho(request):
    aliases = builtins.aliases
    aliases['gcloud'] = lambda args: 'Would have run: ' + ' '.join(args) + '@\n'
    yield None
    del aliases['gcloud']


@pytest.fixture
def kubectlecho(request):
    aliases = builtins.aliases
    aliases['kubectl'] = lambda args: 'Would have run: ' + ' '.join(args) + '\n'
    yield None
    del aliases['kubectl']


def rmtree(dirname):
    """Remove a directory, even if it has read-only files (Windows).
    Git creates read-only files that must be removed on teardown. See
    https://stackoverflow.com/questions/2656322  for more info.

    Parameters
    ----------
    dirname : str
        Directory to be removed
    """
    try:
        shutil.rmtree(dirname)
    except PermissionError:
        if sys.platform == 'win32':
            subprocess.check_call(['del', '/F/S/Q', dirname], shell=True)
        else:
            raise
