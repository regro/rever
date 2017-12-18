"""Provides basic activity funtionality."""
import sys
import inspect
import traceback

from xonsh.tools import expand_path, print_color

from rever import vcsutils
from rever import docker


class Activity:
    """Activity representing a node in DAG of release tasks."""

    def __init__(self, *, name=None, deps=frozenset(), func=None, undo=None,
                 setup=None, args=None, kwargs=None, desc=None):
        """
        Parameters
        ----------
        name : str, optional
            Name of the activity.
        deps : set of str, optional
            Set of activities that must be completed before this activity is
            executed.
        func : callable, optional
            Function to perform as activity when this activities is executed (called).
        undo : callable, optional
            Function to undo this activities behaviour and reset the repo state.
        setup : callable, optional
            Function to help initialize the activity.
        args : tuple, optional
            Arguments to be supplied to the ``func(*args)``, if needed.
        kwargs : mapping, optional
            Keyword arguments to be supplied to the ``func(**kwargs)``, if needed.
        desc : str, optional
            A short description of this activity
        """
        self.name = name or "nemo"
        self.deps = deps
        self.func = func
        self._undo = undo
        self._setup = setup
        self.args = args
        self.kwargs = kwargs
        self.desc = desc
        self._env_names = None
        self.ns = None

    def __str__(self):
        s = '{}: {}'.format(self.name, self.desc)

    def __call__(self):
        start_rev = vcsutils.current_rev()
        log -a @(self.name) -c activity-start @("starting activity " + self.name)
        if self.func is None:
            print('Activity {!r} has no function to call!'.format(self.name),
                  file=sys.stderr)
        else:
            args = self.args or ()
            kwargs = self.all_kwargs()
            try:
                self.func(*args, **kwargs)
            except Exception:
                msg = 'activity failed with execption:\n' + traceback.format_exc()
                msg += 'rewinding to ' + start_rev
                log -a @(self.name) -c activity-error @(msg)
                return False
        data = {"start_rev": start_rev}
        $LOGGER.log(activity=self.name, category="activity-end",
                    message="activity " + self.name + " complete",
                    data=data, version=$VERSION)
        return True

    def undo(self):
        """Reverts to the last instance of this activity. This default implementation
        uses the revision in the log file from the last time that the activity was
        started. This may be overridden in a subclass.
        """
        if self._undo is not None:
            self._undo()
            return
        for entry in $LOGGER.load()[::-1]:
            if entry['activity'] == self.name and entry['category'] == 'activity-end':
                rev = entry['data']['start_rev']
                break
        else:
            raise RuntimeError(self.name + ' activity can not be undone, no starting '
                               'entry found in log.')
        vcsutils.rewind(rev)
        msg = "Reverted {activity} from rev {rev} at {timestamp}".format(**entry)
        log -a @(self.name) -c activity-undo @(msg)

    def undoer(self, undo):
        """Decorator that sets the undo function for this activity."""
        self._undo = undo
        return undo

    def setup(self):
        """Calls this activities setup() initialization function."""
        if self._setup is None:
            print_color('{PURPLE}No setup needed for ' + self.name + ' activity{NO_COLOR}')
            return True
        status = self._setup()
        if not status:
            return status
        msg = 'Setup activity {activity}'.format(activity=self.name)
        log -a @(self.name) -c activity-setup @(msg)
        return True

    def setupper(self, setup):
        """Decorator that sets the setup function for this activity."""
        self._setup = setup
        return setup

    @property
    def env_names(self):
        """Dictionary mapping parameter names to the names of environment
        varaibles that the activity looks for when it is executed.
        """
        if self._env_names is not None:
            return self._env_names
        if self.func is None:
            return {}
        prefix = self.name.upper() + '_'
        params = inspect.signature(self.func).parameters
        self._env_names = {name: prefix + name.upper() for name in params}
        return self._env_names

    def kwargs_from_env(self):
        """Obtains possible func() kwarg from the environment."""
        kwargs = {}
        for name, key in self.env_names.items():
            if key in ${...}:
                kwargs[name] = ${...}[key]
        return kwargs

    def clear_kwargs_from_env(self):
        """Removes kwarg from the environment, if they exist."""
        for key in self.env_names.values():
            if key in ${...}:
                del ${...}[key]

    def all_kwargs(self):
        """Returns all kwargs for this activity."""
        kwargs = self.kwargs_from_env()
        kwargs.update(self.kwargs or {})
        return kwargs


def activity(name=None, deps=frozenset(), undo=None, desc=None):
    """A decorator that turns the function into an activity. The arguments here have the
    same meaning as they do in the Activity class constructor. This decorator also
    registers the activity in the $DAG.
    """
    # handle the @activity case
    def dec(f):
        members = dict(inspect.getmembers(f))
        true_name = name or members['__name__']
        act = Activity(name=true_name, deps=deps, func=f,
                       undo=undo, desc=desc or members['__doc__'])
        $DAG[true_name] = act
        return act
    if callable(name):
        f, name = name, None
        return dec(f)
    else:
        return dec


