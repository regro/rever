"""Provides basic activity funtionality."""
import sys


class Activity:
    """Activity representing a node in DAG of release tasks."""

    def __init__(self, *, name=None, deps=frozenset(), func=None, desc=None):
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
        desc : str, optional
            A short description of this activity
        """
        self.name = name
        self.deps = deps
        self.func = func
        self.desc = desc

    def __str__(self):
        s = '{}: {}'.format(self.name, self.desc)

    def __call__(self):
        if self.func is None:
            print('Activity {!r} has no function to call!', file=sys.stderr)
        else:
            self.func()
