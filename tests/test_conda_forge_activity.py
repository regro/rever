"""Tests the conda forge activity."""
import os
import builtins

import pytest

from rever import vcsutils
from rever.logger import current_logger
from rever.main import env_main
from rever.activities.conda_forge import (feedstock_url, feedstock_repo,
                                          fork_url)


@pytest.mark.parametrize('name, proto, exp', [
    ('my-feedstock', 'ssh', 'git@github.com:conda-forge/my-feedstock.git'),
    ('git@github.com:conda-forge/my-feedstock.git', None,
     'git@github.com:conda-forge/my-feedstock.git'),
    ('my-feedstock', 'http', 'http://github.com/conda-forge/my-feedstock.git'),
    ('http://github.com/conda-forge/my-feedstock.git', None,
     'http://github.com/conda-forge/my-feedstock.git'),
    ('my-feedstock', 'https', 'https://github.com/conda-forge/my-feedstock.git'),
    ('https://github.com/conda-forge/my-feedstock.git', None,
     'https://github.com/conda-forge/my-feedstock.git'),
])
def test_feedstock_url(name, proto, exp):
    obs = feedstock_url(name, protocol=proto)
    assert exp == obs


@pytest.mark.parametrize('name, exp', [
    ('my-feedstock', 'my-feedstock'),
    ('my-feedstock.git', 'my-feedstock'),
    ('git@github.com:conda-forge/my-feedstock.git', 'my-feedstock'),
    ('http://github.com/conda-forge/my-feedstock.git', 'my-feedstock'),
    ('https://github.com/conda-forge/my-feedstock.git', 'my-feedstock'),
])
def test_feedstock_repo(name, exp):
    obs = feedstock_repo(name)
    assert exp == obs


@pytest.mark.parametrize('feed, username, exp', [
    ('git@github.com:conda-forge/my-feedstock.git', 'zappa',
     'git@github.com:zappa/my-feedstock.git'),
    ('http://github.com/conda-forge/my-feedstock.git', 'zappa',
     'http://github.com/zappa/my-feedstock.git'),
    ('https://github.com/conda-forge/my-feedstock.git', 'zappa',
     'https://github.com/zappa/my-feedstock.git'),
])
def test_fork_url(feed, username, exp):
    obs = fork_url(feed, username)
    assert exp == obs



REVER_XSH = """
$ACTIVITIES = ['conda_forge']
$PROJECT = 'rever'
$GITHUB_CREDFILE = 'credfile'
$GITHUB_ORG = 'regro'
$GITHUB_REPO = 'rever'
$CONDA_FORGE_RERENDER = False
$CONDA_FORGE_PULL_REQUEST = False
"""

CREDFILE = """zappa
45463104f006ccb3a512fb20e31b9a50f10ba38b
55d60676
"""

ORIG_META_YAML = """
{% set name = "rever" %}
{% set version = "0.0.1" %}
{% set sha256 = "01264da25bac23e27ca9298bbfd41f7226854247e92a3edea6f28decf42c7b09" %}

package:
  name: {{ name|lower }}
  version: {{ version }}
  version: 0.0.1

source:
  fn: {{ name }}-{{ version }}.tar.gz
  url: https://github.com/ergs/rever/archive/{{ version }}.tar.gz
  sha256: {{ sha256 }}
  sha256: 01264da25bac23e27ca9298bbfd41f7226854247e92a3edea6f28decf42c7b09

build:
  number: 3
  script: python setup.py install
  skip: True  # [py2k]

requirements:
  build:
    - python
  run:
    - python
    - xonsh
    - lazyasd

test:
  imports:
    - rever
    - rever.activities
  commands:
    - rever -h

about:
  home: http://www.ergs.sc.edu/rever-docs/
  license: BSD 3-Clause
  license_family: BSD
  license_file: LICENSE
  summary: 'Releaser of Versions'
  description: |
    Rever is a xonsh-powered, cross-platform software release tool. The goal of rever is
    to provide sofware projects a standard mechanism for dealing with code released.
    Rever aims to make the process of releasing a new version of a code base as easy as
    running a single command.
  doc_url: http://www.ergs.sc.edu/rever-docs/
  dev_url: https://github.com/ergs/rever

extra:
  recipe-maintainers:
    - scopatz
    - asmeurer
"""

