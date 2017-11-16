====================
Rever Change Log
====================

.. current developments

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




