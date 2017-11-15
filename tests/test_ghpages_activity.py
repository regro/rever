"""Tests the github pages activity."""
import pytest

from rever.activities.ghpages import branch_name


@pytest.mark.parametrize('repo, branch, exp', [
    ('git@github.com:myorg/myrepo.git', None, 'gh-pages'),
    ('git@github.com:myorg/myrepo.git', 'gh-pages', 'gh-pages'),
    ('git@github.com:myorg/myorg.github.io.git', None, 'master'),
    ('git@github.com:myorg/myorg.github.com.git', None, 'master'),
    ('https://github.com/myorg/myrepo.git', None, 'gh-pages'),
    ('https://github.com/myorg/myrepo.git', 'gh-pages', 'gh-pages'),
    ('https://github.com/myorg/myorg.github.io.git', None, 'master'),
    ('https://github.com/myorg/myorg.github.com.git', None, 'master'),
])
def test_branch_name(repo, branch, exp):
    obs = branch_name(repo, branch)
    assert exp == obs
