"""Activity for keeping a changelog from news entries."""
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
  - conda install {conda_deps} -c (conda_channels)
  - pip install {pip_deps}
  - python setup.py install

# script:
  # - set -e
  # - # Command to build your docs
  # - pip install doctr
  # - cd docs
  # - make html
  # - cd ..
  # - doctr deploy . --deploy-repo ergs/rever-docs --built-docs ./docs/_build/html

notifications:
  email: false

"""

class TravisCI(Activity):
    """Manages keeping a changelog up-to-date.

    This activity may be configured with the following envionment variables:

    :$CHANGELOG_FILENAME: str, path to input file. The default is 'CHANGELOG'.
    :$CHANGELOG_PATTERN: str, Python regex that is used to find the location
        in the file where new changelog entries should be placed. The default is
        ``'.. current developments'``.
    :$CHANGELOG_HEADER: str or callable that accepts a single version argument,
        this is the replacement that goes above the new merge entries.
        This should contain a string that matches the pattern arg
        so that the next release may be inserted automatically.
        The default value is:

        .. code-block:: rst

            .. current developments

            v$VERSION

            ====================

    :$CHANGELOG_NEWS: str, path to directory containing news files.
        The default is ``'news'``.
    :$CHANGELOG_IGNORE: list of str, regexes of filenames in the news directory
        to ignore. The default is to ignore the template file.
    :$CHANGELOG_LATEST: str, file to write just the latest part of the
        changelog to. This defaults to ``$REVER_DIR/LATEST``. This is evaluated
        in the current environment.
    :$CHANGELOG_TEMPLATE: str, filename of the template file in the
        news directory. The default is ``'TEMPLATE'``.
    """

    def __init__(self, *, deps=frozenset()):
        super().__init__(name='changelog', deps=deps,
                         desc="Manages keeping a changelog up-to-date.",
                         setup=self.setup_func)
        self._re_cache = {}


    def setup_func(self):
        """Initializes the changelog activity by starting a news dir, making
        a template file, and starting a changlog file.
        """
        template_file = ".travis.yml"
        with open(template_file,"w") as f:
            s = TRAVIS_CI.format(conda_docs=$DOCKER_CONDA_DEPS,
                                            pip_deps=$DOCKER_PIP_DEPS,
                                            conda_channels=$DOCKER_CONDA_CHANNELS)
            f.write(s)
        return True