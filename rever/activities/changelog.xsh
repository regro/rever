"""Activity for keeping a changelog from news entries."""
import os
import re
import sys

from xonsh.tools import print_color

from rever import vcsutils
from rever.activity import Activity
from rever.tools import eval_version, replace_in_file


NEWS_CATEGORIES = ['Added', 'Changed', 'Deprecated', 'Removed', 'Fixed',
                   'Security']
NEWS_RE = re.compile('\*\*({0}):\*\*'.format('|'.join(NEWS_CATEGORIES)),
                     flags=re.DOTALL)


NEWS_TEMPLATE = """**Added:**

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
"""

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
        in the current environment.
    :$CHANGELOG_TEMPLATE: str, filename of the template file in the
        news directory. The default is ``'TEMPLATE'``.
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
              latest='$REVER_DIR/LATEST', template='TEMPLATE'):
        ignore = [template] if ignore is None else ignore
        header = eval_version(header)
        latest = eval_version(latest)
        merged = self.merge_news(news=news, ignore=ignore)
        with open(latest, 'w') as f:
            f.write(merged)
        n = header + merged
        replace_in_file(pattern, n, filename)
        vcsutils.commit('Updated CHANGELOG for ' + $VERSION)

    def merge_news(self, news='news', ignore=('TEMPLATE',)):
        """Reads news files and merges them."""
        cats = {c: '' for c in NEWS_CATEGORIES}
        files = [os.path.join(news, f) for f in os.listdir(news)
                 if self.keep_file(f, ignore)]
        files.sort()
        for fname in files:
            with open(fname) as f:
                raw = f.read()
            raw = raw.strip()
            parts = NEWS_RE.split(raw)
            while len(parts) > 0 and parts[0] not in NEWS_CATEGORIES:
                parts = parts[1:]
            for key, val in zip(parts[::2], parts[1::2]):
                val = val.strip()
                if val == '* <news item>' or val == 'None':
                    continue
                cats[key] += val + '\n'
        for fname in files:
            os.remove(fname)
        s = ''
        for c in NEWS_CATEGORIES:
            val = cats[c]
            if len(val) == 0:
                continue
            s += '**' + c + ':**\n\n' + val + '\n\n'
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

    def setup_func(self):
        """Initializes the changelog activity by starting a news dir, making
        a template file, and starting a changlog file.
        """
        # get vars from env
        news = ${...}.get('CHANGELOG_NEWS', 'news')
        template_file = ${...}.get('CHANGELOG_TEMPLATE', 'TEMPLATE')
        template_file = os.path.join(news, template_file)
        changelog_file = ${...}.get('CHANGELOG_FILENAME', 'CHANGELOG')
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
        with open(template_file, 'w') as f:
            f.write(NEWS_TEMPLATE)
        with open(changelog_file, 'w') as f:
            s = INITIAL_CHANGELOG.format(PROJECT=$PROJECT,
                                         bars='='*(len($PROJECT) + 11))
            f.write(s)
        return True
