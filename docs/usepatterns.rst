Notes for using rever
---------------------
Rever is a very powerful versioning and release tool. Like all good tools
there are use patterns to maximizing your productivity.

1. Always commit all changes before versioning/tagging the code, since rever
   will commit any changes. While rever can undo the changes it makes all
   non-version changes will be lost upon a rever undo!
2. You can undo a rever command by ``rever $version -u command1,command2``
3. You will need to insert a ``__version__=='a.b.c'`` in the top most
   ``__init__.py`` file.
4. You will need to change the docs ``conf.py`` to use the version by
   importing it from the top most ``__init__.py`` file.


.. code-block:: python

    # The short X.Y version.
    version = REVER_VERSION.rsplit('.',1)[0]

    # The full version, including alpha/beta/rc tags.
    release = REVER_VERSION

==================
Initializing Rever
==================
There are a couple steps you should take to get the most out of rever.

1. Install rever. Rever is on conda-forge so install via
   ``conda install rever -c conda-forge``, via pypi with ``pip install re-ver``,
   or from source.

2. Setup a ``rever.xsh`` file in the root directory of your source repository.
   Here is a simplified example from ``rever`` itself,

    .. code-block:: xonsh

          $ACTIVITIES = [
                        'version_bump',  # Changes the version number in various source files (setup.py, __init__.py, etc)
                        'changelog',  # Uses files in the news folder to create a changelog for release
                        'tag',  # Creates a tag for the new version number
                        'pypi',  # Sends the package to pypi
                        'conda_forge',  # Creates a PR into your package's feedstock
                        'ghrelease'  # Creates a Github release entry for the new tag
                         ]
          $VERSION_BUMP_PATTERNS = [  # These note where/how to find the version numbers
                                   ('rever/__init__.py', '__version__\s*=.*', "__version__ = '$VERSION'"),
                                   ('setup.py', 'version\s*=.*,', "version='$VERSION',")
                                   ]
          $CHANGELOG_FILENAME = 'CHANGELOG.rst'  # Filename for the changelog
          $CHANGELOG_TEMPLATE = 'TEMPLATE.rst'  # Filename for the news template
          $TAG_REMOTE = 'git@github.com:regro/rever.git'  # Repo to push tags to

          $GITHUB_ORG = 'regro'  # Github org for Github releases and conda-forge
          $GITHUB_REPO = 'rever'  # Github repo for Github releases  and conda-forge

3. After setting up the ``rever.xsh`` file run ``rever setup`` in the root
   directory of your source repository. This will setup files and other things
   needed for rever to operate.

4. When you are ready to release run ``rever <new_version_number>`` and rever
   will take care of the rest.
