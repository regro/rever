"""Activity for performing a GitHub release."""
import os

from xonsh.tools import expand_path

from rever import github
from rever.activity import Activity
from rever.tools import eval_version


def read_file_if_exists(filename):
    """Reads file if it exists, returns None otherwise"""
    if os.path.isfile(filename):
        with open(filename, 'r') as f:
            s = f.read()
        return s
    return None


def find_notes(notes):
    """Tries to find the release notes in a variety of places."""
    if notes is not None:
        return notes
    if 'CHANGELOG_LATEST' in ${...}:
        notes = read_file_if_exists($CHANGELOG_LATEST)
        if notes is not None:
            return notes
    rever_latest = expand_path('$REVER_DIR/LATEST')
    notes = read_file_if_exists(rever_latest)
    if notes is not None:
        return notes
    return ''


class GHRelease(Activity):
    """Performs a github release.

    The behaviour of this activity may be adjusted through the following
    environment variables:

    :$GHRELEASE_NAME: str, Name of the release.  This is evaluated with the
        version. Default is ``$VERSION``
    :$GHRELEASE_NOTES: str or None, Release notes to send to the release
        page. If None (the default), this is read from ``$CHANGELOG_LATEST``,
        if present, or failing that ``$REVER_DIR/LATEST``. If neither file exists,
        an empty string is passes in.
    :$GHRELEASE_PREPEND: str, string to prepend to the release notes,
        defaults to ''
    :$GHRELEASE_APPEND: str, string to append to the release notes,
        defaults to ''

    Other environment variables that affect the behavior are:

    :$GITHUB_CREDFILE: the credential file to use.
    :$GITHUB_ORG: the github organization that the project belongs to.
    :$GITHUB_REPO: the github repository of the project.
    :$REVER_CONFIG_DIR: the user's config directory for rever, which
        is where the GitHub credential files are stored by default.
    :$CHANGELOG_LATEST: path to the latest release notes file
        created by the changelog activity.

    """

    def __init__(self):
        super().__init__(name='ghrelease', deps=frozenset(), func=self._func,
                         desc="Performs a GitHub release")

    def _func(self, name='$VERSION', notes=None, prepend='', append=''):
        name = eval_version(name)
        notes = find_notes(notes)
        notes = prepend + notes + append
        gh = github.login()
        repo = gh.repository($GITHUB_ORG, $GITHUB_REPO)
        repo.create_release(name, target_commitish='master',
                            name=name, body=notes,
                            draft=False, prerelease=False)
