"""Activities for building and uploading to Dockerfiles."""
import os

from xonsh.tools import expand_path, print_color

from rever.activity import Activity
from rever.tools import indir


class DockerBuild(Activity):
    """Builds a Dockerfile.

    The behaviour of this activity may be adjusted through the following
    environment variables:

    :$DOCKER_BUILD_PATH: str, path to the Dockerfile, default (None) looks from
        reads from ``$DOCKERFILE``.
    :$DOCKER_BUILD_CONTEXT: str, directory to execute the build within.
        An empty string indicates that the image should be built in directory
        containing the path. The default (None) reads from ``$DOCKERFILE_CONTEXT``.
    :$DOCKER_BUILD_TAGS: list of str, Tags the ``$DOCKERFILE`` should be built
        and pushed with. Default (None) reads from ``$DOCKERFILE_TAGS``.
    :$DOCKER_BUILD_CACHE: bool, Flag for whether or not to use the cache,
        default False.
    """

    def __init__(self, *, deps=frozenset()):
        super().__init__(name='docker_build', deps=deps, func=self._func,
                         desc="Builds a Dockerfile.")

    def _func(self, path=None, context=None, tags=None, cache=False):
        # get defaults
        path = $DOCKERFILE if path is None else context
        context = $DOCKERFILE_CONTEXT if context is None else context
        tags = $DOCKERFILE_TAGS if tags is None else tags
        # expand paths
        path = expand_path(path)
        context = expand_path(context)
        fname = ''
        if not context:
            context, path = os.path.split(path)
            context = '.' if len(context) == 0 else context
            path, fname = ('.', path) if path == 'Dockerfile' else (path, '')
        tags = list(map(expand_path, tags))
        # get args
        args = []
        for tag in tags:
            args.extend(['-t', tag])
        if not cache:
            args.append('--no-cache')
        if fname:
            args.extend(['-f', fname])
        args.append(path)
        # run build
        with indir(context):
            ![docker build @(args)]


class DockerPush(Activity):
    """Pushes a built Dockerfile.

    The behaviour of this activity may be adjusted through the following
    environment variables:

    :$DOCKER_PUSH_TAGS: list of str, Tags that the ``$DOCKERFILE`` should be built
        and pushed with. Default (None) reads from ``$DOCKERFILE_TAGS``.
    """

    def __init__(self, *, deps=frozenset()):
        super().__init__(name='docker_push', deps=deps, func=self._func,
                         desc="Pushed a Dockerfile.")

    def _func(self, tags=None):
        tags = $DOCKERFILE_TAGS if tags is None else tags
        tags = list(map(expand_path, tags))
        # get args
        args = []
        for tag in tags:
            ![docker push @(tag)]
