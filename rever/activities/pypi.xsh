"""Activity for uploading to the Python Package Index."""
import os
import re
import sys
import getpass
from configparser import ConfigParser, ExtendedInterpolation

from lazyasd import lazyobject
from xonsh.tools import expand_path, print_color
from xonsh.lib.os import rmtree

from rever.activity import Activity
from rever.tools import download, check_gpg


def create_rc(rc, username=None, password=None):
    """Creates a pypirc file."""
    if username is None:
        username = input('pypi username: ')
    if password is None:
        password = getpass.getpass('pypi password: ')
    parser = ConfigParser(interpolation=ExtendedInterpolation())
    parser.add_section('distutils')
    parser.set('distutils', 'index-servers', '\npypi')
    parser.add_section('pypi')
    parser.set('pypi', 'username', username)
    parser.set('pypi', 'password', password)
    with open(rc, 'w') as f:
        parser.write(f, False)
    print_color('{YELLOW}wrote ' + rc, file=sys.stderr)
    os.chmod(rc, 0o600)
    print_color('{YELLOW}secured permisions of ' + rc, file=sys.stderr)


def validate_rc(rc):
    """Validate a pypirc file, returns True/False and a message"""
    parser = ConfigParser(interpolation=ExtendedInterpolation())
    parser.read([rc])
    if 'distutils' not in parser:
        return False, 'distutils section not in ' + rc
    if 'index-servers' not in parser['distutils']:
        return False, 'index-servers not in distutils section of ' + rc
    if 'pypi' not in parser:
        return False, 'pypi section not in ' + rc
    if 'repository' in parser['pypi'] and parser['pypi']['repository'] == 'https://pypi.python.org/pypi':
        return False, ('pypi repository "https://pypi.python.org/pypi" is no longer '
                       'supported, please remove this line from ' + rc)
    if 'username' not in parser['pypi']:
        return False, 'username not in pypi section of ' + rc
    if 'password' not in parser['pypi']:
        return False, 'password not in pypi section of ' + rc
    # note that pypi/repository option not required
    return True, ''


@lazyobject
def maintainer_re():
    return re.compile(r'<span class="sidebar-section__maintainer">.*?'
                      r'<a href="/user/(\w+)/" '
                      r'(?:class="sidebar-section__user-gravatar-text"|aria-label="\w+")'
                      r'>.*?</span>', flags=re.DOTALL)


class PyPI(Activity):
    """Uploads a package to the Python Package Index.

    The behaviour of this activity may be adjusted through the following
    environment variables:

    :$PYPI_RC: str, path to the pypirc file, default ``~/.pypirc``.
    :$PYPI_BUILD_COMMANDS: list of str, The commands to run in setup.py
        that will build the project, default ``['sdist']``.  Other examples
        include ``'bdist'`` or ``'bdist_wininst'``.
    :$PYPI_UPLOAD: bool, whether or not to upload PyPI, default True.
    :$PYPI_NAME: str or None, The name of the package on PyPI. If None,
        This will default to the result of ``python setup.py --name``
    :$PYPI_SIGN: bool or None, whether the packages should be signed
        (with gpg) when uploaded. If None (default), packages will be
        signed if a gpg key is available and skipped otherwise.

    Other environment variables that affect the behavior are:

    :$PYTHON: the path to the Python interpreter.
    """

    def __init__(self, *, deps=frozenset(('version_bump',))):
        requires = {"commands": {"twine": "twine"}}
        super().__init__(name='pypi', deps=deps, func=self._func,
                         desc="Uploads to the Python Package Index.",
                         requires=requires, check=self.check_func)

    def _ensure_rc(self, rc, always_return=False):
        rc = expand_path(rc)
        if not os.path.isfile(rc):
            print_color('{YELLOW}WARNING: PyPI run control file ' + rc + \
                        ' does not exist.{NO_COLOR}', file=sys.stderr)
            create_rc(rc)
        valid, msg = validate_rc(rc)
        if not valid:
            if always_return:
                return rc, valid, msg
            else:
                raise RuntimeError(msg)
        if always_return:
            return rc, valid, 'PyPI run control file is valid'
        else:
            return rc

    def _func(self, rc='$HOME/.pypirc', build_commands=('sdist',),
              upload=True, name=None, sign=None):
        rc = self._ensure_rc(rc)
        # isolate distributions for rever
        $dist_dir = os.path.join($REVER_DIR, "dist")
        if os.path.exists($dist_dir):
            rmtree($dist_dir, force=True)
        # build distributions
        dist_in_cmds = any(["dist" in c for c in build_commands])
        dist_dir_in_cmds = any([c.startswith("-d=") or c == "-d" or c.startswith("--dist-dir")
                                for c in build_commands])
        if dist_in_cmds and not dist_dir_in_cmds:
            build_commands = list(build_commands) + ["--dist-dir", $dist_dir]
        p = ![$PYTHON setup.py @(build_commands)]
        if p.rtn != 0:
            raise RuntimeError("Failed to build Python distributions!")
        # upload, as needed
        if upload:
            upload_args = ["upload"]
            if sign:
                upload_args.append("--sign")
            elif sign is None:
                gpg_flag, gpg_msg = check_gpg()
                if gpg_flag:
                    upload_args.append("--sign")
                else:
                    msg = "{YELLOW}Package cannot be signed: " + gpg_msg + "{NO_COLOR}"
                    print_color(msg, file=sys.stderr)
            p = ![twine @(upload_args) $dist_dir/*]
            if p.rtn != 0:
                raise RuntimeError('PyPI upload failed!')
        del $dist_dir

    def check_func(self):
        # First check rc file
        rc = ${...}.get('PYPI_RC', '$HOME/.pypirc')
        rc, valid, msg = self._ensure_rc(rc, always_return=True)
        print_color(msg, file=sys.stderr)
        if not valid:
            return False
        # next check that the PyPI name given is actually a maintainer
        parser = ConfigParser(interpolation=ExtendedInterpolation())
        parser.read([rc])
        username = parser['pypi']['username']
        pypi_name = ${...}.get('PYPI_NAME', None)
        if pypi_name is None:
            pypi_name = $($PYTHON setup.py --name).strip()
        # PyPI does not have an API for this, so we have to check the website
        url = "https://pypi.org/project/" + pypi_name + "/"
        html = download(url, quiet=True)
        maintainers = set(maintainer_re.findall(html))
        if username not in maintainers:
            sys.stdout.flush()
            sys.stderr.flush()
            msg = "{RED}Check failure!{NO_COLOR} " + repr(username)
            msg += " is not in the maintainers list! Valid maintainers are:\n\n* "
            msg += "\n* ".join(sorted(maintainers))
            print_color(msg, file=sys.stderr)
            return False
        # Now check signing capability
        upload = ${...}.get('PYPI_UPLOAD', True)
        sign = ${...}.get('PYPI_SIGN', None)
        if not upload or sign is False:
            pass
        elif sign is None or sign:
            gpg_flag, gpg_msg = check_gpg()
            msg = "{GREEN}" if gpg_flag else "{RED}"
            msg += gpg_msg + "{NO_COLOR}"
            print_color(msg, file=sys.stderr)
            if sign and not gpg_flag:
                return False
        return True
