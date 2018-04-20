"""Dockers tools for rever."""
import os
import sys
import textwrap
from collections.abc import MutableMapping

from xonsh.tools import expand_path, print_color

from rever import vcsutils
from rever import environ


_TEXT_WRAPPER = None
BASE_DOCKERFILE = """
FROM {base_from}

{envvars}
WORKDIR /root

{deps}

{git_config}
"""


def text_wrapper():
    """Obtains docker text wrapper."""
    global _TEXT_WRAPPER
    if _TEXT_WRAPPER is not None:
        return _TEXT_WRAPPER
    tw = textwrap.TextWrapper(break_on_hyphens=False, break_long_words=False)
    _TEXT_WRAPPER = tw
    return tw


def wrap(s, indent='', suffix=' \\', width=70):
    """Wraps a dockerfile line."""
    tw = text_wrapper()
    tw.initial_indent = tw.subsequent_indent = indent
    tw.width = width
    lines = tw.wrap(s)
    new = (suffix + '\n').join(lines)
    return new


def docker_envvars(envvars=None):
    """Constructs a string that sets envvars in docker from a dictionary mapping
    environment variable names to value strings.
    """
    if not envvars:
        return ''
    s = ''
    t = 'ENV {0} {1}\n'
    for var, value in sorted(envvars.items()):
        s += t.format(var, value)
    return s


def apt_deps(apt=None):
    """Constructs apt-based install command"""
    apt = apt or $DOCKER_APT_DEPS
    if not apt:
        return ''
    s = ('RUN apt-get -y update && \\\n'
         '    apt-get install -y --fix-missing \\\n')
    s += wrap(' '.join(sorted(apt)), indent=' '*8) + ' && \\\n'
    s += '    apt-get clean -y\n\n'
    return s


def conda_deps(conda=None, conda_channels=None):
    """Constructs conda-based install command"""
    conda = conda or $DOCKER_CONDA_DEPS
    if not conda:
        return ''
    channels = $DOCKER_CONDA_CHANNELS if conda_channels is None else conda_channels
    s = 'RUN conda config --set always_yes yes && \\\n'
    if channels:
        for channel in channels[::-1]:
            s += '    conda config --add channels ' + channel + ' && \\\n'
    s += '    conda update --all --update-deps && \\\n'
    s += '    conda update --all && \\\n'
    s += '    conda install \\\n'
    s += wrap(' '.join(sorted(conda)), indent=' '*8) + ' && \\\n'
    s += '    conda clean --all && \\\n'
    s += '    conda info\n\n'
    return s


def pip_deps(pip=None, pip_requirements=None):
    """Constructs pip-based install command"""
    pip = pip or $DOCKER_PIP_DEPS
    reqs = pip_requirements or $DOCKER_PIP_REQUIREMENTS
    if not pip and not reqs:
        return ''
    inst = []
    if reqs:
        inst += ['-r ' + r for r in reqs]
    if pip:
        inst += pip
    s = 'RUN pip install \\\n'
    s += wrap(' '.join(inst), indent=' '*4) + '\n\n'
    return s


def collate_deps(apt=None, conda=None, conda_channels=None,
                 pip=None, pip_requirements=None):
    """Constructs a string that installs all known dependencies."""
    s = ''
    s += apt_deps(apt)
    s += conda_deps(conda, conda_channels)
    s += pip_deps(pip, pip_requirements)
    return s


def git_configure(name=None, email=None):
    """Make basic git configuration."""
    name = name or $DOCKER_GIT_NAME
    email = email or $DOCKER_GIT_EMAIL
    if not name and not email:
        return ''
    cmd = 'RUN '
    if name:
        cmd += 'git config --global user.name "{0}"'.format(name)
        if email:
            cmd += ' && \\\n    '
        else:
            cmd += '\n'
    if email:
        cmd += 'git config --global user.email "{}"\n'.format(email)
    return cmd


def make_base_dockerfile(base_from=None, apt=None, conda=None, conda_channels=None,
                         pip=None, pip_requirements=None, git_name=None,
                         git_email=None):
    """Constructs the base dockerfile."""
    base_from = base_from or $DOCKER_BASE_FROM
    deps = collate_deps(apt=apt, conda=conda, conda_channels=conda_channels,
                        pip=pip, pip_requirements=pip_requirements)
    env = {'PROJECT': $PROJECT, 'VERSION': $VERSION, 'REVER_VCS': $REVER_VCS,
           'GITHUB_ORG': $GITHUB_ORG, 'GITHUB_REPO': $GITHUB_REPO,
           'WEBSITE_URL': $WEBSITE_URL, 'HOME': $DOCKER_HOME}
    env = {k: v for k, v in env.items() if v}
    envvars = docker_envvars(env)
    git_config = git_configure(name=git_name, email=git_email)
    base = BASE_DOCKERFILE.format(base_from=base_from, deps=deps,
                                  envvars=envvars, git_config=git_config)
    base = base.strip() + '\n'
    return base


