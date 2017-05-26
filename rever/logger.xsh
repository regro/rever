"""Logging tools for rever"""
import json
import time
import argparse

from rever.vcsutils import current_rev


class Logger:
    """A logging object for rever that stores information in line-oriented JSON
    format.
    """

    def __init__(self, filename):
        """
        Parameters
        ----------
        filename : str
            Path to logfile.
        """
        self.filename = filename
        self._argparser = None

    def log(self, message, activity=None):
        """Logs a message, teh associated activity (optional), the timestamp, and the
        current revision to the log file.
        """
        entry = {'message': message, 'timestamp': time.time(),
                 'rev': current_rev()}
        if activity is not None:
            entry['activity'] = activity
        with open(self.filename, 'a+') as f:
            json.dump(entry, f, sort_keys=True, separators=(',', ':'))

    def load(self):
        """Loads all of the records from the logfile and returns a list of dicts."""
        with open(self.filename) as f:
            entries = [json.loads(line) for line in f]
        return entries

    @property
    def argparser(self):
        """Returns an argument parser for the logger"""
        if self._argparser is not None:
            return self._argparser
        p = argparse.ArgumentParser('log')
        p.add_argument('-a', '--activity', dest='activity', default=None)
        p.add_argument('message', nargs=argparse.REMAINDER)
        self._argparser = p
        return self._argparser


def log(args):
    """Command line interface for logging a message"""
    ns = $LOGGER.argparser(args)
    message = ' '.join(ns.message)
    $LOGGER.log(message, activity=ns.activity)


aliases['log'] = log
