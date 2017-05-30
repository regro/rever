"""Tests the activity class and its operations."""
import builtins

from rever import  vcsutils
from rever.activity import Activity


def do_tryptophan():
    with open('tryptophan.txt', 'w') as f:
        f.write('5-HTP\n')
    vcsutils.track('tryptophan.txt')
    vcsutils.commit("seratonin")


def test_do_undo(gitrepo):
    """Writes and commits a file and then undoes it."""
    # create and execute activity
    logger = builtins.__xonsh_env__['LOGGER']
    act = Activity(name='seratonin', func=do_tryptophan)
    act()
    # Test that the activity ran correctly
    entries = logger.load()
    assert len(entries) == 2
    assert entries[0]['activity'] == 'seratonin'
    assert entries[1]['activity'] == 'seratonin'
    assert entries[0]['category'] == 'activity-start'
    assert entries[1]['category'] == 'activity-end'
    assert entries[0]['rev'] != entries[1]['rev']
    assert entries[1]['rev'] == vcsutils.current_rev()
    # undo the activity
    act.undo()
    entries = logger.load()
    assert len(entries) == 3
    assert entries[2]['activity'] == 'seratonin'
    assert entries[2]['category'] == 'activity-undo'
    assert entries[2]['rev'] != entries[1]['rev']
    assert entries[2]['rev'] == entries[0]['rev']
    assert entries[2]['rev'] == vcsutils.current_rev()

