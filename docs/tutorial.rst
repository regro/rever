Tutorial
========
Avast! Welcome to the rever tutorial! This document will teach you the ropes of releasing
software with rever.  Let's go sailing!


Writing Custom Activities
-------------------------
In your ``rever.xsh`` file, you have the ability to provide additional, custom activies that
are specific to your project. Each activity is composed of a few different components:

* A string name that uniquely identifies the activity
* A callable that performs the actions for the release activity
* A set of strings that specify the dependencies for this activity,
  by default this is an empty set.
* A callable that is able to undo the action of the activity (optional)
* A description of the activity

There are a couple of ways to write activities. The easiest is to use the activity decorator.

.. code-block:: xonsh

    from rever.activity import activity


Simply use this on a function to create an activity of the name of the function.  For example,
let's write a simple activity that runs the test suite with pytest:

.. code-block:: xonsh

    from rever.activity import activity

    @activity
    def run_tests():
        cd tests
        pytest
        cd ..

    $ACTIVITIES = ['run_tests']


Furthermore, like with other activities, custom activities can accept arguments and keyword
arguments. These are then settable by environment variables.  Let's say that we only want to
test specific files, but by default we want to test all of them. We could instead write the following,

.. code-block:: xonsh

    from rever.activity import activity

    @activity
    def run_tests(files=()):
        """Running the test suite."""
        cd tests
        pytest @(files)
        cd ..

    $ACTIVITIES = ['run_tests']

    # by default, the environment variable $RUN_TESTS_FILES will be mapped
    # to the files kwarg of the run_tests() function.
    $RUN_TESTS_FILES = ['test_me.py', 'test_you.py']


Also note that in the above, the docstring of the function becomes the description for the
activity automatically!  You can also set the ``name``, ``deps``, ``undo``, and ``desc``.  For
example, if you want to make the tests depenendent on another install activity, you could write:

.. code-block:: xonsh

    @activity(deps={'install'})
    def run_tests(files=()):
        """Running the test suite."""
        cd tests
        pytest @(files)
        cd ..

In certain situations, it is also useful for activities to know how to undo themselves. For example,
consider the case where you want to build a source tarball. If the user rewinds this activity,
the tarball should be deleted from the filesystem. Activities have an ``undoer()`` decorator
(like ``setter()`` and ``deleter()`` for properties) that registers an undo function. Thus, our
source tarball activity could be implemented as:


.. code-block:: xonsh

    from rever.activity import activity

    $ACTIVITIES = ['tarball']

    @activity
    def tarball():
        """Creates a source tarball"""
        tar czf project.tar.gz src/

    @tarball.undoer
    def tarball():
        rm -f project.tar.gz



Alternatively, if you really need a lot of fine grained control or encapsulation, you can also
import the ``Activity`` class and subclass it.  Note that when you define an activity this way,
it does not register an instance of this activity for you in the ``$DAG``.  You have to take
care of this bookeeping yourself. For example, the tarball activity can be implemented as
follows:


.. code-block:: xonsh

    from rever.activity import Activity

    class Tarball(Activity):

        def __init__(self, **kwargs):
            super().__init__()
            self.name = 'tarball'
            self.deps = {'install'}
            self.desc = "Creates a source tarball"

        def __call__(self, filename='project.tar.gz'):
            tar czf @(filename) src/

        def undo(self):
            rm -f *.tar.gz


    $DAG['tarball'] = Tarball()  # register the activity
    $ACTIVITIES = ['tarball']
