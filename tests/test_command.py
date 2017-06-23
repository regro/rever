"""Tests the command activity."""
import os

from rever import vcsutils
from rever.main import env_main

REVER_XSH = """
from rever.activities.command import command

command('test_command', 'touch test', 'rm test')

$ACTIVITIES = ['test_command']
"""


def test_command_activity(gitrepo):
    files = [('rever.xsh', REVER_XSH),]
    for filename, body in files:
        with open(filename, 'w') as f:
            f.write(body)
    vcsutils.track('.')
    vcsutils.commit('Some versioned files')

    env_main(['42.1.1'])
    # now see if this worked
    assert os.path.exists('test')
    # now try to undo the tag
    env_main(['-u', 'test_command', '42.1.1'])
    assert not os.path.exists('test')
