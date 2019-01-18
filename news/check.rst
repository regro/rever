**Added:**

* New ``rever check`` command for checking that all activities can be run
  prior to actually performing a release. The intended workflow is:

  .. code-block:: sh

      $ rever check
      $ rever X.Y.Z

* The ``Activitiy`` class and ``activity()`` decorator have ``check``
  and ``requires`` keyword arguments. The ``check`` parameter is a
  function for performing the necessary checks during ``rever check``.
  The ``requires`` parameter is a dict that specifies necessary
  command line utilites and modules for the activity to be run.
* New ``Activity.check_requirements()`` method for checking requirements.
* New ``rever.authors.metadata_is_valid()`` function for checking if
  an author metadata list is correct.
* New ``rever.github.can_login()`` functions checks if the user can
  login to GitHub.
* New SAT solving module, ``rever.sat``, for defining satisfiability problems,
  and a ``solve_2sat()`` function for solving 2-SAT problems.
* New ``rever.tools.download()`` and ``rever.tools.download_bytes()`` function
  for downloading URLs as strings and bytes respetively.
* New ``rever.vcsutils.have_push_permissions()`` function for checking if the
  user has push permisions on a remote repository.

**Changed:**

* All existing activities have been updated to include ``requires`` dicts
  and ``check`` functions as needed.
* The ``Authors`` activitiy can now be configured with ``$AUTHORS_INCLUDE_ORGS``
  for whether or not it should include organizations in the authors list.
  Organizations are entries in the authors listing that have the ``is_org``
  field set to ``True``.
* ``rever.authors.update_metadata()`` now attempts to add GitHub identifiers
  if ``$GITHUB_ORG`` is set.

**Deprecated:**

* <news item>

**Removed:**

* <news item>

**Fixed:**

* Fixed bug where ``$REVER_VCS`` would be detyped as a boolean.

**Security:**

* <news item>
