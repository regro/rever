"""Tests the appimage activity."""
from rever import vcsutils
from rever.logger import current_logger
from rever.main import env_main
from pathlib import Path

REVER_XSH = """
$ACTIVITIES = ['appimage']
"""

SETUP_FILE = """
import setuptools
setuptools.setup(
    name="rever-activity-appimage-test",
    version="42.1.1",
    description="Rever appimage activity test",
    url="https://github.com/regrp/rever",
    python_requires='>=3.6',
    install_requires=[],
    package_data={'dir': ['*.py']},
    packages=setuptools.find_packages(),
    author="anki-code",
    author_email="anki-code@example.com"
)
"""

APPIMAGE_ENTRYPOINT_FILE = """
#! /bin/bash
echo "Hello"
"""

APPIMAGE_PRE_REQUIREMENTS_FILE = ""

APPIMAGE_APPDATA_FILE = """
<?xml version="1.0" encoding="UTF-8"?>
<component type="desktop-application">
    <id>xonsh</id>
    <metadata_license>BSD</metadata_license>
    <project_license>Python-2.0</project_license>
    <name>Xonsh</name>
    <summary>Xonsh on Python {{ python-fullversion }}</summary>
    <description>
        <p>  Python {{ python-fullversion }} + Xonsh bundled in an AppImage.
        </p>
    </description>
    <launchable type="desktop-id">xonsh.desktop</launchable>
    <url type="homepage">http://xon.sh</url>
    <provides>
        <binary>python{{ python-version }}</binary>
    </provides>
</component>
"""

APPIMAGE_DESKTOP_FILE = """
[Desktop Entry]
Type=Application
Name=xonsh
Exec=xonsh
Comment=Xonsh on Python {{ python-fullversion }}
Icon=python
Categories=System;
Terminal=true
"""

def test_appimage(gitrepo):
    Path('appimage').mkdir(exist_ok=True)
    files = [('rever.xsh', REVER_XSH), ('setup.py', SETUP_FILE),
             ('appimage/entrypoint.sh', APPIMAGE_ENTRYPOINT_FILE),
             ('appimage/pre-requirements.txt', APPIMAGE_PRE_REQUIREMENTS_FILE),
             ('appimage/xonsh.appdata.xml', APPIMAGE_APPDATA_FILE),
             ('appimage/xonsh.desktop', APPIMAGE_DESKTOP_FILE)]
    for filename, body in files:
        with open(filename, 'w') as f:
            f.write(body)
    vcsutils.track('.')
    vcsutils.commit('Some versioned files')
    env_main(['42.1.1'])
    assert Path('xonsh-x86_64.AppImage') in Path('.').glob('*')
