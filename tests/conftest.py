import os
import shutil
import tempfile
import builtins
import subprocess

import pytest

from rever import environ


@pytest.fixture
def gitrepo(request):
    """A test fixutre that creates and destroys a git repo in a temporary
    directory.
    This will yield the path to the repo.
    """
    cwd = os.getcwd()
    name = request.node.name
    repo = os.path.join(tempfile.gettempdir(), name)
    if os.path.exists(repo):
        shutil.rmtree(repo)
    subprocess.run(['git', 'init', repo])
    os.chdir(repo)
    with open('README', 'w') as f:
        f.write('testing ' + name)
    subprocess.run(['git', 'add', '.'])
    subprocess.run(['git', 'commit', '-am', 'Initial readme'])
    with environ.context():
        yield repo
    os.chdir(cwd)
    shutil.rmtree(repo)


@pytest.fixture
def gitecho(request):
    aliases = builtins.aliases
    aliases['git'] = lambda args: 'Would have run: ' + ' '.join(args) + '\n'
    yield None
    del aliases['git']
