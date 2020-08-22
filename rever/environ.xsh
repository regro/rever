"""Custom environment handling tools for rever."""
import os
import re
import sys
import getpass
import datetime
from ast import literal_eval
from contextlib import contextmanager
from collections.abc import MutableMapping

from xonsh.environ import default_value
from xonsh.tools import (is_string, ensure_string, always_false, always_true, is_bool,
                         is_string_set, csv_to_set, set_to_csv, is_nonstring_seq_of_strings,
                         to_bool, bool_to_str)

from rever.logger import Logger


def is_logger(x):
    """Validates if something is a valid logger"""
    return isinstance(x, Logger)


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


@default_value
def default_dag(env):
    """Creates a default activity DAG."""
    from rever.activities.authors import Authors
    from rever.activities.bibtex import BibTex
    from rever.activities.changelog import Changelog
    from rever.activities.check import Check
    from rever.activities.conda_forge import CondaForge
    from rever.activities.forge import Forge
    from rever.activities.docker import DockerBuild, DockerPush
    from rever.activities.ghpages import GHPages
    from rever.activities.ghrelease import GHRelease
    from rever.activities.nose import Nose
    from rever.activities.pypi import PyPI
    from rever.activities.pytest import PyTest
    from rever.activities.sphinx import Sphinx
    from rever.activities.tag import Tag
    from rever.activities.push_tag import PushTag
    from rever.activities.version_bump import VersionBump
    from rever.activities.gcloud import DeploytoGCloud, DeploytoGCloudApp
    from rever.activities.appimage import AppImage
    dag = {
        'authors': Authors(),
        'bibtex': BibTex(),
        'changelog': Changelog(),
        'check': Check(),
        'conda_forge': CondaForge(),
        'forge': Forge(),
        'docker_build': DockerBuild(),
        'docker_push': DockerPush(),
        'ghpages': GHPages(),
        'ghrelease': GHRelease(),
        'nose': Nose(),
        'pypi': PyPI(),
        'pytest': PyTest(),
        'sphinx': Sphinx(),
        'tag': Tag(),
        'push_tag': PushTag(),
        'version_bump': VersionBump(),
        'deploy_to_gcloud': DeploytoGCloud(),
        'deploy_to_gcloud_app': DeploytoGCloudApp(),
        'appimage': AppImage(),
    }
    return dag


def csv_to_list(x):
    """Converts a comma separated string to a list of strings."""
    return x.split(',')


def list_to_csv(x):
    """Converts a list of str to a comma-separated string."""
    return ','.join(x)


def is_dict_str_str_or_none(x):
    """Checks if x is a mutable mapping from strings to strings or None"""
    if x is None:
        return True
    elif not isinstance(x, MutableMapping):
        return False
    # now we know we have a mapping, check items.
    for key, value in x.items():
        if not isinstance(key, str) or not isinstance(value, str):
            return False
    return True


def is_date(x):
    """Checks if x is a datetime.date object."""
    return isinstance(x, datetime.date)


def str_to_date(s):
    """Converts a string in YYYY-MM-DD format to a date."""
    nums = list(map(int, s.split('-', 2)))
    return datetime.date(*nums)


@default_value
def rever_config_dir(env):
    """Ensures and returns the $REVER_CONFIG_DIR"""
    rcd = os.path.expanduser(os.path.join($XDG_CONFIG_HOME, 'rever'))
    os.makedirs(rcd, exist_ok=True)
    return rcd


@default_value
def today(env):
    """Provides today's date"""
    return datetime.date.today()


