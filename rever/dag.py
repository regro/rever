"""Tools for dealing with activity DAGs."""


def find_path(dag, ends, done=frozenset(), path=None, already_done=None):
    """Returns a list that includes all end points for a given DAG.

    Parameters
    ----------
    dag : dict of names to activities
        A DAG of all possible activities
    ends : set of str
        End points to compute.
    done : set of str, optional
        The nodes that have already been computed
    path : list of str, optional
        This is the return value of which activities to execute in which order.
    already_done : list of str
        The return value  of the activities that have already been computed
        that would otherwise need to be computed.

    Returns
    -------
    path : list of str
        The path through the DAG.
    already_done : list of str
        Activities that have already been computed that would otherwise need to
        be computed.
    """
    if path is None:
        path = []
    if not isinstance(done, frozenset):
        done = frozenset(done)
    if already_done is None:
        already_done = []
    pth = set(path)
    sofar = pth | done
    todo = ends - sofar
    would_do = (ends - pth) & done
    already_done.extend([x for x in sorted(would_do) if x not in already_done])
    if len(todo) == 0:
        return path, already_done
    for end in sorted(todo):
        try:
            deps = set(dag[end].deps)
        except KeyError:
            # we need to do it this way to support defaultdict
            raise KeyError('{0!r} not found in DAG!'.format(end))
        need = deps - sofar
        already_done.extend([x for x in sorted(deps & done) if x not in already_done])
        if len(need) > 0:
            find_path(dag, need, done=done, path=path, already_done=already_done)
            sofar.update(path)
        if end not in sofar:
            path.append(end)
    return path, already_done
