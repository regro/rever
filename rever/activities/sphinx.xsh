"""Activity for building sphinx documentation. The doc building happens inside of a docker
container. However, the sphinx build directory is mounted into $REVER_DIR/sphinx-build, so the
built docs are available on the host.
"""
import re

from xonsh.tools import expand_path

from rever import vcsutils
from rever.activity import DockerActivity


class Sphinx(DockerActivity):
    """Runs sphinx inside of a container.
    """

    def __init__(self):
        super().__init__(name='sphinx', deps=frozenset(), func=self._func,
                         desc="Runs sphinx inside of a docker container",
                         lang='sh')

    def _func(self, host_dir='$REVER_DIR/sphinx-build'):
        host_dir = expand_path(host_dir)
        super()._func()