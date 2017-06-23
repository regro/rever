from contextlib import contextmanager

@contextmanager
def run_in_conda_env(packages, envname='rever-env'):
    """
    Context manager to run in a conda environment

    Examples
    --------

    >>> with run_in_conda_env(['python=3']):
    ...     ./setup.py test

    """
    xontrib load xonda
    conda create -y -n @(envname) @(packages)
    conda activate @(envname)
    yield
    conda deactivate
    conda remove -y -n @(envname) --all
