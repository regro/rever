$PROJECT = 'rever'
$REVER_DIR = 'rever-tmp'
$ACTIVITIES = ['pytest', 'version_bump', 'changelog', 'tag']

$VERSION_BUMP_PATTERNS = [
    ('rever/__init__.py', '__version__\s*=.*', "__version__ = '$VERSION'"),
    ('setup.py', '        version\s*=.*,', "        version='$VERSION',")
    ]
$CHANGELOG_FILENAME = 'CHANGELOG.rst'
$CHANGELOG_IGNORE = ['TEMPLATE.rst']
$TAG_REMOTE = 'git@github.com:ergs/rever.git'


with open('requirements/tests.txt') as f:
    $DOCKER_CONDA_DEPS = f.read().split()
$DOCKER_PIP_DEPS = ['xonda']
$DOCKER_INSTALL_COMMAND = './setup.py install'
$DOCKER_GIT_NAME = 'rever'
$DOCKER_GIT_EMAIL = 'rever@example.com'
