"""Activity for running pytest inside of a container."""
import re

from rever import vcsutils
from rever.activity import DockerActivity
from rever.tools import eval_version


class PyTest(DockerActivity):
    """Runs pytest inside of a container.
    """

    def __init__(self):
        super().__init__(name='pytest', deps=frozenset(), func=self._func,
                         desc="Runs pytest inside of a docker container",
                         lang='sh', code='pytest')

    def _func(self, command=None):
        super()._func(code=command)