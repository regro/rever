"""Test main utilities"""
from collections import defaultdict
import builtins

from rever.main import env_main
from rever.activity import Activity


def test_source_rc(gitrepo):
    with open('rever.xsh', 'w') as f:
        f.write('$YOU_DONT = "always"\n')
    env_main(args=[])
    assert builtins.__xonsh_env__['YOU_DONT'] == 'always'
    del builtins.__xonsh_env__['YOU_DONT']


def test_alt_source_rc(gitrepo):
    with open('rc.xsh', 'w') as f:
        f.write('$YOU_DO = "never"\n')
    env_main(args=['--rc=rc.xsh'])
    assert builtins.__xonsh_env__['YOU_DO'] == 'never'
    del builtins.__xonsh_env__['YOU_DO']


def test_activities_from_rc(gitrepo):
    with open('rever.xsh', 'w') as f:
        f.write('$ACTIVITIES = {"a", "b", "c"}\n')
    env = builtins.__xonsh_env__
    env['ACTIVITY_DAG'] = defaultdict(Activity)
    env_main(args=[])
    assert env['ACTIVITIES'] == {"a", "b", "c"}


def test_activities_from_cli(gitrepo):
    with open('rever.xsh', 'w') as f:
        f.write('$ACTIVITIES = {"a", "b", "c"}\n')
    env = builtins.__xonsh_env__
    env['ACTIVITY_DAG'] = defaultdict(Activity)
    env_main(args=['-a', 'e,f,g'])
    assert env['ACTIVITIES'] == {"e", "f", "g"}
