from rever.activity import Activity


class Command(Activity):
    """Runs a command

    Optionally, an undo command can also be given to undo the given command

    .. note::

       The recommended way to create a command is with the
       :func:`rever.activities.command.command` function.

    """
    def __init__(self, name, command, undo_command=None, requires=None, **kwargs):
        """
        Parameters
        ----------
        name : str
            The name of the activity. Should be unique.
        command : str
            The command to be run. Should be a valid xonsh command.
        undo_command : str, optional
            Command to undo the activity. Should be a valid xonsh command.
        requires : dict or None, optional
            The requirements for this command.
        """
        self.command = command
        self.undo_command = undo_command
        super().__init__(name=name, func=self._func, undo=self._undo,
                         requires=requires, **kwargs)

    def _func(self):
        print('Running command {command!r}'.format(command=self.command))
        evalx(self.command)

    def _undo(self):
        if self.undo_command:
            print("Running undo command {undo_command!r}".format(undo_command=self.undo_command))
            evalx(self.undo_command)


def command(name, command, undo_command=None, requires=None, **kwargs):
    """Create a command activity

    Parameters
    ----------
    name : str
        The name of the activity. Should be unique.
    command : str
        The command to be run. Should be a valid xonsh command.
    undo_command : str, optional
        Command to undo the activity. Should be a valid xonsh command.
    requires : dict or None, optional
        The requirements for this command.

    Examples
    --------

    .. code-block:: xonsh

        from rever.activities.command import command

        command('mycommand', '<command to run>', '<command to undo>')

        $ACTIVITIES = ['mycommand']

    """
    command = Command(name, command, undo_command=undo_command,
                      requires=requires, **kwargs)
    $DAG[name] = command
