News Workflow
=============

One of the most helpful features of rever is the ``changelog`` activity.
This activity produces a changelog by colating ``news`` files.
The changelog is written into the repo and can be used in the GitHub
release activity.

The workflow for using news is:
  1. When changes are added to the code (usually via a Pull Request) add a 
     file to the ``news`` directory. 
     Usually we name the file after the branch that is used to avoid conflicts. 
     The news files have two formats depending on when the rever template
     was made.
     The older templates look like::

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

     The new ``news`` template looks like::

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


     Note that you can add multiple entries inside a single news file.

  2. Once the project is ready for a release when running the ``rever``
     command all the files, except the template, in the ``news`` folder will
     be collated and merged into a single changelog file.
