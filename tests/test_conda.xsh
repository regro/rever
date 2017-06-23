from rever.conda import run_in_conda_env

def test_run_in_conda_env():
    with run_in_conda_env(['python', 'numpy']):
        assert 'rever-env' in ':'.join($PATH)
        # xonda doesn't do capturing correctly (https://github.com/gforsyth/xonda/issues/11)
        assert 'rever-env' in $($(which -s conda) info -e)

    assert 'rever-env' not in $PATH
    assert 'rever-env' not in $($(which -s conda) info -e)
