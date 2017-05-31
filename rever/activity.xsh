"""Provides basic activity funtionality."""
import sys
import inspect
import traceback

from rever import vcsutils


class Activity:
    """Activity representing a node in DAG of release tasks."""

    def __init__(self, *, name=None, deps=frozenset(), func=None, undo=None,
                 args=None, kwargs=None, desc=None):
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
        args : tuple, optional
            Arguments to be supplied to the func(*args), if needed.
        kwargs : mapping, optional
            Keyword arguments to be supplied to the func(**kwargs), if needed.
        desc : str, optional
            A short description of this activity
        """
        self.name = name or "nemo"
        self.deps = deps
        self.func = func
        self._undo = undo
        self.args = args
        self.kwargs = kwargs
        self.desc = desc

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
            kwargs = self.kwargs or {}
            try:
                self.func(*args, **kwargs)
            except Exception:
                msg = 'activity failed with execption:\n' + traceback.format_exc()
                msg += 'rewinding to ' + start_rev
                log -a @(self.name) -c activity-error @(msg)
                vcsutils.rewind(start_rev)
                return False
        $LOGGER.log(activity=self.name, category="activity-end",
                    message="activity " + self.name + " complete",
                    data={"start_rev": start_rev})
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


def activity(name=None, deps=frozenset(), undo=None, desc=None):
    """A decorator that turns the function into an activity. The arguments here have the
    same meaning as they do in the Activity class constructor. This decorator also
    registers the activity in the $ACTIVITY_DAG.
    """
    # handle the @activity case
    def dec(f):
        members = dict(inspect.getmembers(f))
        true_name = name or members['__name__']
        act = Activity(name=true_name, deps=deps, func=f,
                       undo=undo, desc=desc or members['__doc__'])
        $ACTIVITY_DAG[true_name] = act
        return act
    if callable(name):
        f, name = name, None
        return dec(f)
    else:
        return dec
