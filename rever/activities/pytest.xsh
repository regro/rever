"""Activity for running pytest inside of a container."""
import re

from rever import vcsutils
from rever.activity import DockerActivity
from rever.tools import eval_version


class PyTest(DockerActivity):
    """Runs pytest inside of a container.

    The environment variable that affects the behaviour of this activity is:

    :$PYTEST_COMMAND: str, the test command to run. The defaults to
        ``'pytest'``.

    Additionally, the ``$DOCKER_*`` environment variables will affect the
    behaviour of the conatiner that is used for testing.
    """

    def __init__(self):
        super().__init__(name='pytest', deps=frozenset(), func=self._func,
                         desc="Runs pytest inside of a docker container",
                         lang='sh', code='pytest')

    def _func(self, command='pytest'):
        super()._func(code=command)
