import pytest

from rever.conda import run_in_conda_env


def test_run_in_conda_env():
    if len(${...}.get("CI", "")) == 0:
        pytest.skip("long tests run on CI")
    with run_in_conda_env(['python', 'numpy']):
        assert 'rever-env' in ':'.join($PATH)
        assert 'rever-env' in $(conda info -e)

    assert 'rever-env' not in $PATH
    assert 'rever-env' not in $(conda info -e)
