"""Dockers tools for rever."""
import textwrap

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
    """Constructs the base dockerfile, if needed."""
    base_from = base_from or $DOCKER_BASE_FROM
    deps = collate_deps(apt=apt, conda=conda, conda_channels=conda_channels,
                        pip=pip, pip_requirements=pip_requirements)
    base = BASE_DOCKERFILE.format(base_from=base_from, deps=deps)
    return base
