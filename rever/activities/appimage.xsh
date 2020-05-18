"""Activity for create AppImage."""

import importlib
import platform
from shutil import which
from pathlib import Path
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

        if platform.system() == 'Linux':
            if not importlib.util.find_spec("python_appimage"):
                pip install git+https://github.com/niess/python-appimage

            echo -e \n@(p'.'.absolute()) >> @(requirements_file)
            python -m python_appimage build app @(self.appimage_descr_dir)
        else:
            path = Path('.').absolute()
            echo -e \n/dir >> @(requirements_file)
            docker run -v @(path):/dir --rm -e GID=@$(id -g) -e UID=@$(id -u) python:3.7-slim-buster bash -c @('addgroup --gid $GID user && adduser --disabled-password --gecos "" --uid $UID --gid $GID user && apt update && apt install -y git file gpg && pip install git+https://github.com/niess/python-appimage && chown -R user:user /dir && su - user -c "cd /dir && python -m python_appimage build app ./appimage"')
        rm @(requirements_file)

    def check_func(self):
        if not self.appimage_descr_dir.exists():
            print(f"AppImage description not found in {self.appimage_descr_dir.absolute()}")
            return False

        if not Path('setup.py').exists():
            print('setup.py does not exists!')
            return False

        if platform.system() == 'Linux':
            is_python_appimage = importlib.util.find_spec("python_appimage")
            if not is_python_appimage:
                print('Module python_appimage not found!\n'
                      'Please install: pip install -U git+https://github.com/niess/python-appimage')
                return False
        elif not which('docker'):
            print('The system is not Linux and docker is not installed!\n')
            return False

        return True