"""This module contains tools for interacting with GitHub."""
import os
import sys
import socket
import hashlib
from functools import wraps
from getpass import getpass

from lazyasd import lazyobject
from xonsh.tools import print_color


@lazyobject
def github3():
    try:
        import github3 as gh3
    except ImportError:
        gh3 = None
    return gh3


def ensure_github(f):
    """Ensure we have github3 befire running a function."""
    @wraps(f)
    def dec(*args, **kwargs):
        if github3 is None:
            raise RuntimeError('Must have github3.py installed to '
                               'interact with GitHub.')
        if not $GITHUB_ORG:
            raise RuntimeError('Must know which GitHub organization to '
                               'interact with. Please set $GITHUB_ORG')
        if not $GITHUB_REPO:
            raise RuntimeError('Must know which GitHub repository to '
                               'interact with. Please set $GITHUB_REPO')
        return f(*args, **kwargs)
    return dec


@ensure_github
def credfilename(credfile=None):
    """Returns the path to the creditial file."""
    if credfile is not None:
        f = os.path.abspath(credfile)
        d = os.path.dirname(f)
        os.makedirs(d, exist_ok=True)
    elif $GITHUB_CREDFILE:
        f = os.path.abspath($GITHUB_CREDFILE)
        d = os.path.dirname(f)
        os.makedirs(d, exist_ok=True)
    else:
        d = os.path.join($REVER_CONFIG_DIR, 'github')
        os.makedirs(d, exist_ok=True)
        f = os.path.join(d, $GITHUB_ORG + '-' + $GITHUB_REPO + '.cred')
    return f


def two_factor():
    """2 Factor Authentication callback function, called by
    ``github3.authorize()`` as needed.
    """
    code = ''
    while not code:
        code = input('Enter 2FA code: ')
    return code


def _compid(host=''):
    """Generates a (nominally) unique id for the computer."""
    h = hashlib.sha1(host.encode())
    if sys.platform == 'linux':
        with open('/proc/cpuinfo', 'rb') as f:
            h.update(f.read())
    return h.hexdigest()[:8]


@ensure_github
def write_credfile(credfile=None, username='', password=''):
    """Acquires a github token and writes a credentials file."""
    while not username:
        username = input('GitHub Username: ')
    while not password:
        password = getpass('GitHub Password for {0}: '.format(username))
    host = socket.gethostname()
    note = 'rever {org}/{repo} {host} {compid}'
    note = note.format(org=$GITHUB_ORG, repo=$GITHUB_REPO,
                       host=host, compid=_compid(host))
    note_url = $WEBSITE_URL
    scopes = ['user', 'repo']
    try:
        auth = github3.authorize(username, password, scopes, note, note_url,
                                 two_factor_callback=two_factor)
    except github3.exceptions.UnprocessableEntity:
        print_color('{YELLOW}Token for "' + note + ' "may already exist! '
                    'Attempting to delete and regenerate...{NO_COLOR}', file=sys.stderr)
        gh = github3.login(username, password=password, two_factor_callback=two_factor)
        for auth in authorizations(gh):
            if note == auth.note:
                break
        else:
            msg = 'Could not find GitHub authentication token to delete it!'
            raise RuntimeError(msg)
        auth.delete()
        print_color('{YELLOW}Deleted previous token.{NO_COLOR}')
        auth = github3.authorize(username, password, scopes, note, note_url,
                                 two_factor_callback=two_factor)
        print_color('{YELLOW}Regenerated token.{NO_COLOR}')
    credfile = credfilename(credfile)
    with open(credfile, 'w') as f:
        f.write(username + '\n')
        f.write(str(auth.token) + '\n')
        f.write(str(auth.id))
    print_color('{YELLOW}wrote ' + credfile , file=sys.stderr)
    os.chmod(credfile, 0o600)
    print_color('{YELLOW}secured permisions of ' + credfile, file=sys.stderr)


def read_credfile(credfile=None):
    """Reads in a credentials file and returns the username, token, and id."""
    credfile = credfilename(credfile)
    with open(credfile, 'r') as f:
        username = f.readline().strip()
        token = f.readline().strip()
        ghid = f.readline().strip()
    return username, token, ghid


def login(credfile=None, return_username=False):
    """Returns a github object that is logged in."""
    credfile = credfilename(credfile)
    if not os.path.exists(credfile):
        write_credfile(credfile)
    username, token, _ = read_credfile()
    gh = github3.login(username, token=token)
    if return_username:
        return gh, username
    else:
        return gh


def can_login():
    """Checks that we can login to GitHub"""
    try:
        gh, username = login(return_username=True)
    except Exception as e:
        print_color("{RED}Unable to login to GitHub{NO_COLOR}", file=sys.stderr)
        print(str(e), file=sys.stderr)
        return False
    print_color("GitHub login as {GREEN}" + username + "{NO_COLOR} works!",
                file=sys.stderr)
    return True


def authorizations(gh, number=-1, etag=None):
    """Generator that is API independent of getting the authorizations"""
    authorizations = getattr(gh, 'iter_authorizations', None)
    authorizations = authorizations or getattr(gh, 'authorizations')
    yield from authorizations(number=number, etag=etag)
