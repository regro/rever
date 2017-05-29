"""DAG tests"""
from rever.dag import find_path
from rever.activity import Activity


def test_empty():
    path, _ = find_path({}, set())
    assert [] == path


def test_single():
    path, _ = find_path({'a': Activity()}, {'a'})
    assert ['a'] == path


def test_two_unrelated():
    dag = {'a': Activity(), 'b': Activity()}
    path, _ = find_path(dag, {'a', 'b'})
    assert ['a', 'b'] == path


def test_two_dep():
    dag = {'a': Activity(), 'b': Activity(deps=set('a'))}
    path, _ = find_path(dag, {'b'})
    assert ['a', 'b'] == path


def test_three_linear():
    dag = {'a': Activity(), 'b': Activity(deps=set('a')), 'c': Activity(deps=set('b'))}
    path, _ = find_path(dag, {'c'})
    assert ['a', 'b', 'c'] == path


def test_three_forked():
    dag = {'a': Activity(), 'b': Activity(deps=set('a')), 'c': Activity(deps=set('a'))}
    path, _ = find_path(dag, {'b'})
    assert ['a', 'b'] == path
    path, _ = find_path(dag, {'c'})
    assert ['a', 'c'] == path
    path, _ = find_path(dag, {'b', 'c'})
    assert ['a', 'b', 'c'] == path


def test_five_forked():
    dag = {'a': Activity(), 'b': Activity(deps=set('a')), 'c': Activity(deps=set('b')),
           'd': Activity(deps=set('a')), 'e': Activity(deps=set('c'))}
    path, _ = find_path(dag, {'d'})
    assert ['a', 'd'] == path
    path, _ = find_path(dag, {'e'})
    assert ['a', 'b', 'c', 'e'] == path
    path, _ = find_path(dag, {'d', 'e'})
    assert ['a', 'd', 'b', 'c', 'e'] == path
    path, _ = find_path(dag, {'b', 'c', 'd', 'e'})
    assert ['a', 'b', 'c', 'd', 'e'] == path


def test_empty_done():
    path, already_done = find_path({}, set(), done={'a'})
    assert [] == path
    assert [] == already_done


def test_single_done():
    path, already_done = find_path({'a': Activity()}, {'a'}, done={'a'})
    assert [] == path
    assert ['a'] == already_done


def test_two_unrelated_done():
    dag = {'a': Activity(), 'b': Activity()}
    path, already_done = find_path(dag, {'a', 'b'}, done={'a'})
    assert ['b'] == path
    assert ['a'] == already_done


def test_two_dep_done():
    dag = {'a': Activity(), 'b': Activity(deps=set('a'))}
    path, already_done = find_path(dag, {'b'}, done={'a'})
    assert ['b'] == path
    assert ['a'] == already_done


def test_three_linear_done():
    dag = {'a': Activity(), 'b': Activity(deps=set('a')), 'c': Activity(deps=set('b'))}
    # just a is done
    path, already_done = find_path(dag, {'c'}, done={'a'})
    assert ['b', 'c'] == path
    assert ['a'] == already_done
    # b is done, which implies that a is done
    path, already_done = find_path(dag, {'c'}, done={'b'})
    assert ['c'] == path
    assert ['b'] == already_done
    # a and b are done, only b matters
    path, already_done = find_path(dag, {'c'}, done={'a', 'b'})
    assert ['c'] == path
    assert ['b'] == already_done


def test_three_forked_done():
    dag = {'a': Activity(), 'b': Activity(deps=set('a')), 'c': Activity(deps=set('a'))}
    path, already_done = find_path(dag, {'b'}, done={'a'})
    assert ['b'] == path
    assert ['a'] == already_done
    path, already_done = find_path(dag, {'c'}, done={'a'})
    assert ['c'] == path
    assert ['a'] == already_done
    path, already_done = find_path(dag, {'b', 'c'}, done={'a'})
    assert ['b', 'c'] == path
    assert ['a'] == already_done


def test_five_forked_done():
    dag = {'a': Activity(), 'b': Activity(deps=set('a')), 'c': Activity(deps=set('b')),
           'd': Activity(deps=set('a')), 'e': Activity(deps=set('c'))}
    path, already_done = find_path(dag, {'d'}, done={'a'})
    assert ['d'] == path
    assert ['a'] == already_done
    path, already_done = find_path(dag, {'e'}, done={'b'})
    assert ['c', 'e'] == path
    assert ['b'] == already_done
    path, already_done = find_path(dag, {'d', 'e'}, done={'a', 'b'})
    assert ['d', 'c', 'e'] == path
    assert ['a', 'b'] == already_done
    path, already_done = find_path(dag, {'b', 'c', 'd', 'e'}, done={'a', 'c'})
    assert ['b', 'd', 'e'] == path
    assert ['c', 'a'] == already_done
