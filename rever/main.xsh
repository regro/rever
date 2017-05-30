"""Main CLI entry point for rever"""
import argparse

from lazyasd import lazyobject

from rever import environ


@lazyobject
def PARSER():
    p = argparse.ArgumentParser('rever')
    p.add_argument('--rc', default='rever.xsh', dest='rc',
                   help='Rever run control file.')
    p.add_argument('-a', '--activities', default=None, dest='activities',
                   help='comma-separated list of activities to execute. '
                        'This overrides the list in the rc file.')
    return p


def env_main(args=None):
    """The main function that must be called with the rever environment already
    started up.
    """
    ns = PARSER.parse_args(args)
    source @(ns.rc)
    if ns.activities is not None:
        $ACTIVITIES = ns.activities


def main(args=None):
    """Main function for rever."""
    with environ.context():
        env_main(args=args)


if __name__ == '__main__':
    main()