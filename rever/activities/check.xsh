"""Activity to run `rever check`."""
from rever.activity import Activity


class Check(Activity):
    """Run `rever check`.

    This activity takes no parameters.
    """

    def __init__(self, *, deps=frozenset()):
        super().__init__(
            name="check", deps=deps, func=self._func, desc="Run `rever check`."
        )

    def _func(self):
        for name in $RUNNING_ACTIVITIES:
            act = $DAG[name]
            status = act.check()
            if not status:
                sys.exit(1)
