"""Test main utilities"""
import builtins

from rever.main import env_main


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
