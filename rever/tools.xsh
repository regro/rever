"""Some special rever tools"""
import os
from contextlib import contextmanager

from xonsh.tools import expand_path

def eval_version(v):
    """Evalauates the argument either as a template string which contains
    $VERSION (or other environment variables) or a callable which
    takes a single argument (that is $VERSION) and returns a string.
    """
    if callable(v):
        rtn = v($VERSION)
    else:
        rtn = expand_path(v)
    return rtn


@contextmanager
def indir(d):
    """Context manager for temporarily entering into a directory."""
    old_d = os.getcwd()
    ![cd @(d)]
    yield
    ![cd @(old_d)]
