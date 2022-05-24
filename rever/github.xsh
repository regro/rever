"""This module contains tools for interacting with GitHub.

The 'GitHub_raise_for_status' and 'GitHubError' functions are copied directly 
from the doctr package, while the 'get_oauth_token' is a modified version of 
'GitHub_login' from doctr (https://github.com/drdoctr/doctr),
which is distributed with the following 
The MIT License (MIT)

Copyright (c) 2016 Aaron Meurer, Gil Forsyth

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

"""
import os
import sys
import socket
import hashlib
from functools import wraps
from getpass import getpass

from lazyasd import lazyobject
from xonsh.tools import print_color
import webbrowser
import requests
import time

REVER_CLIENT_ID = "0c99261465cac91a1a3f"

@lazyobject
def github3():
    try:
        from github3.github import GitHub
    except ImportError:
        return None
    return GitHub()


def ensure_github(f):
    """Ensure we have github3 before running a function."""
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


def get_oauth_token(client_id, *, headers=None, scope='repo'):
    """
    Login to GitHub.
    This uses the device authorization flow. client_id should be the client id
    for your GitHub application. See
    https://docs.github.com/en/free-pro-team@latest/developers/apps/authorizing-oauth-apps#device-flow.
    'scope' should be the scope for the access token ('repo' by default). See https://docs.github.com/en/free-pro-team@latest/developers/apps/scopes-for-oauth-apps#available-scopes.
    Returns an access token.
    """
    _headers = headers or {}
    headers = {"accept":  "application/json", **_headers}

    r = requests.post("https://github.com/login/device/code",
                      {"client_id": client_id, "scope": scope},
                      headers=headers)
    GitHub_raise_for_status(r)
    result = r.json()
    device_code = result['device_code']
    user_code = result['user_code']
    verification_uri = result['verification_uri']
    expires_in = result['expires_in']
    interval = result['interval']
    request_time = time.time()

    print_color("{YELLOW}Go to "+ verification_uri + "and enter this code:\n")
    print_color("{GREEN}" + user_code + "\n")
    print_color("{YELLOW}Press Enter to open a webbrowser to " + verification_uri)
    input()
    webbrowser.open(verification_uri)
    while True:
        time.sleep(interval)
        now = time.time()
        if now - request_time > expires_in:
            print_color(
                "{RED}Did not receive a response in time. Please try again.")
            return get_oauth_token(client_id=client_id, headers=headers, scope=scope)
        # Try once before opening in case the user already did it
        r = requests.post("https://github.com/login/oauth/access_token",
                          {"client_id": client_id,
                           "device_code": device_code,
                           "grant_type": "urn:ietf:params:oauth:grant-type:device_code"},
                          headers=headers)
        GitHub_raise_for_status(r)
        result = r.json()
        if "error" in result:
            # https://docs.github.com/en/free-pro-team@latest/developers/apps/authorizing-oauth-apps#error-codes-for-the-device-flow
            error = result['error']
            if error == "authorization_pending":
                if 0:
                    print_color("{RED}No response from GitHub yet: trying again")
                continue
            elif error == "slow_down":
                # We are polling too fast somehow. This adds 5 seconds to the
                # poll interval, which we increase by 6 just to be sure it
                # doesn't happen again.
                interval += 6
                continue
            elif error == "expired_token":
                print_color("{RED}GitHub token expired. Trying again...")
                return get_oauth_token(client_id=client_id, headers=headers, scope=scope)
            elif error == "access_denied":
                raise AuthenticationFailed("User canceled authorization")
            else:
                # The remaining errors, "unsupported_grant_type",
                # "incorrect_client_credentials", and "incorrect_device_code"
                # mean the above request was incorrect somehow, which
                # indicates a bug. Or GitHub added a new error type, in which
                # case this code needs to be updated.
                raise AuthenticationFailed(
                    "Unexpected error when authorizing with GitHub:", error)
        else:
            return result['access_token']


class GitHubError(RuntimeError):
    pass


