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

    Environment variables that modify this activity's behaviour are:

    :$SPHINX_HOST_DIR:
    """

    _cmd = 'sphinx-build -b {builder} {opts} {build_dir}/{builder}'

    def __init__(self):
        super().__init__(name='sphinx', deps=frozenset(), func=self._func,
                         desc="Runs sphinx inside of a docker container",
                         lang='sh')

    def _func(self, host_dir='$REVER_DIR/sphinx-build', build_dir='$DOCKER_WORKDIR/docs/_build',
              opts=(), paper='', builders=('html',)):
        # first compute the mount point
        host_dir = expand_path(host_dir)
        build_dir = expand_path(build_dir)
        mounts = [{'type': 'bind', 'src': host_dir, 'dst': build_dir}]
        # now get the options for the sphinx-build command
        options = ['-d', os.path.join(build_dir, 'doctrees')]
        if paper:
            options.extend(['-D', 'latex_paper_size=' + paper])
        if opts and not isinstance(opts, str):
            options.extend(opts)
        optstr = ' '.join(options)
        if opts and not isinstance(opts, str):
            optstr += ' ' + opts
        # now build the build command
        cmds = [self._cmd.format(builder=b, opts=optstr, build_dir=build_dir) for b in builders]
        code = ' && '.join(cmds)
        # OK, build the docs!
        super()._func(code=code, mounts=mounts)