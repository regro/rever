from rever.conda import run_in_conda_env

def test_run_in_conda_env():
    with run_in_conda_env(['python', 'numpy']):
        assert 'rever-env' in ':'.join($PATH)
        assert 'rever-env' in $(conda info -e)

    assert 'rever-env' not in $PATH
    assert 'rever-env' not in $(conda info -e)
