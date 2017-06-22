rever
=====
Release Versions of Software

Quick Start
===========
To get started with rever, first put a ``rever.xsh`` file in the root directory of your
source repository,

.. code-block:: xonsh

    $ACTIVITIES = ['tag']
    $TAG_PUSH = False

Then, run rever from this directory to execute the release actions you specified.

.. code-block:: sh

    $ rever 1.42



