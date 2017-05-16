"""Tools for dealing with activity DAGs."""


def find_path(dag, ends, path=None):
    """Returns a list that includes all end points for a given DAG.

    Parameters
    ----------
    dag : dict of names to activities
        A DAG of all possible activities
    ends : set of str
        End points to compute.
    path : list of str, optional
        This is the return value of which activities to execute in which order.

    Returns
    -------
    path : list of str
        The path through the DAG.
    """
    if path is None:
        path = []
    sofar = set(path)
    todo = ends - sofar
    if len(todo) == 0:
        return path
    for end in sorted(todo):
        deps = set(dag[end].deps)
        need = deps - sofar
        if len(need) > 0:
            find_path(dag, need, path)
            sofar.update(path)
        if end not in sofar:
            path.append(end)
    return path