class DockerActivity(Activity):
    """An activity that executes within a docker container.

    A Docker activity, by default will respect the following environment
    variables, if they are set:

    :$<NAME>_IMAGE: str, Name of the image to run, defaults to
        $DOCKER_INSTALL_IMAGE. Environment variables will be expanded when
        the activity is run.
    :$<NAME>_LANG: str, Language to execute the body in, default xonsh.
        This may also be a full path to an executable.
    :$<NAME>_ARGS: sequence of str, Extra arguments to pass in after
        the executable but before the main body. Defaults to the standard
        compile flag ``'-c'``.
    :$<NAME>_ENV: bool or dict, Environment to use. This has the same meaning as in
        ``rever.docker.run_in_container()``. Please see that function for
        more details, default True.
    :$<NAME>_MOUNT: list of dict, Locations to mount in the running container.
        This has the same meaning as in ``rever.docker.run_in_container()``.
        Please see that function for more details, default does not mount anything.

    Additionally, DockerActivities are macro context managers. This allows you
    to set the code block by entering the context::

        with! DockerActivity(name='myactivity'):
            echo "I will be run in the docker container!"

    Entering the context manager will also automatically register the
    activity in the DAG.
    """

    __xonsh_block__ = str

    def __init__(self, *, name=None, deps=frozenset(), func=None, undo=None,
                 desc=None, image=None, lang='xonsh', run_args=('-c',),
                 code=None, env=True, mounts=()):
        """
        Parameters
        ----------
        name : str, optional
            Name of the activity.
        deps : set of str, optional
            Set of activities that must be completed before this activity is
            executed.
        func : callable, optional
            Function to perform as activity when this activities is executed
            (called).  The default _func method is good enough for most cases.
        undo : callable, optional
            Function to undo this activities behaviour and reset the repo state.
        desc : str, optional
            A short description of this activity
        image : str or None, optional
            Name of the image to run, defaults to $DOCKER_INSTALL_IMAGE.
            Environment variables will be expanded when the activity is run.
        lang : str, optional
            Language to execute the body in, default xonsh. This may also be a full
            path to an executable.
        run_args : sequence of str, optional
            Extra arguments to pass in after the executable but before the
            main body. Defaults to the standard compile flag ``'-c'``.
        code : str or None, optional
            The code to execute in the docker container with lang. If this is
            None, it may be on the instance itself, passed in when the activity
            is called, or set by entering the activity as a macro context manager.
            In this last case, the context block is set as the code.
        env : bool or dict, optional
            Environment to use. This has the same meaning as in
            ``rever.docker.run_in_container()``. Please see that function for
            more details, default True.
        mounts : list of dict, optional
            Locations to mount in the running container. This has the same meaning as
            ing ``run_in_container()``. Please see that function for more details, default
            does not mount anything.

        """
        super().__init__(name=name, deps=deps, func=func or self._func,
                         undo=undo, desc=desc)
        self.image = image
        self.lang = lang
        self.run_args = run_args
        self._code = code
        self.env = env
        self.mounts = mounts

    @property
    def code(self):
        """Get's the code to execute in the docker container."""
        if not self._code:
            mb = getattr(self, macro_block, None)
            if mb:
                self._code = mb
            else:
                raise RuntimeError(self.__class__.__name__ + ' has no code '
                                   'to execute in a docker container.')
        return self._code

    @code.setter
    def code(self, value):
        self._code = value

    def __enter__(self):
        self.code = self.macro_block
        $DAG[self.name] = self
        return self

    def __exit__(self, *exc):
        # no reason to keep these attributes around.
        del self.macro_globals, self.macro_locals

    def _func(self, image=None, lang=None, args=None, code=None, env=None, mounts=None):
        image = expand_path(self.image or $DOCKER_INSTALL_IMAGE)
        lang = lang or self.lang
        args = self.run_args if args is None else args
        code = self.code if code is None else code
        env = self.env if env is None else env
        mounts = self.mounts if mounts is None else mounts
        # first make sure we have a container execute in
        if self.ns is None:
            force_base = force_install = False
        else:
            force_base = self.ns.docker_base
            force_install = self.ns.docker_install
        docker.ensure_images(force_base=force_base, force_install=force_install)
        # now actually run the container
        command = [lang]
        command.extend(args)
        command.append(code)
        rtn = docker.run_in_container(image, command, env=env, mounts=mounts)
        return rtn


def dockeractivity(**kwargs):
    """Returns a new docker activity. This accepts the same keyword arguments
    as the DockerActivity class.
    """
    return DockerActivity(**kwargs)
