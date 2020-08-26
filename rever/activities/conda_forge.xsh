"""Activity for updating conda-forge feedstocks."""
from rever.activity import Activity
from rever.activities.forge import Forge


class CondaForge(Forge):
    """Updates conda-forge feedstocks.

    The behaviour of this activity may be adjusted through the following
    environment variables:

    :$CONDA_FORGE_FEEDSTOCK: str or None, feedstock name or URL,
        default ``$PROJECT-feedstock``.
    :$CONDA_FORGE_PROTOCOL: str, one of ``'ssh'``, ``'http'``, or ``'https'``
        that specifies how the activity should interact with github when
        cloning, pulling, or pushing to the feedstock repo. Note that
        ``'ssh'`` requires you to have an SSH key registered with github.
        The default  is ``'ssh'``.
    :$CONDA_FORGE_SOURCE_URL: str, the URL that the recipe will use to
        download the source code. This is needed so that we may update the
        hash of the downloaded file. This string is evaluated with the current
        environment. Default
        ``'https://github.com/$GITHUB_ORG/$GITHUB_REPO/archive/$VERSION.tar.gz'``.
    :$CONDA_FORGE_HASH_TYPE: str, the type of hash that the recipe uses, eg
        ``'md5'`` or ``'sha256'``. Default ``'sha256'``.
    :$CONDA_FORGE_PATTERNS: list or 3-tuples of str, this is list of
        (filename, pattern-regex, replacement) tuples that is evaluated
        inside of the recipe directory. This is similar to the version bump
        pattern structure. Both the pattern-regex str and the replacement str
        will have environment variables expanded. The following environment
        variables are added for this evaluation:

        * ``$SOURCE_URL``: the fully expanded source code URL.
        * ``$HASH_TYPE``: the hash type used to hash ``$SOURCE_URL``.
        * ``$HASH``: the hexdigest of ``$SOURCE_URL``.

        The default patterns match most standard recipes.
    :$CONDA_FORGE_PULL_REQUEST: bool, whether the activity should open
        a pull request to the upstream conda-forge feestock, default True.
    :$CONDA_FORGE_RERENDER: bool, whether the activity should rerender the
        feedstock using conda-smithy, default True.
    :$CONDA_FORGE_FORK: bool, whether the activity should create a new fork of
        the feedstock if it doesn't exist already, default True.
    :$CONDA_FORGE_FORK_ORG: str, the org to fork the recipe to or which holds
        the fork, if ``''`` use the registered gh username, defaults to ``''``

    Other environment variables that affect the behavior are:

    :$GITHUB_CREDFILE: the credential file to use. This should NOT be
        set in the rever.xsh file
    :$GITHUB_ORG: the github organization that the project belongs to.
    :$GITHUB_REPO: the github repository of the project.
    :$TAG_TEMPLATE: str, the template string used to tag the version, by default
        this is '$VERSION'. Used to download project source.
    :$PROJECT: the name of the project being released.
    :$REVER_CONFIG_DIR: the user's config directory for rever, which
      is where the GitHub credential files are stored by default.

    """

    CONDA_FORGE_FEEDSTOCK_ORG = "conda-forge"

    def __init__(self, *, deps=frozenset(("tag", "push_tag"))):
        requires = {
            "imports": {"github3.exceptions": "github3.py"},
            "commands": {"conda": "conda", "conda-smithy": "conda-smithy"},
        }

        Activity.__init__(
            self,
            name="conda_forge",
            deps=deps,
            func=self._func,
            desc="Updates a conda-forge feedstock",
            requires=requires,
            check=self.check_func,
        )

    def _func(
        self,
        feedstock=None,
        protocol=None,
        source_url=None,
        hash_type=None,
        patterns=None,
        pull_request=True,
        rerender=True,
        fork=True,
        fork_org=None,
    ):

        super()._func(
            feedstock=feedstock,
            feedstock_org=CondaForge.CONDA_FORGE_FEEDSTOCK_ORG,
            protocol=protocol,
            source_url=source_url,
            hash_type=hash_type,
            patterns=patterns,
            pull_request=pull_request,
            rerender=rerender,
            fork=fork,
            fork_org=fork_org,
            use_git_url=False,
            recipe_dir=None,
        )
