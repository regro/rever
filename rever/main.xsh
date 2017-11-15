"""Main CLI entry point for rever"""
import sys
import argparse
from collections import defaultdict

from lazyasd import lazyobject
from xonsh.tools import csv_to_set, print_color

from rever import environ
from rever.dag import find_path


@lazyobject
def PARSER():
    p = argparse.ArgumentParser('rever')
    p.add_argument('--rc', default='rever.xsh', dest='rc',
                   help='Rever run control file.')
    p.add_argument('-a', '--activities', default=None, dest='activities',
                   help='comma-separated set of activities to execute. '
                        'This overrides the set in the rc file.')
    p.add_argument('-u', '--undo', default=frozenset(), dest='undo', type=csv_to_set,
                   help='comma-separated set of activities to undo, in reverse '
                        'chronological order.')
    p.add_argument('-e', '--entrypoint', default=None, dest='entrypoint',
                   help='the entry point target, this determines the activities '
                        'to execute.')
    p.add_argument('--docker-base', default=False, action='store_true',
                   dest='docker_base', help='Forces (re-)build of the '
                                            'base docker container.')
    p.add_argument('--docker-install', default=False, action='store_true',
                   dest='docker_install', help='Forces (re-)build of the '
                                            'install docker container.')
    p.add_argument('version', help='version to release')
    return p


def running_activities(ns):
    """Sets the $RUNNING_ACTIVITIES environment variable."""
    if ns.activities is not None:
        $ACTIVITIES = $RUNNING_ACTIVITIES = ns.activities
        return
    if ns.entrypoint is None:
        $RUNNING_ACTIVITIES = $ACTIVITIES
        return
    acts = {}
    for key, value in ${...}._d.items():
        if key.startswith('ACTIVITIES_'):
            _, _, k = key.partition('_')
            acts[k.lower()] = value
    entry = ns.entrypoint.lower()
    $RUNNING_ACTIVITIES = acts[entry]


def compute_activities_completed():
    """Computes which activities have actually been successfully completed."""
    entries = $LOGGER.load()
    acts_done = {}
    for entry in entries:
        if 'activity' not in entry:
            continue
        act = entry['activity']
        if entry['category'] == 'activity-end':
            if act not in acts_done:
                acts_done[act] = defaultdict(int)
            acts_done[act][entry['data']['start_rev']] += 1
        elif entry['category'] == 'activity-undo':
            if act not in acts_done:
                acts_done[act] = defaultdict(int)
            acts_done[act][entry['rev']] -= 1
    done = set()
    for act, revcount in acts_done.items():
        for rev, count in revcount.items():
            if count > 0:
                done.add(act)
                break
    return done


def compute_activities_to_run(activities=None):
    """Computes which activities to execute based on the DAG, which activities
    the user requested, and which activites the log file says are already done.
    Returns the list of needed activities and the list of completed ones.
    """
    activities = $RUNNING_ACTIVITIES if activities is None else activities
    done = compute_activities_completed()
    order, already_done = find_path($DAG, set(activities), done)
    path = []
    for a in activities:
        if a not in already_done:
            path.append(a)
        else:
            continue
        i = activities.index(a)
        act = $DAG[a]
        for d in act.deps:
            if d in activities:
                j = activities.index(d)
            else:
                continue
            if j >= i:
                raise ValueError(d + ' is a dependency of ' + a + ' and must come before ' +
                                 a + ' in the $ACTIVITIES list.')
    return path, already_done


def run_activities(ns):
    """Actually run activities."""
    need, done = compute_activities_to_run()
    for name in done:
        print_color("{GREEN}Activity '" + name + "' has already been "
                    "completed!{NO_COLOR}")
    for name in need:
        act = $DAG[name]
        act.ns = ns
        status = act()
        if not status:
            sys.exit(1)


def undo_activities(ns):
    """Run undoer for specified activities."""
    done = compute_activities_completed()
    undo = ns.undo & done  # can only undo completed activities
    # compute reverse chronological order of completed activities
    latest_acts = {}
    for entry in $LOGGER.load():
        if 'activity' not in entry:
            continue
        act = entry['activity']
        if act in undo and entry['category'] == 'activity-end':
            last_time = latest_acts.get(act, -1.0)
            if last_time < entry['timestamp']:
                latest_acts[act] = entry['timestamp']
    order = sorted(latest_acts, reverse=True, key=latest_acts.get)
    for name in order:
        act = $DAG[name]
        act.ns = ns
        act.undo()


def env_main(args=None):
    """The main function that must be called with the rever environment already
    started up.
    """
    ns = PARSER.parse_args(args)
    $VERSION = ns.version
    source @(ns.rc)
    running_activities(ns)
    # run the command
    if ns.undo:
        undo_activities(ns)
    else:
        run_activities(ns)


def main(args=None):
    """Main function for rever."""
    with environ.context():
        env_main(args=args)


if __name__ == '__main__':
    main()