# key = name
# value = (default, validate, convert, detype, docstr)
ENVVARS = {
    'ACTIVITIES': ([], is_nonstring_seq_of_strings, csv_to_list, list_to_csv,
                   'Default list of activity names for rever to execute, if they have '
                   'not already been executed.'),
    re.compile(r'ACTIVITIES_\w*'): ([], is_nonstring_seq_of_strings, csv_to_list, list_to_csv,
                                   'A list of activity names for rever to execute for the entry '
                                   'point named after the first underscore.'),
    'DAG': (default_dag(None), always_true, None, str,
                     'Directed acyclic graph of '
                     'activities as represented by a dict with str keys and '
                     'Activity objects as values.'),
    'DOCKERFILE': ('', is_string, str, ensure_string,
                   'Path to Dockerfile, default is empty string.'),
    'DOCKERFILE_CONTEXT': ('', is_string, str, ensure_string,
                           'Context (ie the directory) that the $DOCKERFILE should '
                           'be built in. The default (an empty string) indicates '
                           'that the image should be built in directory containing '
                           'the $DOCKERFILE.'),
    'DOCKERFILE_TAGS': (('$REVER_USER/$PROJECT:$VERSION',
                         '$REVER_USER/$PROJECT:latest'),
                        is_nonstring_seq_of_strings, csv_to_list, list_to_csv,
                        'Tag that the $DOCKERFILE should be built and pushed with. '
                        'The default is ``["$REVER_USER/$PROJECT:$VERSION", '
                        '"$REVER_USER/$PROJECT:latest"]``.'),
    'DOCKER_APT_DEPS': ([], is_nonstring_seq_of_strings, csv_to_list, list_to_csv,
                        'Dependencies to install in the base container via apt-get.'),
    'DOCKER_BASE_FROM': ('debian:latest', is_string, str, ensure_string,
                         'Image to include in the base rever image.'),
    'DOCKER_BASE_IMAGE': ('$PROJECT/rever-base', is_string, str, ensure_string,
                          'Image name for the base docker image. This is evaluated in the '
                          'current environment, default $PROJECT/rever-base'),
    'DOCKER_BASE_FILE': ('$REVER_DIR/rever-base.dockerfile',
                         is_string, str, ensure_string,
                         'Path to base dockerfile, default '
                         '``$REVER_DIR/rever-base.dockerfile``'),
    'DOCKER_CONDA_DEPS': ([], is_nonstring_seq_of_strings, csv_to_list, list_to_csv,
                          'Dependencies to install in the base container via conda.'),
    'DOCKER_CONDA_CHANNELS': (('conda-forge',), is_nonstring_seq_of_strings,
                              csv_to_list, list_to_csv,
                              'Conda channels to use, in order of decreasing precedence. '
                              'Defaults to conda-forge'),
    'DOCKER_GIT_EMAIL': ('', is_string, str, ensure_string,
                         'Email to configure for git in the docker container'),
    'DOCKER_GIT_NAME': ('', is_string, str, ensure_string,
                        'Username to configure for git in the docker container'),
    'DOCKER_HOME': ('/root', is_string, str, ensure_string,
                    'Home directory in the docker container, default /root'),
    'DOCKER_INSTALL_COMMAND': ('', is_string, str, ensure_string,
                               'Command for installing the project that is used in docker.'),
    'DOCKER_INSTALL_ENVVARS': (None, is_dict_str_str_or_none, repr, literal_eval,
                               'Environment variables to set at the end of the '
                               'docker install. May be either a Python dictionary mapping '
                               'string variable names to string values or None, default None.'),
    'DOCKER_INSTALL_FILE': ('$REVER_DIR/rever-install.dockerfile',
                            is_string, str, ensure_string,
                            'Path to base dockerfile, odefault '
                            '``$REVER_DIR/rever-install.dockerfile``'),
    'DOCKER_INSTALL_IMAGE': ('$PROJECT/rever-install', is_string, str, ensure_string,
                             'Image name for the install docker image. This is evaluated in the '
                             'current environment, default $PROJECT/rever-install'),
    'DOCKER_INSTALL_SOURCE': ('', is_string, str, ensure_string,
        'Command for obtaining the source code in the install container.'
        'This command shoudl create the $DOCKER_WORKDIR.'),
    'DOCKER_INSTALL_URL': ('', is_string, str, ensure_string,
                           'URL to clone to in docker in the install image.'),
    'DOCKER_PIP_DEPS': ([], is_nonstring_seq_of_strings, csv_to_list, list_to_csv,
                        'Dependencies to install in the base container via pip.'),
    'DOCKER_PIP_REQUIREMENTS': ([], is_nonstring_seq_of_strings, csv_to_list, list_to_csv,
                                'Requirements files to use in pip install.'),
    'DOCKER_ROOT': ('', is_string, str, ensure_string,
                    'Root directory for docker to use.'),
    'DOCKER_WORKDIR': ('$HOME/$PROJECT', is_string, str, ensure_string,
        'The working directory for the docker container. This is evaluated in '
        'the container itself, default $HOME/$PROJECT'),
    'GCLOUD_PROJECT_ID': ('', is_string, str, ensure_string,
                          'The ID for the gcloud project'),
    'GCLOUD_ZONE': ('us-central1-a', is_string, str, ensure_string,
                    'The gcloud zone'),
    'GCLOUD_CLUSTER': ('', is_string, str, ensure_string,
                       'The kubernetes cluster to deploy to'),
    'GCLOUD_CONTAINER_NAME': ('', is_string, str, ensure_string,
                              'The name of the container image to deploy to'),
    'GCLOUD_DOCKER_HOST': ('docker.io', is_string, str, ensure_string,
                          'The name of the docker host to pull the container from'),
    'GCLOUD_DOCKER_ORG': ('', is_string, str, ensure_string,
                          'The name of the docker org to pull the container from'),
    'GCLOUD_DOCKER_REPO': ('', is_string, str, ensure_string,
                           'The name of the docker container repo to use'),
    'GITHUB_CREDFILE': ('', is_string, str, ensure_string,
                        'GitHub credential file to use'),
    'GITHUB_ORG': ('', is_string, str, ensure_string, 'GitHub organization name'),
    'GITHUB_REPO': ('', is_string, str, ensure_string, 'GitHub repository name'),
    'LOGGER': (Logger('rever.log'), is_logger, to_logger, detype_logger,
               "Rever logger object. Setting this variable to a string will "
               "change the filename of the logger."),
    'PROJECT': ('', is_string, str, ensure_string, 'Project name'),
    'PYTHON': (sys.executable if sys.executable else 'python', is_string, str,
               ensure_string, 'Path to Python executable that rever is run '
                              'with or "python".'),
    'RELEASE_DATE': (today(None), is_date, str_to_date, str,
                     'The date of the release, defaults to today, string '
                     'representations have "YYYY-MM-DD" format.'),
    'REVER_CONFIG_DIR': (rever_config_dir(None), is_string, str, ensure_string,
                         'Path to rever configuration directory'),
    'REVER_DIR': ('rever', is_string, str, ensure_string, 'Path to directory '
                  'used for storing rever temporary files.'),
    'REVER_FORCED': (False, is_bool, str, ensure_string, 'Path to directory '
                     'used for storing rever temporary files.'),
    'REVER_QUIET': (False, is_bool, bool, to_bool,
                    'If True do not write progress during hashing'),
    'REVER_USER': (getpass.getuser(), is_string, to_bool, bool_to_str,
                   "Name of the user who ran the rever command."),
    'REVER_VCS': ('git', is_string, str, ensure_string, "Version control "
                  "system used by rever. May be 'None' to not use "
                  "version control."),
    'RUNNING_ACTIVITIES': ([], is_nonstring_seq_of_strings, csv_to_list, list_to_csv,
                           'List of activity names that rever is actually executing.'),
    'VERSION': ('x.y.z', is_string, str, ensure_string, 'Version string of new '
                'version that is being released.'),
    'WEBSITE_URL': ('', is_string, str, ensure_string,
                    'Project URL, usually for docs.'),
    }


