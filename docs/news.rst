News Workflow
=============

One of the most helpful features of rever is the ``changelog`` activity.
This activity produces a changelog by colating ``news`` files.
The changelog is written into the repo and can be used in the GitHub
release activity.

The workflow for using news is:

1. Go into the ``news/`` directory
2. Copy the ``TEMPLATE.rst`` file to another file in the ``news/`` directory.
   We suggest using the branchname::

      $ cp TEMPLATE.rst branch.rst

3. The news files have two formats depending on when the rever template
   was made.
   The first template looks like::

    **Added:** None

    **Changed:** None

    **Deprecated:** None

    **Removed:** None

    **Fixed:** None

    **Security:** None

   To add a news entry, remove the ``None`` from the category, add a
   newline and ``* My news entry``.
   For example::

    **Added:**

    * News tutorial

    **Changed:** None

    **Deprecated:** None

    **Removed:** None

    **Fixed:** None

    **Security:** None

   The second ``news`` template looks like::

    **Added:**

    * <news item>

    **Changed:**

    * <news item>

    **Deprecated:**

    * <news item>

    **Removed:**

    * <news item>

    **Fixed:**

    * <news item>

    **Security:**

    * <news item>

   In this case you can remove the ``* <news item>`` and replace it with your own, eg::

    **Added:**

    * New news template tutorial

    **Changed:**

    * <news item>

    **Deprecated:**

    * <news item>

    **Removed:**

    * <news item>

    **Fixed:**

    * <news item>

    **Security:**

    * <news item>

4. Commit your ``branch.rst``.

Feel free to update this file whenever you want! Please don't use someone
else's file name. All of the files in this ``news/`` directory will be merged
automatically at release time.  The ``None`` entries will be automatically
filtered out too!

Once the project is ready for a release when running the ``rever``
command all the files, except the template, in the ``news`` folder will
be collated and merged into a single changelog file.