EXP_META_YAML = """
{% set name = "rever" %}
{% set version = "0.1.0" %}
{% set sha256 = "ce8924c4f2feb57f8151bdf8ab002f8fcedebc32855269cffbaa321d5023f352" %}

package:
  name: {{ name|lower }}
  version: {{ version }}
  version: "0.1.0"

source:
  fn: {{ name }}-{{ version }}.tar.gz
  url: https://github.com/ergs/rever/archive/{{ version }}.tar.gz
  sha256: {{ sha256 }}
  sha256: ce8924c4f2feb57f8151bdf8ab002f8fcedebc32855269cffbaa321d5023f352

build:
  number: 0
  script: python setup.py install
  skip: True  # [py2k]

requirements:
  build:
    - python
  run:
    - python
    - xonsh
    - lazyasd

test:
  imports:
    - rever
    - rever.activities
  commands:
    - rever -h

about:
  home: http://www.ergs.sc.edu/rever-docs/
  license: BSD 3-Clause
  license_family: BSD
  license_file: LICENSE
  summary: 'Releaser of Versions'
  description: |
    Rever is a xonsh-powered, cross-platform software release tool. The goal of rever is
    to provide sofware projects a standard mechanism for dealing with code released.
    Rever aims to make the process of releasing a new version of a code base as easy as
    running a single command.
  doc_url: http://www.ergs.sc.edu/rever-docs/
  dev_url: https://github.com/ergs/rever

extra:
  recipe-maintainers:
    - scopatz
    - asmeurer
"""

EXP_META_YAML2 = """
{% set name = "rever" %}
{% set version = "0.2.0" %}
{% set sha256 = "ce8924c4f2feb57f8151bdf8ab002f8fcedebc32855269cffbaa321d5023f352" %}

package:
  name: {{ name|lower }}
  version: {{ version }}
  version: "0.1.0"

source:
  fn: {{ name }}-{{ version }}.tar.gz
  url: https://github.com/ergs/rever/archive/{{ version }}.tar.gz
  sha256: {{ sha256 }}
  sha256: ce8924c4f2feb57f8151bdf8ab002f8fcedebc32855269cffbaa321d5023f352

build:
  number: 0
  script: python setup.py install
  skip: True  # [py2k]

requirements:
  build:
    - python
  run:
    - python
    - xonsh
    - lazyasd

test:
  imports:
    - rever
    - rever.activities
  commands:
    - rever -h

about:
  home: http://www.ergs.sc.edu/rever-docs/
  license: BSD 3-Clause
  license_family: BSD
  license_file: LICENSE
  summary: 'Releaser of Versions'
  description: |
    Rever is a xonsh-powered, cross-platform software release tool. The goal of rever is
    to provide sofware projects a standard mechanism for dealing with code released.
    Rever aims to make the process of releasing a new version of a code base as easy as
    running a single command.
  doc_url: http://www.ergs.sc.edu/rever-docs/
  dev_url: https://github.com/ergs/rever

extra:
  recipe-maintainers:
    - scopatz
    - asmeurer
"""


def test_conda_forge_activity(gitrepo, gitecho):
    vcsutils.tag('0.0.1')
    env = builtins.__xonsh_env__
    recipe_dir = os.path.join(env['REVER_DIR'], 'rever-feedstock', 'recipe')
    meta_yaml = os.path.join(recipe_dir, 'meta.yaml')
    os.makedirs(recipe_dir, exist_ok=True)
    files = [('rever.xsh', REVER_XSH),
             (meta_yaml, ORIG_META_YAML),
             ('credfile', CREDFILE)]
    for filename, body in files:
        with open(filename, 'w') as f:
            f.write(body)
    vcsutils.track('.')
    vcsutils.commit('Some versioned files')
    env_main(['0.1.0'])
    # now see if this works
    with open(meta_yaml, 'r') as f:
        obs = f.read()
    assert EXP_META_YAML == obs

    env_main(['0.2.0'])
    # now see if this works
    with open(meta_yaml, 'r') as f:
        obs = f.read()
    assert EXP_META_YAML2 == obs
