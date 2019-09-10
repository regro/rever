"""Some special rever tools"""
import os
import re
import sys
import string
import getpass
import hashlib
import urllib.request
from contextlib import contextmanager
if 'win' not in sys.platform:
    import pwd
    import grp
else:
    pwd = grp = None

from xonsh.tools import expand_path, print_color


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


def replace_in_file(pattern, new, fname, leading_whitespace=True):
    """Replaces a given pattern in a file. If leading whitespace is True,
    whitespace at the begining of a line will be captured and preserved.
    Otherwise, the pattern itself must contain all leading whitespace.
    """
    with open(fname, 'r') as f:
        raw = f.read()
    lines = raw.splitlines()
    if leading_whitespace:
        ptn = re.compile(r'(\s*?)' + pattern)
    else:
        ptn = re.compile(pattern)
    for i, line in enumerate(lines):
        m = ptn.match(line)
        if m is not None:
            lines[i] = m.group(1) + new if leading_whitespace else new
    upd = '\n'.join(lines) + '\n'
    with open(fname, 'w') as f:
        f.write(upd)


@contextmanager
def indir(d):
    """Context manager for temporarily entering into a directory."""
    old_d = os.getcwd()
    ![cd @(d)]
    yield
    ![cd @(old_d)]


def render_authors(authors):
    """Parse a list of of tuples of authors into valid bibtex

    Parameters
    ----------
    authors: list of str
        The authors eg ['Your name in nicely formatted bibtex'].
        Please see ``<http://nwalsh.com/tex/texhelp/bibtx-23.html>`` for
        information about how to format your name for bibtex

    Returns
    -------
    str:
        Valid bibtex authors
    """
    if isinstance(authors, str):
        authors = (authors, )
    if len(authors) == 1:
        return ''.join(authors[0])
    else:
        return ' and '.join(authors)


PONG = ("▐⠂       ▌",
        "▐⠈       ▌",
        "▐ ⠂      ▌",
        "▐ ⠠      ▌",
        "▐  ⡀     ▌",
        "▐  ⠠     ▌",
        "▐   ⠂    ▌",
        "▐   ⠈    ▌",
        "▐    ⠂   ▌",
        "▐    ⠠   ▌",
        "▐     ⡀  ▌",
        "▐     ⠠  ▌",
        "▐      ⠂ ▌",
        "▐      ⠈ ▌",
        "▐       ⠂▌",
        "▐       ⠠▌",
        "▐       ⡀▌",
        "▐      ⠠ ▌",
        "▐      ⠂ ▌",
        "▐     ⠈  ▌",
        "▐     ⠂  ▌",
        "▐    ⠠   ▌",
        "▐    ⡀   ▌",
        "▐   ⠠    ▌",
        "▐   ⠂    ▌",
        "▐  ⠈     ▌",
        "▐  ⠂     ▌",
        "▐ ⠠      ▌",
        "▐ ⡀      ▌",
        "▐⠠       ▌",
        )


_NPONG = 0


