"""Activity for building sphinx documentation. The doc building happens inside of a docker
container. However, the sphinx build directory is mounted into $REVER_DIR/sphinx-build, so the
built docs are available on the host.
"""
import os

from xonsh.tools import expand_path

from rever import vcsutils
from rever.activity import DockerActivity
from rever.tools import user_group


class Sphinx(DockerActivity):
    """Runs sphinx inside of a container.

    Environment variables that modify this activity's behaviour are:

    :$SPHINX_DOCS_DIR: str, the directory in the container that is the root of
        the documentation. This must be an absolute path. Defaults to
        ``'$DOCKER_HOME/$PROJECT/docs'``.
    :$SPHINX_HOST_DIR: str, the directory on the host (ie outside of the container
        to place the built docs in, default ``'$REVER_DIR/sphinx-build'``.
    :$SPHINX_BUILD_DIR: str, the directory in the container where sphinx will
        build the docs, default ``'{docs_dir}/_build'``. If ``'{docs_dir}'`` is
        present in the string, then the string will be formated with the
        value of $SPHINX_DOCS_DIR. Otherwise, enviroment variables will be expanded.
    :$SPHINX_OPTS: str or list of str, Additional options to provide to the sphinx
        builders. Default to no extra options.
    :$SPHINX_PAPER: str, The paper size to use in latex.  Maybe ``''``, ``'a4'``,
        ``'letter'``, or similar.  Defaults to an empty string, which disables this
        option.
    :$SPHINX_BUILDER: list of str, The build targets that sphinx should construct.
        This defaults to ``['html']``.

    As a dockerized activity, the docker environment variables affect the execution
    of the sphinx activity.
    """

    _cmd = 'sphinx-build -b {builder} {opts} {docs_dir} {build_dir}/{builder}'

    def __init__(self):
        super().__init__(name='sphinx', deps=frozenset(), func=self._func,
                         desc="Runs sphinx inside of a docker container",
                         lang='sh')

    def _func(self, docs_dir='$DOCKER_HOME/$PROJECT/docs', host_dir='$REVER_DIR/sphinx-build',
              build_dir='{docs_dir}/_build', opts=(), paper='', builders=('html',)):
        # first compute the mount point
        docs_dir = $SPHINX_DOCS_DIR = expand_path(docs_dir)
        host_dir = os.path.abspath(expand_path(host_dir))
        if '{docs_dir}' in build_dir:
            build_dir = build_dir.format(docs_dir=docs_dir)
        else:
            build_dir = expand_path(build_dir)
        os.makedirs(host_dir, exist_ok=True)
        user, group, uid, gid = user_group(host_dir, return_ids=True)
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
        if gid is None:
            cmds = ['groupadd {group}'.format(group=group),
                    'useradd --gid {gid} {user}'.format(gid=group, user=user)]
        else:
            cmds = ['groupadd --gid {gid} {group}'.format(gid=gid, group=group),
                    'useradd --uid {uid} --gid {gid} {user}'.format(uid=uid,
                                                                    gid=gid,
                                                                    user=user,)]
        cmds.append('cd ' + docs_dir)
        cmds += [self._cmd.format(builder=b, opts=optstr, docs_dir=docs_dir, build_dir=build_dir)
                 for b in builders]
        cmds.append('chown -R {user}:{group} {build_dir}'.format(
                    user=user, group=group, build_dir=build_dir))
        code = ' && '.join(cmds)
        # OK, build the docs!
        super()._func(code=code, mounts=mounts)