def setup():
    orig_thread_subprocs, $THREAD_SUBPROCS = $THREAD_SUBPROCS, False
    for name, (default, validate, convert, detype, docstr) in ENVVARS.items():
        if name in ${...}:
            del ${...}[name]
        ${...}.register(
            name=name,
            default=default,
            validate=validate,
            convert=convert,
            detype=detype,
            doc=docstr,
        )
    return orig_thread_subprocs


def teardown(orig_thread_subprocs=True):
    for act in $DAG.values():
        act.clear_kwargs_from_env()
    for name in ENVVARS:
        ${...}.deregister(name)
        if name in ${...}:
            del ${...}[name]
    $THREAD_SUBPROCS = orig_thread_subprocs


@contextmanager
def context():
    """A context manager for entering and leaving the rever environment
    safely.
    """
    orig_thread_subprocs = setup()
    yield
    teardown(orig_thread_subprocs=orig_thread_subprocs)


def rever_envvar_names():
    """Returns the rever environment variable names as a set of str."""
    names = set(ENVVARS.keys())
    for act in $DAG.values():
        names.update(act.env_names.values())
    return names


def rever_detype_env():
    """Returns a detyped version of the environment containing only the rever
    environment variables.
    """
    keep = rever_envvar_names()
    denv = {k: v for k, v in ${...}.detype().items() if k in keep}
    return denv
