"""Logging tools for rever"""
import os
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
            Path to logfile, if a realtive pathname is given it is relative to $REVER_DIR.
        """
        self._filename = None
        self._argparser = None
        self.filename = filename

    def log(self, message, activity=None, category='misc'):
        """Logs a message, teh associated activity (optional), the timestamp, and the
        current revision to the log file.
        """
        entry = {'message': message, 'timestamp': time.time(),
                 'rev': current_rev(), 'category': category}
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
    def filename(self):
        value = self._filename
        if not os.path.isabs(value):
            value = os.path.join($REVER_DIR, value)
        dname = os.path.dirname(value)
        if not os.path.isdir(dname):
            mkdir -p @(dname)
        return value

    @filename.setter
    def filename(self, value):
        self._filename = value

    @property
    def argparser(self):
        """Returns an argument parser for the logger"""
        if self._argparser is not None:
            return self._argparser
        p = argparse.ArgumentParser('log')
        p.add_argument('-a', '--activity', dest='activity', default=None)
        p.add_argument('-c', '--category', dest='category', default='misc')
        p.add_argument('message', nargs=argparse.REMAINDER)
        self._argparser = p
        return self._argparser


def log(args, stdin=None):
    """Command line interface for logging a message"""
    if stdin is not None:
        args = args + [stdin.read()]
    ns = $LOGGER.argparser(args)
    message = ' '.join(ns.message)
    $LOGGER.log(message, activity=ns.activity, category=ns.category)


aliases['log'] = log
