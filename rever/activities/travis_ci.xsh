"""Activity for making a Travis.yml file."""
import os
import re
import sys

from xonsh.tools import print_color

from rever import vcsutils
from rever.activity import Activity
from rever.tools import eval_version, replace_in_file

TRAVIS_CI = """sudo: False

language: python

matrix:
  include:
    - python: 3.6

install:
  # Install conda
  - wget https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh
  - bash miniconda.sh -b -p $HOME/miniconda
  - export PATH="$HOME/miniconda/bin:$PATH"
  - conda config --set always_yes yes --set changeps1 no
  - conda config --add channels conda-forge
  - conda update conda

  # Install dependencies
  - conda install {conda_deps}  -c (conda_channels) 
  - pip install {pip_deps}
  - python setup.py install

# script:
  # - set -e
  # - {tests}
  # - cd docs
  # - make html 
  # - cd ..

notifications:
  email: false

"""

class TravisCI(Activity):
    """Creates the Travis.yml file from user provided environmental variables.

    This activity may be configured with the following environment variables:

    :$DOCKER_CONDA_DEPS: Dependencies to install in the base container via conda.
    :$DOCKER_PIP_DEPS:Dependencies to install in the base container via pip.
    :$DOCKER_CONDA_CHANNELS: Conda channels to use, in order of decreasing
        precedence. Defaults to conda-forge
    """

    def __init__(self, *, deps=frozenset()):
        super().__init__(name='travis_ci', deps=deps,
                         desc="Creates the Travis.yml file",
                         setup=self.setup_func)


    def setup_func(self):
        """Creates the Travis file by creating a template and inserting the user
            provided environment variables.
        """
        template_file = ".travis.yml"
        with open(template_file,"w") as f:
            s = TRAVIS_CI.format(conda_docs=$DOCKER_CONDA_DEPS,
                                            pip_deps=$DOCKER_PIP_DEPS,
                                            conda_channels=$DOCKER_CONDA_CHANNELS,
                                            tests=$PYTEST_COMMAND)
            f.write(s)
        return True
