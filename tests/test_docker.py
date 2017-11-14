"""Docker Tests"""
import os
import builtins
import tempfile

import pytest

from rever import environ
from rever.docker import (apt_deps, conda_deps, pip_deps, make_base_dockerfile,
    docker_envvars, make_install_dockerfile, docker_source_from)


@pytest.fixture
def dockerenv(request):
    with environ.context():
        env = builtins.__xonsh_env__
        yield env


@pytest.mark.parametrize('envvars, exp', [
    (None, ''),
    ({}, ''),
    ({'PATH': '$HOME/.local/bin/$PATH'},
"""ENV PATH $HOME/.local/bin/$PATH
"""),
    ({'PATH': '$HOME/.local/bin/$PATH', 'A': 'YO', 'Z': 'APPA'},
"""ENV A YO
ENV PATH $HOME/.local/bin/$PATH
ENV Z APPA
"""),
])
def test_docker_envvars(envvars, exp):
    obs = docker_envvars(envvars)
    assert exp == obs


@pytest.mark.parametrize('deps, exp', [
    ([], ''),
    (['dep1', 'dep0'],
"""RUN apt-get -y update && \\
    apt-get install -y --fix-missing \\
        dep0 dep1 && \\
    apt-get clean -y

"""),
])
def test_apt_deps(dockerenv, deps, exp):
    obs = apt_deps(deps)
    assert exp == obs



@pytest.mark.parametrize('deps, channels, exp', [
    ([], [], ''),
    ([], None, ''),
    ([], ['conda-forge'], ''),
    (['dep1', 'dep0'], [],
"""RUN conda config --set always_yes yes && \\
    conda update --all && \\
    conda install \\
        dep0 dep1 && \\
    conda clean --all && \\
    conda info

"""),
    (['dep1', 'dep0'], ['conda-forge', 'my-channel'],
"""RUN conda config --set always_yes yes && \\
    conda config --add channels my-channel && \\
    conda config --add channels conda-forge && \\
    conda update --all && \\
    conda install \\
        dep0 dep1 && \\
    conda clean --all && \\
    conda info

"""),
])
def test_conda_deps(dockerenv, deps, channels, exp):
    obs = conda_deps(deps, channels)
    assert exp == obs


@pytest.mark.parametrize('deps, reqs, exp', [
    ([], [], ''),
    (['dep1', 'dep0'], [],
"""RUN pip install \\
    dep1 dep0

"""),
    ([], ['req1', 'req0'],
"""RUN pip install \\
    -r req1 -r req0

"""),
    (['dep1', 'dep0'], ['req1', 'req0'],
"""RUN pip install \\
    -r req1 -r req0 dep1 dep0

"""),
])
def test_pip_deps(dockerenv, deps, reqs, exp):
    obs = pip_deps(deps, reqs)
    assert exp == obs


EXP_BASE = """FROM zappa/project

ENV REVER_VCS git
ENV VERSION x.y.z

WORKDIR /root

RUN apt-get -y update && \\
    apt-get install -y --fix-missing \\
        dep0 dep1 && \\
    apt-get clean -y

RUN conda config --set always_yes yes && \\
    conda config --add channels my-channel && \\
    conda config --add channels conda-forge && \\
    conda update --all && \\
    conda install \\
        dep0 dep1 && \\
    conda clean --all && \\
    conda info

RUN pip install \\
    -r req1 -r req0 dep1 dep0


"""


def test_make_base_dockerfile(dockerenv):
    obs = make_base_dockerfile(base_from='zappa/project',
                               apt=['dep1', 'dep0'],
                               conda=['dep1', 'dep0'],
                               conda_channels=['conda-forge', 'my-channel'],
                               pip=['dep1', 'dep0'],
                               pip_requirements=['req1', 'req0'])
    assert EXP_BASE == obs


@pytest.mark.parametrize('source, url, root, workdir, exp', [
    ('curl -L afile.tar.gz && tar xvf afile.tar.gz && rm afile.tar.gz',
     None, '.', '$HOME/my/workdir',
     'RUN curl -L afile.tar.gz && tar xvf afile.tar.gz && rm afile.tar.gz'),
    (None, 'git@github.com:regro/rever.git', '.', '$HOME/my/workdir',
     'RUN git clone git@github.com:regro/rever.git $HOME/my/workdir'),
    (None, None, '.', '$HOME/my/workdir',
     'ADD . $HOME/my/workdir'),
])
def test_docker_source_from(dockerenv, source, url, root, workdir, exp):
    obs = docker_source_from(source=source, url=url, root=root, workdir=workdir)
    assert exp == obs



EXP_INSTALL = """FROM project/rever-base

ADD . $HOME/my/workdir

WORKDIR $HOME/my/workdir

RUN setup.py install --user

ENV PATH $HOME/.local/bin:$PATH

"""


def test_make_install_dockerfile(dockerenv):
    obs = make_install_dockerfile(base='project/rever-base',
                                  root='.',
                                  command='setup.py install --user',
                                  envvars={'PATH': '$HOME/.local/bin:$PATH'},
                                  workdir='$HOME/my/workdir',
                                  )
    assert EXP_INSTALL == obs
