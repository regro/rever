from contextlib import contextmanager

@contextmanager
def run_in_conda_env(packages, envname='rever-env'):
    xontrib load xonda
    xontrib list
    conda create -y -n @(envname) @(packages)
    conda activate @(envname)
    yield
    conda deactivate
    conda remove -y -n @(envname) --all