def docker_root(root=None):
    """Gets the root-level directory for the repo that docker should use."""
    if root:
        return root
    return $DOCKER_ROOT or vcsutils.root()


def docker_source_from(source=None, url=None, root=None, workdir=None):
    """This constructs a docker command detailing how to get the source
    code for the project. In order of precedence, this will use,

    * A command as provided by source or $DOCKER_INSTALL_SOURCE
    * A URL to clone with $REVER_VCS as provided by url or $DOCKER_INSTALL_URL
    * A directory on the file system, defaulting to $DOCKER_ROOT or
      the root directory of the project repo.

    """
    url = url or $DOCKER_INSTALL_URL
    source = source or $DOCKER_INSTALL_SOURCE
    if source:
        s = 'RUN ' + source
    elif url:
        workdir = workdir or $DOCKER_WORKDIR
        s = 'RUN {vcs} clone {url} {workdir}'
        s = s.format(vcs=$REVER_VCS, url=url, workdir=workdir)
    else:
        root = docker_root(root)
        root = os.path.relpath(root, '.')
        workdir = workdir or $DOCKER_WORKDIR
        s = 'ADD {root} {workdir}'.format(root=root, workdir=workdir)
    return s


INSTALL_DOCKERFILE = """FROM {base}

{source_from}

WORKDIR {workdir}

RUN {command}

{envvars}
"""


def make_install_dockerfile(base=None, root=None, command=None, envvars=None,
                            workdir=None, url=None, source=None):
    """Constructs a dockerfile that installs the source code."""
    base = expand_path(base or $DOCKER_BASE_IMAGE)
    workdir = workdir or $DOCKER_WORKDIR
    source_from = docker_source_from(source=None, url=url, root=root,
                                     workdir=workdir)
    command = command or $DOCKER_INSTALL_COMMAND
    if not command:
        raise ValueError('Docker must have an install command! '
                         'Try setting $DOCKER_INSTALL_COMMAND')
    envvars = docker_envvars(envvars or $DOCKER_INSTALL_ENVVARS)
    install = INSTALL_DOCKERFILE.format(base=base, command=command,
                                        envvars=envvars, workdir=workdir,
                                        source_from=source_from)
    return install


def should_build_image(dockerfile, image, maker, force=False, **kwargs):
    """Determines if we should (re)build the dockerfile image."""
    if force:
        return True
    if not os.path.isfile(dockerfile):
        return True
    # dockerfile exists, let's check contents
    with open(dockerfile, 'r') as f:
        current = f.read()
    new = maker(**kwargs)
    if current != new:
        return True
    # current dockerfile is up-to-date, let's check if the image exists
    # an empty image-id means the image does not exist
    imageid = $(docker images -q @(image)).strip()
    return not imageid


def build_image(dockerfile, image, maker, **kwargs):
    """Builds a docker image."""
    s = maker(**kwargs)
    with open(dockerfile, 'w') as f:
        f.write(s)
    print_color('{PURPLE}Wrote ' + dockerfile + '{NO_COLOR}')
    print_color('{CYAN}Building docker image ' + image + ' ...{NO_COLOR}')
    ![docker build -t @(image) -f @(dockerfile) --no-cache .]


def ensure_images(base_file=None, base_image=None, force_base=False,
                  base_from=None, apt=None, conda=None, conda_channels=None,
                  pip=None, pip_requirements=None,
                  install_file=None, install_image=None, force_install=False,
                  root=None, command=None, envvars=None, workdir=None,
                  url=None, source=None):
    """This verifies that docker images have been built for rever, and builds
    them if they haven't.
    """
    # ensure base build
    base_file = expand_path(base_file or $DOCKER_BASE_FILE)
    base_image = expand_path(base_image or $DOCKER_BASE_IMAGE)
    base_kwargs = dict(base_from=base_from, apt=apt, conda=conda,
                       conda_channels=conda_channels, pip=pip,
                       pip_requirements=pip_requirements)
    should_build_base = should_build_image(base_file, base_image,
                                           make_base_dockerfile, force=force_base,
                                           **base_kwargs)
    if should_build_base:
        build_image(base_file, base_image, make_base_dockerfile, **base_kwargs)
    # ensure install build
    install_file = expand_path(install_file or $DOCKER_INSTALL_FILE)
    install_image = expand_path(install_image or $DOCKER_INSTALL_IMAGE)
    install_kwargs = dict(base=base_image, root=root, command=command,
                          envvars=envvars, workdir=workdir, url=url,
                          source=source)
    if should_build_base:
        should_build_install = True
    else:
        should_build_install = should_build_image(install_file, install_image,
                                                  make_install_dockerfile,
                                                  force=force_install,
                                                  **install_kwargs)
    if should_build_install:
        build_image(install_file, install_image, make_install_dockerfile,
                    **install_kwargs)


