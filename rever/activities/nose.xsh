"""Activity for running nosetests inside of a container."""
from rever.activity import DockerActivity


class Nose(DockerActivity):
    """Runs nose tests inside of a container.

    Environment variables that modify this activity's behaviour are:

    :$NOSE_COMMAND: str, nose command to execute, defaults to 'nosetests'.
    :$NOSE_ARGS: str or list of str, additional arguments to send to the
        nose command. By default no additional arguments are sent.
    """

    def __init__(self):
        super().__init__(name='nose', deps=frozenset(), func=self._func,
                         desc="Runs nose inside of a docker container",
                         lang='sh', code='nosetests')

    def _func(self, command='nosetests', args=()):
        code = command
        if args:
            code += ' '
            code += args if isinstance(args, str) else ' '.join(args)
        super()._func(code=code)
