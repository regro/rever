import builtins

# setup xonsh ctx and execer
builtins.__xonsh_ctx__ = {}
from xonsh.execer import Execer
builtins.__xonsh_execer__ = Execer(xonsh_ctx=builtins.__xonsh_ctx__)
from xonsh.shell import Shell
builtins.__xonsh_shell__ = Shell(builtins.__xonsh_execer__,
                                 ctx=builtins.__xonsh_ctx__,
                                 shell_type='none')

builtins.__xonsh_env__['RAISE_SUBPROC_ERROR'] = True

# setup import hooks
import xonsh.imphooks
xonsh.imphooks.install_import_hooks()

__version__ = '0.2.8'

del xonsh, builtins, Execer, Shell