_SUPPORTS_MOUNT = None


def supports_mount():
    """Checks if docker run supports the --mount option."""
    global _SUPPORTS_MOUNT
    if _SUPPORTS_MOUNT is not None:
        return _SUPPORTS_MOUNT
    out = $(docker run --help)
    _SUPPORTS_MOUNT = '--mount' in out
    return _SUPPORTS_MOUNT


VALID_MOUNT_KEYS = frozenset(['type', 'src', 'source', 'dst', 'destination', 'target',
                              'ro', 'readonly', 'consistency'])
VALID_MOUNT_TYPES = frozenset(['volume', 'bind', 'tmpfs'])
VALID_MOUNT_SRCS = frozenset(['src', 'source'])
VALID_MOUNT_DSTS = frozenset(['dst', 'destination', 'target'])
VALID_MOUNT_ROS = frozenset(['ro', 'readonly'])
VALID_MOUNT_CONSISTENCY = frozenset(['default', 'consistent', 'cached', 'delegated'])


def validate_mount(mount):
    """Validates a docker mount description. Returns a boolean flag and a message."""
    msgs = []
    keys = set(mount.keys())
    key_diff = keys - VALID_MOUNT_KEYS
    if len(key_diff) > 0:
        msg = 'docker mount contains unrecognized keys: ' + ' '.join(key_diff)
        msgs.append(msg)
    if 'type' in mount and mount['type'] not in VALID_MOUNT_TYPES:
        msg = 'mount type not recognized {0!r}'.format(mount['type'])
        msgs.append(msg)
    if len(keys & VALID_MOUNT_SRCS) > 1:
        msg = 'both src and source keys are present, only one is allowed'
        msgs.append(msg)
    dst_keys = keys & VALID_MOUNT_DSTS
    if len(dst_keys) != 1:
        if len(dst_keys) == 0:
            msg = "a destination key must be present, got zero"
        else:
            msg = 'got more than 1 destination key: ' + ' '.join(dst_keys)
        msgs.append(msg)
    if len(keys & VALID_MOUNT_ROS) > 1:
        msg = 'recieved too many read-only keys'
        msgs.append(msg)
    if 'consistency' in keys and mount['consistency'] not in VALID_MOUNT_CONSISTENCY:
        msg = 'invalid consistency given to mount {0!r}'.format(mount['consistency'])
        msgs.append(msg)
    return (True, '') if len(msgs) == 0 else (False, ' AND '.join(msgs))


def mount_argument(mount):
    """Creates a mount command argument from a mount dictionary."""
    args = []
    keys = set(mount.keys())
    if 'type' in mount:
        args.append('type=' + mount['type'])
    src_keys = keys & VALID_MOUNT_SRCS
    if len(src_keys) == 1:
        src_key = src_keys.pop()
        args.append(src_key + '=' + mount[src_key])
    dst_keys = keys & VALID_MOUNT_DSTS
    dst_key = dst_keys.pop()
    args.append(dst_key + '=' + mount[dst_key])
    ro_keys = keys & VALID_MOUNT_ROS
    if len(ro_keys) == 1:
        ro_key = ro_keys.pop()
        val = 'true' if bool(mount[ro_key]) else 'false'
        args.append(ro_key + '=' + val)
    if 'consistency' in keys:
        args.append('consistency=' + mount['consistency'])
    return ','.join(args)


def volume_arguments(mount):
    """Creates a list of volume arguments for older versions of docker that
    don't support --mount.
    """
    vargs = []
    keys = set(mount.keys())
    t = mount.get('type', 'bind')
    dst_keys = keys & VALID_MOUNT_DSTS
    dst_key = dst_keys.pop()
    if t == 'tempfs':
        vargs.append('--tmpfs')
        vargs.append(mount[dst_key])
    else:
        ro_keys = keys & VALID_MOUNT_ROS
        if len(ro_keys):
            ro_key = ro_keys.pop()
            vargs.append('--read-only')
        vargs.append('--volume')
        src_keys = keys & VALID_MOUNT_SRCS
        src_key = src_keys.pop()
        vargs.append(mount[src_key] + ':' +  mount[dst_key])
    return vargs


