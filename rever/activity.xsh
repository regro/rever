"""Provides basic activity funtionality."""
import sys
import inspect

from rever import vcsutils


class Activity:
    """Activity representing a node in DAG of release tasks."""

    def __init__(self, *, name=None, deps=frozenset(), func=None, undo=None, desc=None):
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
        desc : str, optional
            A short description of this activity
        """
        self.name = name or "nemo"
        self.deps = deps
        self.func = func
        self._undo = undo
        self.desc = desc

    def __str__(self):
        s = '{}: {}'.format(self.name, self.desc)

    def __call__(self):
        log -a @(self.name) -c activity-start @("starting activity " + self.name)
        if self.func is None:
            print('Activity {!r} has no function to call!', file=sys.stderr)
        else:
            self.func()
        log -a @(self.name) -c activity-end @("activity " + self.name + " complete")

    def undo(self):
        """Reverts to the last instance of this activity. This default implementation
        uses the revision in the log file from the last time that the activity was
        started. This may be overridden in a subclass.
        """
        if self._undo is not None:
            self._undo()
            return
        for entry in $LOGGER.load()[::-1]:
            if entry['activity'] == self.name and entry['category'] == 'activity-start':
                rev = entry['rev']
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


def activity(name=None, deps=None, undo=None, desc=None):
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
