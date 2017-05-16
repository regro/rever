"""DAG tests"""
from rever.dag import find_path
from rever.activity import Activity


def test_empty():
    path = find_path({}, set())
    assert [] == path


def test_single():
    path = find_path({'a': Activity()}, {'a'})
    assert ['a'] == path


def test_two_unrelated():
    dag = {'a': Activity(), 'b': Activity()}
    path = find_path(dag, {'a', 'b'})
    assert ['a', 'b'] == path


def test_two_dep():
    dag = {'a': Activity(), 'b': Activity(deps=set('a'))}
    path = find_path(dag, {'b'})
    assert ['a', 'b'] == path


def test_three_linear():
    dag = {'a': Activity(), 'b': Activity(deps=set('a')), 'c': Activity(deps=set('b'))}
    path = find_path(dag, {'c'})
    assert ['a', 'b', 'c'] == path


def test_three_forked():
    dag = {'a': Activity(), 'b': Activity(deps=set('a')), 'c': Activity(deps=set('a'))}
    path = find_path(dag, {'b'})
    assert ['a', 'b'] == path
    path = find_path(dag, {'c'})
    assert ['a', 'c'] == path
    path = find_path(dag, {'b', 'c'})
    assert ['a', 'b', 'c'] == path


def test_five_forked():
    dag = {'a': Activity(), 'b': Activity(deps=set('a')), 'c': Activity(deps=set('b')),
           'd': Activity(deps=set('a')), 'e': Activity(deps=set('c'))}
    path = find_path(dag, {'d'})
    assert ['a', 'd'] == path
    path = find_path(dag, {'e'})
    assert ['a', 'b', 'c', 'e'] == path
    path = find_path(dag, {'d', 'e'})
    assert ['a', 'd', 'b', 'c', 'e'] == path
    path = find_path(dag, {'b', 'c', 'd', 'e'})
    assert ['a', 'b', 'c', 'd', 'e'] == path




