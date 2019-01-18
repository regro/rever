"""A simple SAT solver, and helper utilites."""
import sys


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
        _hash = hash((self._value, not self._assignment))
        if _hash in self.__cache:
            return self.__cache[_hash]
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
    contras = set()
    for var in vars:
        if not var:
            continue
        not_var = ~var
        if not_var in vars:
            contras.add(var)
    if len(contras) == 0:
        # everything is kosher
        return
    msg = "\n".join(["{var} and {not_var} cannot both be true.".format(var=var, not_var=~var)
                     for var in contras])
    raise ValueError("Contraditions found:\n" + msg)


def _format_clauses_known(clauses, known):
    s = "CLAUSES:\n"  + "\n".join(map(str, clauses))
    s += "\n\nKNOWN:\n"  + "\n".join(map(str, known))
    return s


def _solve_2sat(clauses, known=None, _last_clauses=None, _last_known=None):
    """Solves a 2-SAT problem with a set of clauses that must all be true (ANDed, ∧) together.
    An initial set of known variable assignment may also be provided. Returns known assignments
    """
    if _last_clauses is not None and clauses == _last_clauses and \
       _last_known is not None and known == _last_known:
        msg = "System not satisfiable! Please provide more information!\n"
        msg += _format_clauses_known(clauses, known)
        e = RuntimeError(msg)
        e.clauses = clauses
        e.known = known
        raise e
    orig_clauses = set(clauses)
    if known is None:
        orig_known = None
        known = set()
    else:
        orig_known = set(known)
    # check contraditions in known
    try:
        _check_contraditions(known)
    except (RecursionError, ValueError) as e:
        e.clauses = clauses
        e.known = known
        raise e
    if len(clauses) == 0:
        return clauses, known
    # update from true clauses
    found = {clause for clause in clauses if len(clause) == 1 or clause.vars <= known}
    if len(found) > 0:
        found_vars = set.union(*[set(clause.vars) for clause in found])
    else:
        found_vars = set()
    clauses -= found
    known.update(found_vars)
    if len(clauses) == 0:
        return _solve_2sat(clauses, known=known, _last_clauses=orig_clauses, _last_known=orig_known)
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
        return _solve_2sat(clauses, known=known, _last_clauses=orig_clauses, _last_known=orig_known)
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
    # remove identically true clauses of the form (a ∨ ¬a)
    found = set()
    for clause in clauses:
        vars = list(clause.vars)
        if len(vars) == 1:
            # infering might have reduced some clauses
            found.add(clause)
            known.add(vars[0])
            continue
        a, b = vars
        if a is ~b:
            found.add(clause)
    clauses -= found
    return _solve_2sat(clauses, known=known, _last_clauses=orig_clauses, _last_known=orig_known)


def solve_2sat(clauses, known=None, always_return=False):
    """Solves a 2-SAT problem with a set of clauses that must all be true (ANDed, ∧) together.
    An initial set of known variable assignment may also be provided. Returns known assignments
    """
    try:
        return _solve_2sat(clauses, known=known)
    except RecursionError as e:
        print("Could not solve in reasonable number of iterations!", file=sys.stderr)
        if always_return:
            return (e.clauses, e.known)
        else:
            raise e
    except (RuntimeError, ValueError) as e:
        if always_return:
            return (e.clauses, e.known)
        else:
            raise e
