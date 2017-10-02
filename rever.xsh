$REVER_DIR = 'rever-tmp'
$ACTIVITIES = ['version_bump', 'changelog', 'tag']

$VERSION_BUMP_PATTERNS = [
    ('rever/__init__.py', '__version__\s*=.*', "__version__ = '$VERSION'"),
    ('setup.py', '        version\s*=.*,', "        version='$VERSION',")
    ]
$CHANGELOG_FILENAME = 'CHANGELOG.rst'
$CHANGELOG_IGNORE = ['TEMPLATE.rst']
$TAG_REMOTE = 'git@github.com:ergs/rever.git'
