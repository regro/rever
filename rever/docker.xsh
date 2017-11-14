"""Dockers tools for rever."""
import textwrap

from xonsh.tools import expand_path

from rever import vcsutils


_TEXT_WRAPPER = None
BASE_DOCKERFILE = """FROM {base_from}

{envvars}
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


def make_base_dockerfile(base_from=None, apt=None, conda=None, conda_channels=None,
                         pip=None, pip_requirements=None):
    """Constructs the base dockerfile."""
    base_from = base_from or $DOCKER_BASE_FROM
    deps = collate_deps(apt=apt, conda=conda, conda_channels=conda_channels,
                        pip=pip, pip_requirements=pip_requirements)
    env = {'PROJECT': $PROJECT, 'VERSION': $VERSION, 'REVER_VCS': $REVER_VCS,
           'GITHUB_ORG': $GITHUB_ORG, 'GITHUB_REPO': $GITHUB_REPO,
           'WEBSITE_URL': $WEBSITE_URL}
    env = {k: v for k, v in env.items() if v}
    envvars = docker_envvars(env)
    base = BASE_DOCKERFILE.format(base_from=base_from, deps=deps,
                                  envvars=envvars)
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

