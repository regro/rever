"""Tests the SAT solver"""
from rever.sat import Variable, Clause, solve_2sat


def test_solve_2sat_trivial():
    a = Variable('a')
    clauses = {Clause(a)}
    _, obs = solve_2sat(clauses)
    exp = {a}
    assert obs == exp


def test_solve_2sat_two():
    a = Variable('a')
    b = Variable('b')
    clauses = {Clause(a, b), Clause(~b)}
    _, obs = solve_2sat(clauses)
    exp = {a, ~b}
    assert obs == exp


def test_solve_2sat_two_more():
    a = Variable('a')
    b = Variable('b')
    clauses = {Clause(a, b), Clause(~a, b), Clause(~a, ~b)}
    _, obs = solve_2sat(clauses)
    exp = {~a, b}
    assert obs == exp


def test_solve_2sat_infer():
    a = Variable('a')
    b = Variable('b')
    c = Variable('c')
    clauses = {Clause(a, b), Clause(~b, ~c), Clause(~b), Clause(c)}
    _, obs = solve_2sat(clauses)
    exp = {a, ~b, c}
    assert obs == exp


def test_solve_2sat_remove_a_or_not_a():
    a = Variable('a')
    known = {a}
    clauses = {Clause(a, ~a)}
    _, obs = solve_2sat(clauses, known=known)
    exp = {a}
    assert obs == exp
