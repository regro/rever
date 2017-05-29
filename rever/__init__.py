import builtins

# setup xonsh ctx and execer
builtins.__xonsh_ctx__ = {}
from xonsh.execer import Execer
builtins.__xonsh_execer__ = Execer(xonsh_ctx=builtins.__xonsh_ctx__)

# setup import hooks
import xonsh.imphooks
xonsh.imphooks.install_import_hooks()

__version__ = '0.0.0'