def GitHub_raise_for_status(r):
    """
    Call instead of r.raise_for_status() for GitHub requests
    Checks for common GitHub response issues and prints messages for them.
    """
    # This will happen if the doctr session has been running too long and the
    # OTP code gathered from get_oauth_token has expired.

    # TODO: Refactor the code to re-request the OTP without exiting.
    if r.status_code == 401 and r.headers.get('X-GitHub-OTP'):
        raise GitHubError(
            "The two-factor authentication code has expired. Please run doctr configure again.")
    if r.status_code == 403 and r.headers.get('X-RateLimit-Remaining') == '0':
        reset = int(r.headers['X-RateLimit-Reset'])
        limit = int(r.headers['X-RateLimit-Limit'])
        reset_datetime = datetime.datetime.fromtimestamp(
            reset, datetime.timezone.utc)
        relative_reset_datetime = reset_datetime - \
            datetime.datetime.now(datetime.timezone.utc)
        # Based on datetime.timedelta.__str__
        mm, ss = divmod(relative_reset_datetime.seconds, 60)
        hh, mm = divmod(mm, 60)

        def plural(n):
            return n, abs(n) != 1 and "s" or ""

        s = "%d minute%s" % plural(mm)
        if hh:
            s = "%d hour%s, " % plural(hh) + s
        if relative_reset_datetime.days:
            s = ("%d day%s, " % plural(relative_reset_datetime.days)) + s
        authenticated = limit >= 100
        message = """\
Your GitHub API rate limit has been hit. GitHub allows {limit} {un}authenticated
requests per hour. See {documentation_url}
for more information.
""".format(limit=limit, un="" if authenticated else "un", documentation_url=r.json()["documentation_url"])
        if authenticated:
            message += """
Note that GitHub's API limits are shared across all oauth applications. 
"""
        else:
            message += """
You can get a higher API limit by authenticating.
"""
        message += """
Your rate limits will reset in {s}.\
""".format(s=s)
        raise GitHubError(message)
    r.raise_for_status()


@ensure_github
def credfile_new_format(credfile=None):
    """Check that our credfile conforms to the new format"""
    # The new format should have two lines only,
    # the old format has 3 lines
    if len(open(credfile, 'r').readlines()) == 2:
        return True
    else:
        return False

@ensure_github
def write_credfile(credfile=None, username='', client_id=REVER_CLIENT_ID):
    """Acquires a github token and writes a credentials file."""
    while not username:
        username = input('GitHub Username: ')
    host = socket.gethostname()
    note = 'rever {org}/{repo} {host} {compid}'
    note = note.format(org=$GITHUB_ORG, repo=$GITHUB_REPO,
                       host=host, compid=_compid(host))
    note_url = $WEBSITE_URL
    scopes = ['user', 'repo']
    # We need to include the rever OAuth client ID
    token = get_oauth_token(client_id, scope=scopes)
    credfile = credfilename(credfile)
    with open(credfile, 'w') as f:
        f.write(username + '\n')
        f.write(str(token))
    print_color('{YELLOW}wrote ' + credfile, file=sys.stderr)
    os.chmod(credfile, 0o600)
    print_color('{YELLOW}secured permisions of ' + credfile, file=sys.stderr)


def read_credfile(credfile=None):
    """Reads in a credentials file and returns the username, token, and id."""
    credfile = credfilename(credfile)
    with open(credfile, 'r') as f:
        username = f.readline().strip()
        token = f.readline().strip()
    return username, token


def login(credfile=None, return_username=False):
    """Returns a github object that is logged in."""
    credfile = credfilename(credfile)
    # Check to see if file exists and conforms to new format
    if not os.path.exists(credfile):
        write_credfile(credfile)
    elif not credfile_new_format(credfile):
        write_credfile(credfile)
    username, token = read_credfile()
    github3.login(username, token=token)
    gh = github3
    if return_username:
        return gh, username
    else:
        return gh


def can_login():
    """Checks that we can login to GitHub"""
    try:
        gh, username = login(return_username=True)
    except Exception as e:
        print_color("{RED}Unable to login to GitHub{RESET}", file=sys.stderr)
        print(str(e), file=sys.stderr)
        return False
    print_color("GitHub login as {GREEN}" + username + "{RESET} works!",
                file=sys.stderr)
    return True


def authorizations(gh, number=-1, etag=None):
    """Generator that is API independent of getting the authorizations"""
    authorizations = getattr(gh, 'iter_authorizations', None)
    authorizations = authorizations or getattr(gh, 'authorizations')
    yield from authorizations(number=number, etag=etag)


def create_or_get_release(repo, tag_name, name, target_commitish='master', body=None, draft=False,
                          prerelease=False):
    """A safe way to either get a release object, or create the release if it doesn't exist."""
    try:
        rel = repo.create_release(
            tag_name,
            name=name,
            target_commitish=target_commitish,
            body=body,
            draft=False,
            prerelease=False,
    )
    except github3.exceptions.UnprocessableEntity:
        rel = repo.release_from_tag(tag_name)
    return rel
