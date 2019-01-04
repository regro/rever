====================
Rever Change Log
====================

.. current developments

v0.3.1
====================

**Added:**

* New ``rever.conda.env_exists()`` function for testing if a conda environment exists.
* ``$PUSH_TAG_PROTOCOL`` for manually specifying the push protocol.


**Changed:**

* ``PushTag`` now inspects remotes to find the correct protocol


**Fixed:**

* Fixed issue with ``docker_build`` activitiy not correctly setting the build
  context when the Dockerfile is in the current directory.




v0.3.0
====================

**Changed:**

* Updated rever to use ``xonsh.main.setup()`` function for initialization.


**Fixed:**

* Make ``git push`` and ``git push --tags`` respect the rever ``-f,--force``
  command line argument.




v0.2.9
====================

**Added:**

* New ``docker_build`` and ``docker_push`` activity for building
  and pushing up Dockerfiles.




v0.2.8
====================

**Added:**

* ``conda_forge`` activity kwarg for forking to an org


**Changed:**

* Conda in a docker container will now update dependencies, too.
* Now the ``news`` template uses ``* <news item>`` instead of ``None`` for 
  empty news categories.
* Use the tarball rever generates for the conda forge URL


**Deprecated:**

* ``None`` in the news template (still supported though)


**Fixed:**

* Use the actual ``$VERSION`` not the string ``'$VERSION'``
* Fixed ``rever.tools.hash_url()`` and ``rever.tools.stream_url_progress()``
  functions to robustly handle FTP URLs, in addition to HTTP ones.
* ``repo.create_fork`` doesn't need a username
* Fixed bug preventing ``rever`` from running where version key is not
  present in history entry.




v0.2.7
====================

**Added:**

* GitHub Releases may now attach assets (extra files) to the release.


**Fixed:**

* Fix ``$TAG_TEMPLATE`` being ignored by conda_forge activity when defining
  package URL on GitHub




v0.2.6
====================

**Added:**

* ``$GHRELEASE_PREPEND`` and ``$GHRELEASE_APPEND`` allows users to
  prepend/append a string to the GH release notes
* ``REVER_QUIET`` envvar. If True ``rever`` doesn't print during hashing


**Changed:**

* GitHub token notes now have unique identifiers, which prevents issues from arising
  with hostname clashes.


**Fixed:**

* Addressed issue with DockerActivity not being able to set it's code block
  correctly.
* Null repo fork creation fix for v1.0.0a4 of github3.py
* Fixed bugs in push-tag undoer.




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




