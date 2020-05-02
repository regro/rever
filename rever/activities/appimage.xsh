"""Activity for create AppImage."""

import importlib
from rever.activity import Activity

class AppImage(Activity):
    """Create AppImage.
    """

    def __init__(self, *, deps=frozenset()):
        super().__init__(name='appimage', deps=deps, func=self._func,
                         desc="Create AppImage.")

    def _func(self, template='$VERSION'):
        project_dir = pf'{$PWD}'
        appimage_descr_dir = project_dir / 'appimage'
        if not appimage_descr_dir.exists():
            return None

        is_python_appimage = importlib.util.find_spec("python_appimage")
        if not is_python_appimage:
            pip install git+https://github.com/niess/python-appimage

        pre_requirements_file = appimage_descr_dir / 'pre-requirements.txt'
        requirements_file = appimage_descr_dir / 'requirements.txt'
        cat @(pre_requirements_file) > @(requirements_file)
        echo @(project_dir) >> @(requirements_file)
        python -m python_appimage build app @(appimage_descr_dir)
        rm @(requirements_file)
