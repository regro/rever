"""Activities for building and uploading to Dockerfiles."""
import os
import sys

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
        requires = {"commands": {"docker": "docker"}}
        super().__init__(name='docker_build', deps=deps, func=self._func,
                         desc="Builds a Dockerfile.", requires=requires)

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
        requires = {"commands": {"docker": "docker"}}
        super().__init__(name='docker_push', deps=deps, func=self._func,
                         desc="Pushed a Dockerfile.", requires=requires,
                         check=self.check_func)

    def _expand_tags(self, tags):
        tags = $DOCKERFILE_TAGS if tags is None else tags
        tags = list(map(expand_path, tags))
        return tags

    def _func(self, tags=None):
        tags = self._expand_tags(tags)
        # get args
        args = []
        for tag in tags:
            ![docker push @(tag)]

    def check_func(self):
        """Checks that we can push a docker container"""
        import json
        import uuid
        import tempfile
        tags = ${...}.get('DOCKER_PUSH_TAGS', None)
        tags = self._expand_tags(tags)
        # There is no Docker API for checking that we have push
        # permissions. So instead, let's build a tiny image and
        # push it to a special rever tag.
        bases = {tag.rpartition(":")[0] for tag in tags}
        tags = [base + ":__rever__" for base in bases]
        data = {
            "tags": tags,
            "user": $REVER_USER,
            "check_id": str(uuid.uuid4()),
            }
        df = ("FROM scratch\n"
              "ADD rever.json /\n")
        print("Docker push check-id: {check_id}\nDocker push tags: {tags}".format(**data),
              file=sys.stderr)
        with tempfile.TemporaryDirectory() as d, indir(d):
            with open('Dockerfile', 'w') as f:
                f.write(df)
            with open('rever.json', 'w') as f:
                json.dump(data, f)
            args = []
            for tag in tags:
                args.extend(['-t', tag])
            ![docker build @(args) .]
        # now try to push the tags
        for tag in tags:
            try:
                ![docker push @(tag)]
            except Exception:
                print_color("{RED}Check failure!{NO_COLOR} Cannot push to docker " +
                            tag.rpartition(":")[0], file=sys.stderr)
                return False
        return True
