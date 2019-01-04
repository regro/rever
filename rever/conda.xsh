import os
import json
from contextlib import contextmanager


def env_exists(envname):
    """Returns True if a conda environment already exists and False otherwise"""
    envs = json.loads($(conda env list --json))["envs"]
    for env in envs:
        if os.path.split(env)[1] == envname:
            return True
    else:
        return False


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
    if env_exists(envname):
        conda remove -y -n @(envname) --all
    conda create -y -n @(envname) @(packages)
    conda activate @(envname)
    yield
    conda deactivate
    conda remove -y -n @(envname) --all
