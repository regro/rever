"""Logging tools for rever"""
import os
import json
import time
import argparse

from xonsh.tools import print_color

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
        self._dirty = True
        self._cached_entries = ()

    def log(self, message, activity=None, category='misc', data=None, version=None):
        """Logs a message, the associated activity (optional), the timestamp, and the
        current revision to the log file.
        """
        self._dirty = True
        entry = {'message': message, 'timestamp': time.time(),
                 'rev': current_rev(), 'category': category}
        if activity is not None:
            entry['activity'] = activity
        if data is not None:
            entry['data'] = data

        entry['version'] = version if version is not None else $VERSION
        # write to log file
        with open(self.filename, 'a+') as f:
            json.dump(entry, f, sort_keys=True, separators=(',', ':'))
            f.write('\n')
        # write to stdout
        msg = '{INTENSE_CYAN}' + category + '{PURPLE}:'
        if activity is not None:
            msg += '{RED}' + activity + '{PURPLE}:'
        msg += '{INTENSE_WHITE}' + message + '{NO_COLOR}'
        print_color(msg)

    def load(self):
        """Loads all of the records from the logfile and returns a list of dicts.
        If the log file does not yet exist, this returns an empty list.
        """
        if not os.path.isfile(self.filename):
            return []
        if not self._dirty:
            return self._cached_entries
        with open(self.filename) as f:
            entries = [json.loads(line) for line in f]
        self._dirty = False
        self._cached_entries = entries
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
        p.add_argument('-d', '--data', dest='data', default=None)
        p.add_argument('message', nargs=argparse.REMAINDER)
        self._argparser = p
        return self._argparser


def log(args, stdin=None):
    """Command line interface for logging a message"""
    if stdin is not None:
        args = args + [stdin.read()]
    ns = $LOGGER.argparser.parse_args(args)
    message = ' '.join(ns.message)
    $LOGGER.log(message, activity=ns.activity, category=ns.category,
                data=ns.data)


def current_logger():
    """Retuns the current logger instance."""
    return $LOGGER


aliases['log'] = log
