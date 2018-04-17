"""Activity for performing a GitHub release."""
import os
import mimetypes

from xonsh.tools import expand_path, print_color

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


def git_archive_asset():
    """Provides tarball of the repository as an asset."""
    template = ${...}.get('TAG_TEMPLATE', '$VERSION')
    tag = eval_version(template)
    fname = os.path.join($REVER_DIR, tag + '.tar.gz')
    print_color('Archiving repository as {INTENSE_CYAN}' + fname + '{NO_COLOR}')
    ![git archive -9 --format=tar.gz -o @(fname) @(tag)]
    return fname


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
    :$GHRELEASE_ASSETS: iterable of str or functions, Extra assests to
        upload to the GitHub release. This is ususally a tarball of the source
        code or a binary package. If the asset is a string, it is interpreted
        as a filename (and evalauated in the current environment). If the asset
        is a function, the function is called with no arguments and should return
        either a string filename or a list of string filenames. The asset
        functions will usually generate or acquire the asset. By default, this
        a tarball of the release tag will be uploaded.

    Other environment variables that affect the behavior are:

    :$GITHUB_CREDFILE: the credential file to use.
    :$GITHUB_ORG: the github organization that the project belongs to.
    :$GITHUB_REPO: the github repository of the project.
    :$REVER_CONFIG_DIR: the user's config directory for rever, which
        is where the GitHub credential files are stored by default.
    :$CHANGELOG_LATEST: path to the latest release notes file
        created by the changelog activity.
    :$TAG_TEMPLATE: may used to find the tag name when creating the default
        asset.

    """

    def __init__(self):
        super().__init__(name='ghrelease', deps=frozenset(), func=self._func,
                         desc="Performs a GitHub release")

    def _func(self, name='$VERSION', notes=None, prepend='', append='',
              assets=(git_archive_asset,)):
        name = eval_version(name)
        notes = find_notes(notes)
        notes = prepend + notes + append
        gh = github.login()
        repo = gh.repository($GITHUB_ORG, $GITHUB_REPO)
        rel = repo.create_release(name, target_commitish='master',
                                  name=name, body=notes,
                                  draft=False, prerelease=False)
        # now upload assets
        for asset in assets:
            if isinstance(asset, str):
                filename = eval_version(asset)
                self._upload_asset(rel, filename)
            elif callable(asset):
                filenames = asset()
                filenames = [filenames] if isinstance(filenames, str) else filenames
                for filename in filenames:
                    filename = eval_version(filename)
                    self._upload_asset(rel, filename)
            else:
                msg = ("Unrecognized type of asset: {0} ({1}). "
                       "Must be str or callable!")
                raise ValueError(msg.format(asset, type(asset)))

    def _upload_asset(self, release, filename):
        """Uploads an asset from a filename"""
        print_color("Uploading {INTENSE_CYAN}" + filename +
                    "{NO_COLOR} to GitHub release")
        with open(filename, 'rb') as f:
            asset = f.read()
        name = os.path.basename(filename)
        content_type = mimetypes.guess_type(name, strict=False)[0]
        release.upload_asset(content_type, name, asset)
