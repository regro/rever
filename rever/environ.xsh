"""Custom environment handling tools for rever."""
from contextlib import contextmanager

from xonsh.environ import Ensurer, VarDocs
from xonsh.tools import is_string, ensure_string, always_false

from rever.logger import Logger


def to_logger(x):
    """If x is a string, this will be set as $LOGGER.filename and then returns $LOGGER.
    Otherwise, returns x if x is a Logger already.
    """
    if isinstance(x, Logger):
        rtn = x
    elif isinstance(x, str):
        rtn = $LOGGER
        rtn.filename = x
    else:
        raise ValueError("could not convert {x!r} to a Logger object.".format(x=x))
    return rtn


def detype_logger(x):
    """Returns the filename of the logger."""
    return  x.filename


# key = name
# value = (default, validate, convert, detype, docstr)
ENVVARS = {
    'REVER_VCS': ('git', is_string, str, ensure_string, "Name of version control "
                  "system to use, such as 'git' or 'hg'"),
    'LOGGER': (Logger('/tmp/rever.log'), always_false, to_logger, detype_logger,
               "Rever logger object. Setting this variable to a string will "
               "change the filename of the logger.")
    }


def setup():
    for key, (default, validate, convert, detype, docstr) in ENVVARS.items():
        ${...}._defaults[key] = default
        ${...}._ensurers[key] = Ensurer(validate=validate, convert, detype)
        ${...}._docs[key] = VarDocs(docstr=docstr)


def teardown():
    for key in ENVVARS:
        ${...}._defaults.pop(key)
        ${...}._ensurers.pop(key)
        ${...}._docs.pop(key)


@contextmanager
def context():
    setup()
    yield
    teardown()
