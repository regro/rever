"""Main CLI entry point for rever"""
import argparse
from collections import defaultdict

from lazyasd import lazyobject
from xonsh.tools import print_color

from rever import environ
from rever.dag import find_path


@lazyobject
def PARSER():
    p = argparse.ArgumentParser('rever')
    p.add_argument('--rc', default='rever.xsh', dest='rc',
                   help='Rever run control file.')
    p.add_argument('-a', '--activities', default=None, dest='activities',
                   help='comma-separated list of activities to execute. '
                        'This overrides the list in the rc file.')
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


def env_main(args=None):
    """The main function that must be called with the rever environment already
    started up.
    """
    ns = PARSER.parse_args(args)
    source @(ns.rc)
    if ns.activities is not None:
        $ACTIVITIES = ns.activities
    need, done = compute_activities_to_run()
    for name in done:
        print_color("{GREEN}Activity '" + name + "' has already been "
                    "completed!{NO_COLOR}")
    for name in need:
        act = $ACTIVITY_DAG[name]
        act()


def main(args=None):
    """Main function for rever."""
    with environ.context():
        env_main(args=args)


if __name__ == '__main__':
    main()