def run_in_container(image, command, env=True, mounts=()):
    """Run a command inside of a docker container.

    Parameters
    ----------
    image : str
        Name of the image to start the container with.
    command : list of str
        The command to run inside of the container.
    env : bool or dict, optional
        If False, not environment variables are passed down to the container.
        If True, all rever environment variables are passed into the container (default).
        Otherwise, this is a dictionary of enviroment variable names (str) to values (str).
    mounts : list of dict, optional
        This is a list of dictionaries that specifies files or directories, volumes, or
        temporary file systems to mount.  Valid keys in the dictionary are:

        * ``'type'``
        * ``'src'`` or ``'source'``
        * ``'dst'`` or ``'destination'`` or ``'target'``
        * ``'ro'`` or  ``'readonly'``
        * ``'consistency'``

        See https://docs.docker.com/engine/reference/commandline/service_create/#add-bind-mounts-volumes-or-memory-filesystems
        for more information
    """
    # get the environment
    if not env:
        env = {}
    elif isinstance(env, MutableMapping):
        pass
    else:
        env = environ.rever_detype_env()
    env_args = []
    for key, val in env.items():
        env_args.append('--env')
        env_args.append(key + '=' + val)
    may_use_mount = supports_mount()
    mount_args = []
    for mount in mounts:
        flag, msg = validate_mount(mount)
        if not flag:
            raise ValueError(msg)
        if may_use_mount:
            mount_args.append('--mount')
            mount_args.append(mount_argument(mount))
        else:
            mount_args.extend(volume_arguments(mount))
    ![docker run -t @(env_args) @(mount_args) @(image) @(command)]


class InContainer(object):
    """Macro context manager for running code within a container. This runs
    a command of the following form within the container::

        lang args block

    For example::

        xonsh -c "echo Wow Mom!\\n"

    This allows you to run your own code within a container without having to
    worry about polluting the local namespace.
    """

    __xonsh_block__ = str

    def __init__(self, image=None, lang='xonsh', args=('-c',), env=True,
                 mounts=(), **kwargs):
        """
        Parameters
        ----------
        image : str or None, optional
            Name of the image to run, defaults to $DOCKER_INSTALL_IMAGE. Environment
            variables will be expanded.
        lang : str, optional
            Language to execute the body in, default xonsh. This may also be a full
            path to an executable.
        args : sequence of str, optional
            Extra arguments to pass in after the executable but before the main body.
            Defaults to the standard compile flag ``'-c'``.
        env : bool or dict, optional
            Environment to use. This has the same meaning as in ``run_in_container()``.
            Please see that function for more details, default True.
        mounts : list of dict, optional
            Locations to mount in the running container. This has the same meaning as
            ing ``run_in_container()``. Please see that function for more details, default
            does not mount anything.
        kwargs : dict, optional
            All other keyword arguments are passed into ``ensure_images()`` when the
            context is entered.

        """
        self.image = expand_path(image or $DOCKER_INSTALL_IMAGE)
        self.lang = lang
        self.args = args
        self.env = env
        self.mounts = mounts
        self.kwargs = kwargs

    def __enter__(self):
        # first make sure we have a container execute in
        ensure_images(**self.kwargs)
        # now actually run the container
        command = [self.lang]
        command.extend(self.args)
        command.append(self.macro_block)
        rtn = run_in_container(self.image, command, env=self.env, mounts=self.mounts)
        return rtn

    def __exit__(self, *exc):
        # no reason to keep these attributes around.
        del self.macro_globals, self.macro_locals


def incontainer(*args, **kwargs):
    """Macro context manager for running code within a container.

    Parameters
    ----------
    image : str or None, optional
        Name of the image to run, defaults to $DOCKER_INSTALL_IMAGE. Environment
        variables will be expanded.
    lang : str, optional
        Language to execute the body in, default xonsh. This may also be a full
        path to an executable.
    args : sequence of str, optional
        Extra arguments to pass in after the executable but before the main body.
        Defaults to the standard compile flag ``'-c'``.
    env : bool or dict, optional
        Environment to use. This has the same meaning as in ``run_in_container()``.
        Please see that function for more details, default True.
    mounts : list of dict, optional
        Locations to mount in the running container. This has the same meaning as
        in ``run_in_container()``. Please see that function for more details, default
        does not mount anything.
    kwargs : dict, optional
        All other keyword arguments are passed into ``ensure_images()`` when the
        context is entered.

    Returns
    -------
    New macro context manager InContainer instance.

    """
    return InContainer(*args, **kwargs)
