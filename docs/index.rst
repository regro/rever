Rever: Releaser of Versions!
============================
Rever is a xonsh-powered, cross-platform software release tool.  The
goal of rever is to provide sofware projects a standard mechanism for dealing with
code released. Rever aims to make the process of releasing a new version of a code base
as easy as running a single command. Rever...

* has a number of stock tools and utilities that you can mix and match to meet your projects needs,
* is easily extensible, allowing your project to execute custom release activities, and
* allows you to undo release activities, in the event of a mistake!

=========
Contents
=========
**Installation:**

.. toctree::
    :titlesonly:
    :maxdepth: 1

    dependencies

**Guides:**

.. toctree::
    :titlesonly:
    :maxdepth: 1

    tutorial

**Configuration & Setup:**

.. toctree::
    :titlesonly:
    :maxdepth: 1

    envvars


**Development Spiral:**

.. toctree::
    :titlesonly:
    :maxdepth: 1

    api/index
    devguide/
    changelog


.. include:: dependencies.rst


============
Contributing
============
We highly encourage contributions to rever!  If you would like to contribute,
it is as easy as forking the repository on GitHub, making your changes, and
issuing a pull request.  If you have any questions about this process don't
hesitate to ask on the `Gitter <https://gitter.im/ergs/rever>`_ channel.

See the `Developer's Guide <devguide.html>`_ for more information about contributing.

=============
Helpful Links
=============

* `Documentation <http://ergs.github.io/rever-docs>`_
* `Gitter <https://gitter.im/ergs/rever>`_
* `GitHub Repository <https://github.com/ergs/rever>`_
* :ref:`genindex`
* :ref:`modindex`
* :ref:`search`

.. raw:: html

    <a href="https://github.com/ergs/rever" class='github-fork-ribbon' title='Fork me on GitHub'>Fork me on GitHub</a>

    <style>
    /*!
     * Adapted from
     * "Fork me on GitHub" CSS ribbon v0.2.0 | MIT License
     * https://github.com/simonwhitaker/github-fork-ribbon-css
     */

    .github-fork-ribbon, .github-fork-ribbon:hover, .github-fork-ribbon:hover:active {
      background:none;
      left: inherit;
      width: 12.1em;
      height: 12.1em;
      position: absolute;
      overflow: hidden;
      top: 0;
      right: 0;
      z-index: 9999;
      pointer-events: none;
      text-decoration: none;
      text-indent: -999999px;
    }

    .github-fork-ribbon:before, .github-fork-ribbon:after {
      /* The right and left classes determine the side we attach our banner to */
      position: absolute;
      display: block;
      width: 15.38em;
      height: 1.54em;
      top: 3.23em;
      right: -3.23em;
      box-sizing: content-box;
      transform: rotate(45deg);
    }

    .github-fork-ribbon:before {
      content: "";
      padding: .38em 0;
      background-image: linear-gradient(to bottom, rgba(0, 0, 0, 0), rgba(0, 0, 0, 0.1));
      box-shadow: 0 0.07em 0.4em 0 rgba(0, 0, 0, 0.3);
      pointer-events: auto;
    }

    .github-fork-ribbon:after {
      content: attr(title);
      color: #000;
      font: 700 1em "Helvetica Neue", Helvetica, Arial, sans-serif;
      line-height: 1.54em;
      text-decoration: none;
      text-align: center;
      text-indent: 0;
      padding: .15em 0;
      margin: .15em 0;
      border-width: .08em 0;
      border-style: dotted;
      border-color: #777;
    }

    </style>
