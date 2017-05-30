"""Main CLI entry point for rever"""
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
    return p


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
    activities = $ACTIVITIES if activities is None else activities
    done = compute_activities_completed()
    path, already_done = find_path($ACTIVITY_DAG, activities, done)
    return path, already_done


def run_activities(ns):
    """Actually run activities."""
    need, done = compute_activities_to_run()
    for name in done:
        print_color("{GREEN}Activity '" + name + "' has already been "
                    "completed!{NO_COLOR}")
    for name in need:
        act = $ACTIVITY_DAG[name]
        act()


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
        act = $ACTIVITY_DAG[name]
        act.undo()


def env_main(args=None):
    """The main function that must be called with the rever environment already
    started up.
    """
    ns = PARSER.parse_args(args)
    source @(ns.rc)
    if ns.activities is not None:
        $ACTIVITIES = ns.activities
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