$PROJECT = 'rever'
$REVER_DIR = 'rever-tmp'
$ACTIVITIES = ['version_bump', 'changelog', 'pytest',
               'sphinx', 'tag', 'pypi', 'conda_forge', 'ghpages', 'ghrelease']

$VERSION_BUMP_PATTERNS = [
    ('rever/__init__.py', '__version__\s*=.*', "__version__ = '$VERSION'"),
    ('setup.py', 'version\s*=.*,', "version='$VERSION',")
    ]
$CHANGELOG_FILENAME = 'CHANGELOG.rst'
$CHANGELOG_TEMPLATE = 'TEMPLATE.rst'
$TAG_REMOTE = 'git@github.com:regro/rever.git'

$GITHUB_ORG = 'regro'
$GITHUB_REPO = 'rever'
$GHPAGES_REPO = 'git@github.com:regro/rever-docs.git'

with open('requirements/tests.txt') as f:
    $DOCKER_CONDA_DEPS = f.read().split()
with open('requirements/docs.txt') as f:
    $DOCKER_CONDA_DEPS += f.read().split()
$DOCKER_CONDA_DEPS = [d.lower() for d in set($DOCKER_CONDA_DEPS)]
$DOCKER_PIP_DEPS = ['xonda']
$DOCKER_INSTALL_COMMAND = './setup.py install'
$DOCKER_GIT_NAME = 'rever'
$DOCKER_GIT_EMAIL = 'rever@example.com'
