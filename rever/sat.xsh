"""A simple SAT solver, and helper utilites."""
from collections import namedtuple


class Variable:
    """An immutable, hashable representation of a variable statement and its truth assignment."""

    __cache = {}

    def __new__(cls, value, assignment=True):
        # this interns the objects in the __cache,
        # so that only one instance of a particular Variable ever exists
        _hash = hash((value, assignment))
        if _hash in cls.__cache:
            return cls.__cache[_hash]
        inst = object.__new__(cls)
        inst.__init__(value, assignment=assignment, _hash=_hash)
        cls.__cache[_hash] = inst
        return inst

    def __init__(self, value, assignment=True, _hash=None):
        if _hash is None and hasattr(self, '_hash') and self._hash in self.__cache:
            return
        self._value = value
        self._assignment = assignment
        self._hash = _hash

    @property
    def value(self):
        return self._value

    @property
    def assignment(self):
        return self._assignment

    def __hash__(self):
        return self._hash

    def __invert__(self):
        return self.__class__(self._value, assignment=not self._assignment)

    def __str__(self):
        s = str(self._value)
        if not self._assignment:
            s = '¬' + s
        return s

    def __repr__(self):
        return str(self)

    def __bool__(self):
        return self._assignment

    def __eq__(self, other):
        return self is other

    def __ne__(self, other):
        return self is not other


class Clause:
    """An immutable, hashable representation of multiple variables ORed (∨) together."""

    def __init__(self, *vars):
        self._vars = frozenset(vars)
        self._hash = hash(self._vars)

    @property
    def vars(self):
        return self._vars

    def __len__(self):
        return len(self._vars)

    def __hash__(self):
        return self._hash

    def __str__(self):
        return "∨".join(map(str, self._vars))

    def __repr__(self):
        return str(self)

    def __contains__(self, var):
        return var in self._vars

    def __eq__(self, other):
        return self._hash == other._hash

    def __ne__(self, other):
        return self._hash != other._hash


def _check_contraditions(vars):
    contras = {var for var in vars if ~var in vars and var}
    if len(contras) == 0:
        # everything is kosher
        return
    msg = "\n".join(["{var} and {not_var} cannot both be true.".format(var=var, not_var=~var)
                     for var in contras])
    raise ValueError("Contraditions found:\n" + msg)


def solve_2sat(clauses, known=None):
    """Solves a 2-SAT problem with a set of clauses that must all be true (ANDed, ∧) together.
    An initial set of known variable assignment may also be provided. Returns known assignments
    """
    if known is None:
        known = set()
    # check contraditions in known
    _check_contraditions(known)
    if len(clauses) == 0:
        return known
    # update from true clauses
    found = {clause for clause in clauses if len(clause) == 1 or clause.vars <= known}
    if len(found) > 0:
        found_vars = set.union(*[set(clause.vars) for clause in found])
    else:
        found_vars = set()
    clauses -= found
    known.update(found_vars)
    if len(clauses) == 0:
        return solve_2sat(clauses, known=known)
    # Check if ~known are in any clauses, and add the remaining var to known.
    found = set()
    found_vars = set()
    for var in known:
        not_var = ~var
        for clause in clauses:
            if not_var in clause:
                found.add(clause)
                found_vars.update(clause.vars - {not_var})
    clauses -= found
    known.update(found_vars)
    if len(clauses) == 0:
        return solve_2sat(clauses, known=known)
    # infer new clauses from (a ∨ b) ∧ (¬b ∨ ¬c) ⇒ (a ∨ ¬c)
    inferred = set()
    for first in clauses:
        a, b = list(first.vars)
        not_a = ~a
        not_b = ~b
        for second in (clauses - {first}):
            if not_a in second:
                not_c = list(second.vars - {not_a})[0]
                inferred.add(Clause(b, not_c))
            if not_b in second:
                not_c = list(second.vars - {not_b})[0]
                inferred.add(Clause(a, not_c))
    clauses |= inferred
    return solve_2sat(clauses, known=known)
