"""Activity for create AppImage."""

import importlib
from rever.activity import Activity

class AppImage(Activity):
    """Create AppImage.
    """

    def __init__(self, *, deps=frozenset()):
        self.appimage_descr_dir = p'appimage'
        super().__init__(name='appimage', deps=deps, func=self._func,
                         desc="Create AppImage.", check=self.check_func)

    def _func(self, template='$VERSION'):
        if not self.appimage_descr_dir.exists():
            return None

        pre_requirements_file = self.appimage_descr_dir / 'pre-requirements.txt'
        requirements_file = self.appimage_descr_dir / 'requirements.txt'
        cat @(pre_requirements_file) > @(requirements_file)
        echo -e \n@(p'.'.absolute()) >> @(requirements_file)
        python -m python_appimage build app @(self.appimage_descr_dir)
        rm @(requirements_file)

    def check_func(self):
        if not self.appimage_descr_dir.exists():
            print(f"AppImage description not found in {self.appimage_descr_dir.absolute()}")
            return False

        is_python_appimage = importlib.util.find_spec("python_appimage")
        if not is_python_appimage:
            print('Module python_appimage not found!\n'
                  'Please install: pip install -U git+https://github.com/niess/python-appimage')
            return False
        return True