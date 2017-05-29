"""Tests logger"""
import os

from rever import vcsutils
from rever.logger import Logger


def test_logger(gitrepo):
    logger = Logger(os.path.join(gitrepo, 'mylog.json'))
    logger.log('sample message', activity="kenny", category="loggin'")
    logger.log('another message', activity="wood", category="chippin'")
    entries = logger.load()
    assert len(entries) == 2
    entry = entries[0]
    assert entry['message'] == 'sample message'
    assert entry['activity'] == 'kenny'
    assert entry['category'] == "loggin'"
    assert entry['rev'] == vcsutils.current_rev()
    entry = entries[1]
    assert entry['message'] == 'another message'
    assert entry['activity'] == 'wood'
    assert entry['category'] == "chippin'"
    assert entry['rev'] == vcsutils.current_rev()
    assert entries[0]['timestamp'] < entries[1]['timestamp']
