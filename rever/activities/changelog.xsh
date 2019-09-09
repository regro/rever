"""Activity for keeping a changelog from news entries."""
import os
import re
import sys
import json

from xonsh.tools import print_color

from rever import vcsutils
from rever.activity import Activity
from rever.tools import eval_version, replace_in_file
from rever.authors import load_metadata


DEFAULT_CATEGORIES = ('Added', 'Changed', 'Deprecated', 'Removed', 'Fixed',
                      'Security')
DEFAULT_CATEGORY_TITLE_FORMAT = "**{category}:**\n\n"

INITIAL_CHANGELOG = """{bars}
{PROJECT} Change Log
{bars}

.. current developments

"""


class Changelog(Activity):
    """Manages keeping a changelog up-to-date.

    This activity may be configured with the following envionment variables:

    :$CHANGELOG_FILENAME: str, path to input file. The default is 'CHANGELOG'.
    :$CHANGELOG_PATTERN: str, Python regex that is used to find the location
        in the file where new changelog entries should be placed. The default is
        ``'.. current developments'``.
    :$CHANGELOG_HEADER: str or callable that accepts a single version argument,
        this is the replacement that goes above the new merge entries.
        This should contain a string that matches the pattern arg
        so that the next release may be inserted automatically.
        The default value is:

        .. code-block:: rst

            .. current developments

            v$VERSION

            ====================

    :$CHANGELOG_NEWS: str, path to directory containing news files.
        The default is ``'news'``.
    :$CHANGELOG_IGNORE: list of str, regexes of filenames in the news directory
        to ignore. The default is to ignore the template file.
    :$CHANGELOG_LATEST: str, file to write just the latest part of the
        changelog to. This defaults to ``$REVER_DIR/LATEST``. This is evaluated
        in the current environment. If this file is not within ``$REVER_DIR``,
        it is added to the repository.
    :$CHANGELOG_TEMPLATE: str, filename of the template file in the
        news directory. The default is ``'TEMPLATE'``.
    :$CHANGELOG_CATEGORIES: iterable of str, the news categories that are used.
        Default:``('Added', 'Changed', 'Deprecated', 'Removed', 'Fixed', 'Security')``
    :$CHANGELOG_CATEGORY_TITLE_FORMAT: str or callable, a format string with ``{category}``
        entry for formatting changelog and template category titles. If this is a callable,
        it is a function which takes a single category argument and returns the title string.
        The default is ``"**{category}:**\n\n"``.
    :$CHANGELOG_AUTHORS_TITLE: str or bool, If this is a non-empty string and the ``authors``
        activitiy is being run, this will append an authors section to this changelog entry
        that contains all of the authors that contributed to this version. This string is
        the section title and is formatted as if it were a category with
        ``$CHANGELOG_CATEGORY_TITLE_FORMAT``. The default is ``"Authors"``.
    :$CHANGELOG_AUTHORS_FORMAT: str, this is a format string that formats each author who
        contributed to this release, if an authors section will be appened. This is
        evaluated in the context of the authors, see the ``authors`` activity for more
        details on the available fields. The default is ``"* {name}\n"``.
    """

    def __init__(self, *, deps=frozenset()):
        super().__init__(name='changelog', deps=deps, func=self._func,
                         desc="Manages keeping a changelog up-to-date.",
                         setup=self.setup_func)
        self._re_cache = {}

    def _func(self, filename='CHANGELOG', pattern='.. current developments',
              header='.. current developments\n\nv$VERSION\n'
                     '====================\n\n',
              news='news', ignore=None,
              latest='$REVER_DIR/LATEST', template='TEMPLATE',
              categories=DEFAULT_CATEGORIES,
              category_title_format=DEFAULT_CATEGORY_TITLE_FORMAT,
              authors_title="Authors",
              authors_format="* {name}\n"):
        ignore = [template] if ignore is None else ignore
        header = eval_version(header)
        latest = eval_version(latest)
        merged = self.merge_news(news=news, ignore=ignore, categories=categories,
                                 category_title_format=category_title_format)
        authors = self.generate_authors(title_format=category_title_format,
                                        title=authors_title, format=authors_format)
        merged += authors
        with open(latest, 'w') as f:
            f.write(merged)
        if not latest.startswith($REVER_DIR):
            vcsutils.track(latest)
        n = header + merged
        replace_in_file(pattern, n, filename)
        vcsutils.commit('Updated CHANGELOG for ' + $VERSION)

    def merge_news(self, news='news', ignore=('TEMPLATE',), categories=DEFAULT_CATEGORIES,
                   category_title_format=DEFAULT_CATEGORY_TITLE_FORMAT):
        """Reads news files and merges them."""
        cats = {c: '' for c in categories}
        news_re = self._news_re(categories, category_title_format)
        files = [os.path.join(news, f) for f in os.listdir(news)
                 if self.keep_file(f, ignore)]
        files.sort()
        for fname in files:
            with open(fname) as f:
                raw = f.read()
            raw = raw.strip()
            parts = news_re.split(raw)
            parts = [part for part in parts if part is not None]
            while len(parts) > 0 and parts[0] not in categories:
                parts = parts[1:]
            for key, val in zip(parts[::3], parts[1::3]):
                val = val.strip()
                if val == '* <news item>' or val == 'None':
                    continue
                cats[key] += val + '\n'
        for fname in files:
            os.remove(fname)
        s = ''
        for c in categories:
            val = cats[c]
            if len(val) == 0:
                continue
            s += self._format_category_title(category_title_format, c) + val + '\n'
        return s

    def keep_file(self, filename, ignore):
        """Returns whether or not a file should be kept based on ignore rules."""
        for pattern in ignore:
            p = self._re_cache.get(pattern, None)
            if p is None:
                p = self._re_cache[pattern] = re.compile(pattern)
            if p.match(filename):
                return False
        return True

    def generate_authors(self, title_format, title, format):
        """Generates author portion of changelog."""
        if not title or "authors" not in $RUNNING_ACTIVITIES:
            return ""
        metadata = ${...}.get('AUTHORS_METADATA', '.authors.yml')
        latest = ${...}.get('AUTHORS_LATEST', '$REVER_DIR/LATEST-AUTHORS.json')
        md = load_metadata(metadata)
        by_email = {x["email"]: x for x in md}
        with open(eval_version(latest)) as f:
            emails = json.load(f)
        lines = [self._format_category_title(title_format, title)]
        for email in emails:
            lines.append(format.format(**by_email[email]))
        lines.append("\n")
        s = "".join(lines)
        return s

    def setup_func(self):
        """Initializes the changelog activity by starting a news dir, making
        a template file, and starting a changlog file.
        """
        # get vars from env
        news = ${...}.get('CHANGELOG_NEWS', 'news')
        template_file = ${...}.get('CHANGELOG_TEMPLATE', 'TEMPLATE')
        template_file = os.path.join(news, template_file)
        changelog_file = ${...}.get('CHANGELOG_FILENAME', 'CHANGELOG')
        categories = ${...}.get('CHANGELOG_CATEGORIES', DEFAULT_CATEGORIES)
        category_title_format = ${...}.get('CHANGELOG_CATEGORY_TITLE_FORMAT', DEFAULT_CATEGORY_TITLE_FORMAT)
        # run saftey checks
        template_exists = os.path.isfile(template_file)
        changelog_exists = os.path.isfile(changelog_file)
        msgs = []
        if template_exists:
            msgs.append('Template file {0!r} exists'.format(template_file))
        if changelog_exists:
            msgs.append('Changelog file {0!r} exists'.format(changelog_file))
        if len(msgs) > 0:
            print_color('{RED}' + ' AND '.join(msgs) + '{NO_COLOR}',
                        file=sys.stderr)
            if $REVER_FORCED:
                print_color('{RED}rever forced, overwriting files!{NO_COLOR}',
                            file=sys.stderr)
            else:
                print_color('{RED}Use the --force option to force the creation '
                            'of the changelog files.{NO_COLOR}',
                            file=sys.stderr)
                return False
        # actually create files
        os.makedirs(news, exist_ok=True)
        self._generate_template(template_file, categories, category_title_format)
        with open(changelog_file, 'w') as f:
            s = INITIAL_CHANGELOG.format(PROJECT=$PROJECT,
                                         bars='='*(len($PROJECT) + 11))
            s = s.rstrip() + "\n"
            f.write(s)
        return True

    def _format_category_title(self, title_format, category):
        if isinstance(title_format, str):
            rtn = title_format.format(category=category)
        elif callable(title_format):
            rtn = title_format(category=category)
        else:
            raise RuntimeError("$CHANGELOG_CATEGORY_TITLE_FORMAT must be "
                               "string or callable")
        return rtn

    def _generate_template(self, filename, categories, category_title_format):
        """Helper function for generating template file."""
        news_item = "* <news item>\n\n"
        lines = []
        for category in categories:
            lines.append(self._format_category_title(category_title_format, category))
            lines.append(news_item)
        s = "".join(lines)
        s = s.rstrip() + "\n"
        with open(filename, 'w') as f:
            f.write(s)

    # this cannot contain "[" "]" or "\"
    _regex_special = ".^$*+?(){}|"

    def _news_re(self, categories, category_title_format):
        """generate parser expression based on categories"""
        pats = []
        for category in categories:
            # start with the formatted title
            pat = self._format_category_title(category_title_format, category).strip()
            # escape regex special characters
            pat = pat.replace("\\", "\\\\").replace("[", r"\[").replace("]", r"\]")
            for char in self._regex_special:
                pat = pat.replace(char, "[" + char + "]")
            # capture category name
            pat = pat.replace(category, "(" + category + ")")
            pats.append(pat)
        p = "(" + ")|(".join(pats) + ")"
        return re.compile(p, flags=re.DOTALL)
