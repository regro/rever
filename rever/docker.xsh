"""Dockers tools for rever."""
import textwrap

from xonsh.tools import expand_path

from rever import vcsutils


_TEXT_WRAPPER = None
BASE_DOCKERFILE = """FROM {base_from}

WORKDIR /root

{deps}
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
    tw = text_wrapper()
    tw.initial_indent = tw.subsequent_indent = indent
    tw.width = width
    lines = tw.wrap(s)
    new = (suffix + '\n').join(lines)
    return new


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


def make_base_dockerfile(base_from=None, apt=None, conda=None, conda_channels=None,
                         pip=None, pip_requirements=None):
    """Constructs the base dockerfile."""
    base_from = base_from or $DOCKER_BASE_FROM
    deps = collate_deps(apt=apt, conda=conda, conda_channels=conda_channels,
                        pip=pip, pip_requirements=pip_requirements)
    base = BASE_DOCKERFILE.format(base_from=base_from, deps=deps)
    return base


def docker_root(root=None):
    """Gets the root-level directory for the repo that docker should use."""
    if root:
        return root
    return $DOCKER_ROOT or vcsutils.root()


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


INSTALL_DOCKERFILE = """FROM {base}

ADD {root} /root/project

WORKDIR /root/project

RUN {command}

{envvars}
"""


def make_install_dockerfile(base=None, root=None, command=None, envvars=None):
    """Constructs a dockerfile that installs the source code."""
    base = expand_path(base or $DOCKER_BASE_IMAGE)
    root = docker_root(root)
    command = command or $DOCKER_INSTALL_COMMAND
    if not command:
        raise ValueError('Docker must have an install command! '
                         'Try setting $DOCKER_INSTALL_COMMAND')
    envvars = docker_envvars(envvars or $DOCKER_INSTALL_ENVVARS)
    install = INSTALL_DOCKERFILE.format(base=base, root=root, command=command,
                                        envvars=envvars)
    return install


ACTIVITY_DOCKERFILE = """FROM {install}

{envvars}
RUN {command}
"""


def make_activity_dockerfile(command, install=None, envvars=None):
    """Constructs a dockerfile that runs a command for an activity."""
    install = expand_path(install or $DOCKER_INSTALL_IMAGE)
    envvars = docker_envvars(envvars)
    activity = ACTIVITY_DOCKERFILE.format(base=base, root=root, command=command,
                                          envvars=envvars)
    return activity
