"""Some special rever tools"""
import ast

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


def find_version(filename):
    with open(filename) as f:
        initlines = f.readlines()
    version_line = None
    for line in initlines:
        if line.startswith('__version__'):
            vstr = line.strip().split()[-1]
            ver = ast.literal_eval(vstr)
            break
    return ver