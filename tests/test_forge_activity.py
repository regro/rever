"""Tests the conda forge activity."""
import os
import builtins

import pytest

from rever import vcsutils
from rever.logger import current_logger
from rever.main import env_main
from rever.activities.forge import get_feedstock_url
from rever.activities.forge import get_feedstock_repo_name
from rever.activities.forge import get_fork_url


@pytest.mark.parametrize('name, org, proto, exp', [
    ('my-feedstock', 'conda-forge', 'ssh', 'git@github.com:conda-forge/my-feedstock.git'),
    ('git@github.com:conda-forge/my-feedstock.git', 'conda-forge', None,
     'git@github.com:conda-forge/my-feedstock.git'),
    ('my-feedstock', 'conda-forge', 'http', 'http://github.com/conda-forge/my-feedstock.git'),
    ('http://github.com/my-custom-forge/my-feedstock.git', 'my-custom-forge', None,
     'http://github.com/my-custom-forge/my-feedstock.git'),
    ('my-feedstock', 'conda-forge', 'https',
     'https://github.com/conda-forge/my-feedstock.git'),
    ('https://github.com/conda-forge/my-feedstock.git', 'conda-forge', None,
     'https://github.com/conda-forge/my-feedstock.git'),
])
def test_feedstock_url(name, org, proto, exp):
    obs = get_feedstock_url(name, feedstock_org=org, protocol=proto)
    assert exp == obs


@pytest.mark.parametrize('name, exp', [
    ('my-feedstock', 'my-feedstock'),
    ('my-feedstock.git', 'my-feedstock'),
    ('git@github.com:conda-forge/my-feedstock.git', 'my-feedstock'),
    ('http://github.com/conda-forge/my-feedstock.git', 'my-feedstock'),
    ('https://github.com/conda-forge/my-feedstock.git', 'my-feedstock'),
])
def test_feedstock_repo(name, exp):
    obs = get_feedstock_repo_name(name)
    assert exp == obs


@pytest.mark.parametrize('feed, username, org, exp', [
    ('git@github.com:my-custom-forge/my-feedstock.git', 'zappa', 'my-custom-forge',
     'git@github.com:zappa/my-feedstock.git'),
    ('http://github.com/conda-forge/my-feedstock.git', 'zappa', 'conda-forge',
     'http://github.com/zappa/my-feedstock.git'),
    ('https://github.com/conda-forge/my-feedstock.git', 'zappa', 'conda-forge',
     'https://github.com/zappa/my-feedstock.git'),
])
def test_fork_url(feed, username, org, exp):
    obs = get_fork_url(feed, username, org)
    assert exp == obs
