====================
Rever Change Log
====================

.. current developments

v0.2.5
====================

**Added:**

* More robust handling of github tokens. If a credential file is deleted locally,
  rever will now attempt to find the associated token, delete it, and reissue it.
* Usage docs for initializing rever


**Changed:**

* If fork doesn't exist for conda-forge activity then create one
* ``$PROJECT`` in use docs example
* Logger now records version
* ``compute_activities_completed`` now checks version numbers as well
* Tagging and pushing the tags up to a remote are now separate activities




v0.2.4
====================

**Added:**

* Use Rever's own whitespace parsing in Rever's ``rever.xsh`` file
* New activity for running nosetests inside of a docker container.
* Setup framework that allows activities to initialize themseleves in
  a project has been added.
* Chacgelog setup functionality added.
* ``rever setup`` will now perform some project level setup,
  specifically adding the ``$REVER_DIR`` to the gitignore file,
  if applicable.


**Changed:**

* Updated and improved documentation.
* Patterning matching (as in version-bump) will now automatically capture
  and replace leading whitespace.  Patterns and replacement strings may start
  at the first non-whitespace character.
* Addressed annoyance where sphinx documentation files were created
  with root ownership. The user and group of sphinx files will now
  match the user oand group of the ``$SPHINX_HOST_DIR`` on the host.




v0.2.3
====================

**Changed:**

* Updated link in conda-forge activity to point to docs.




v0.2.2
====================

**Changed:**

* Conda smithy does not correctly rerender unless the feedstock
  directory is called ``$PROJECT`` or ``$PROJECT-feedstock``,
  thus the feedstock dir has been updated.
* Python package name changed to ``re-ver``, since the
  PyPI name ``rever`` is taken (even though no one has
  uploaded a package).


**Fixed:**

* The conda forge activity was printing it matching patterns, and
  it shouldn't have been doing that.




v0.2.1
====================

**Fixed:**

* Fixed ``eval_version`` import in ghrelease.




v0.2.0
====================

**Added:**

* BibTex activity for creating a bibtex reference for software
* Added conda-forge activity
* Added support for running activities in docker containers
* New pytest activity, which runs inside of docker.
* New sphinx activity, which runs inside of docker.
* New ghpages activity, which depolys files to a GitHub pages repo.
* New ghrelease activity, which performs a GitHub release.
* Added new PyPI releaser activity.




v0.1.0
====================

**Added:**

* Version bump activity
* Changelog activity
* Shell command activity
* Tag activity
* DAG Solver
* Pytest-based test suite
* Documentation
* Rever integration