def progress(count, total=None, prefix='', suffix='', width=60, file=None,
             fill='`·.,¸,.·*¯`·.,¸,.·*¯', color=None, empty=' ', quiet=False):
    """CLI progress bar"""
    # forked from https://gist.github.com/vladignatyev/06860ec2040cb497f0f3
    # under an MIT license, Copyright (c) 2016 Vladimir Ignatev
    global _NPONG
    orig_file = file
    quiet = quiet or ${...}.get('REVER_QUIET', False)
    if not file:
        if quiet:
            file = open(os.devnull, 'w')
        else:
            file = sys.stdout

    file = sys.stdout if file is None else file
    if total is None:
        bar = PONG[_NPONG]
        _NPONG = (_NPONG + 1)%len(PONG)
        fmt = ('{prefix}{{{color}}}{bar}{{NO_COLOR}} '
               '{frac} bytes{suffix}\r')
        frac = count
    else:
        filler = fill * (1 + width//len(fill))
        filled_len = int(round(width * count / float(total)))
        bar = filler[:filled_len] + empty * (width - filled_len)
        if color is None:
            color = 'YELLOW' if count < total else 'GREEN'
        frac = count / float(total)
        fmt = ('{prefix}[{{{color}}}{bar}{{NO_COLOR}}] '
               '{{{color}}}{frac:.1%}{{NO_COLOR}}{suffix}\r')
    s = fmt.format(prefix=prefix, color=color, bar=bar, frac=frac,
                   suffix=suffix)
    print_color(s, end='', file=file)
    file.flush()
    if not orig_file and quiet:
        file.close()


def stream_url_progress(url, verb='downloading', chunksize=1024, width=60,
                        quiet=False):
    """Generator yielding successive bytes from a URL.

    Parameters
    ----------
    url : str
        URL to open and stream
    verb : str
        Verb to prefix the url downloading with, default 'downloading'
    chunksize : int
        Number of bytes to return, defaults to 1 kb.
    quiet : bool, optional
        If true don't print out progress bar, defaults to False

    Returns
    -------
    yields the bytes which is at most chunksize in length.
    """
    nbytes = 0
    print(verb + ' ' + url)
    with urllib.request.urlopen(url) as f:
        totalbytes = getattr(f, 'length', None)
        while True:
            b = f.read(chunksize)
            lenbytes = len(b)
            nbytes += lenbytes
            if lenbytes == 0:
                break
            else:
                progress(nbytes, totalbytes, width=width, quiet=quiet)
                yield b
            if totalbytes is None:
                totalbytes = getattr(f, 'length', None)
    if totalbytes is None:
        color = 'GREEN'
        suffix = '{GREEN} TOTAL{NO_COLOR}\n'
    elif nbytes < totalbytes:
        color = 'RED'
        suffix = '{RED} FAILED{{NO_COLOR}\n'
    else:
        color = 'GREEN'
        suffix = '{GREEN} SUCCESS{NO_COLOR}\n'
    progress(nbytes, totalbytes, color=color, suffix=suffix)


def hash_url(url, hash='sha256', quiet=False):
    """Hashes a URL, with a progress bar, and returns the hex representation"""
    hasher = getattr(hashlib, hash)()
    for b in stream_url_progress(url, verb='Hashing', quiet=quiet):
        hasher.update(b)
    return hasher.hexdigest()


def download_bytes(url, **kwargs):
    """Gets the bytes from a URL"""
    return b"".join([b for b in stream_url_progress(url, **kwargs)])


def download(url, encoding=None, errors=None, **kwargs):
    """Gets a URL in a given encoding."""
    encoding = $XONSH_ENCODING if encoding is None else encoding
    errors = $XONSH_ENCODING_ERRORS if errors is None else errors
    return download_bytes(url, **kwargs).decode(encoding=encoding, errors=errors)


def user_group(filename, return_ids=False):
    """Returns the user and group name for a file, and optionally ids too.
    returns (user_name, group_name) if return_ids is False. If True, returns
    (user_name, group_name, user_id, group_id).  On windows, the
    user id and group id will be None and the group name will be the same
    as the user name.
    """
    if pwd is None:
        uname = getpass.getuser()
        if return_ids:
            return uname, uname
        else:
            return uname, uname, None, None
    stat = os.stat(filename)
    uid = stat.st_uid
    gid = stat.st_gid
    uname = pwd.getpwuid(uid).pw_name
    gname = grp.getgrgid(gid).gr_name
    if return_ids:
        return uname, gname, uid, gid
    else:
        return uname, gname


def get_format_field_names(s):
    """Returns the set of field names in a format string."""
    formatter = string.Formatter()
    return {field_name for literal_text, field_name, format_spec, conversion in
            formatter.parse(s) if field_name is not None}


def check_gpg():
    """Checks that gpg is available and useable.
    Returns a boolean and message.
    """
    if not bool(!(which gpg)):
        return False, "gpg command not found! Please install gnupg."
    keys = $(gpg --list-keys)
    phrases = ("-----\n", "\npub ", "\nuid ", "\nsub ")
    if not all([phrase in keys for phrase in phrases]):
        return False, "No gpg keys available! Output of 'gpg --list-keys':\n\n" + keys
    return True, "gpg fully available!"
