"""Tests the tag activity activity."""
from rever import vcsutils
from rever.logger import current_logger
from rever.main import env_main


REVER_XSH = """
$ACTIVITIES = {'tag'}
$TAG_PUSH = False
"""


def test_tag_activity(gitrepo):
    vcsutils.tag('42.1.0')
    files = [('rever.xsh', REVER_XSH),]
    for filename, body in files:
        with open(filename, 'w') as f:
            f.write(body)
    vcsutils.track('.')
    vcsutils.commit('Some versioned files')
    env_main(['42.1.1'])
    # now see if this worked
    current = vcsutils.latest_tag()
    assert '42.1.1' == current
    # now try to undo the tag
    env_main(['-u', 'tag', '42.1.1'])
    current = vcsutils.latest_tag()
    assert '42.1.0' == current
    # ensure that the updates were commited
    logger = current_logger()
    entries = logger.load()
    assert entries[-2] != entries[-1]
