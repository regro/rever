"""Tests the activity class and its operations."""
import os
import builtins

from rever import  vcsutils
from rever.activity import Activity, activity


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
    with open('tryptophan.txt') as f:
        value = f.read()
    assert value == '5-HTP\n'
    # undo the activity
    act.undo()
    entries = logger.load()
    assert len(entries) == 3
    assert entries[2]['activity'] == 'seratonin'
    assert entries[2]['category'] == 'activity-undo'
    assert entries[2]['rev'] != entries[1]['rev']
    assert entries[2]['rev'] == entries[0]['rev']
    assert entries[2]['rev'] == vcsutils.current_rev()
    assert not os.path.isfile('tryptophan.txt')


def test_decorator_just_func(gitrepo):
    @activity
    def collapse():
        """The grade of this collapse"""
        pass
    env = builtins.__xonsh_env__
    dag = env['ACTIVITY_DAG']
    assert 'collapse' in dag
    act = dag['collapse']
    assert act is collapse
    assert act.name == 'collapse'
    assert act.desc == 'The grade of this collapse'
    # test undoer
    @collapse.undoer
    def undo_collapse():
        pass
    assert act._undo is undo_collapse
