"""Tests logger"""
import os

from rever.logger import Logger


def test_logger(gitrepo):
    logger = Logger(os.path.join(gitrepo, 'mylog.json'))
    logger.log('sample message', activity="kenny", category="loggin'")
    entries = logger.load()
    assert len(entries) == 1