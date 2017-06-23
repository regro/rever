from rever.activity import Activity

class Command(Activity):
    def __init__(self, name, command, undo_command=None, **kwargs):
        self.command = command
        self.undo_command = undo_command
        super().__init__(name=name, func=self._func, undo=self._undo, **kwargs)

    def _func(self):
        print('Running command {command!r}'.format(command=self.command))
        evalx(self.command)

    def _undo(self):
        if self.undo_command:
            print("Running undo command {undo_command!r}".format(undo_command=self.undo_command))
            evalx(self.undo_command)


def command(name, command, undo_command=None, **kwargs):
    command = Command(name, command, undo_command=undo_command, **kwargs)
    $DAG[name] = command
