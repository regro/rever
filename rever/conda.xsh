from contextlib import contextmanager


@contextmanager
def run_in_conda_env(packages, envname='rever-env'):
    xontrib xonda
    conda create -n @(envname) @(packages)
    conda activate @(envname)
    yield
    conda deactivate
    conda remove -n @(envname) --all
