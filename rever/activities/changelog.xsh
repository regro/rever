"""Activity for keeping a changelog from news entries."""
import os
import re

from rever import vcsutils
from rever.activity import Activity
from rever.tools import eval_version, replace_in_file


NEWS_CATEGORIES = ['Added', 'Changed', 'Deprecated', 'Removed', 'Fixed',
                   'Security']
NEWS_RE = re.compile('\*\*({0}):\*\*'.format('|'.join(NEWS_CATEGORIES)),
                     flags=re.DOTALL)


class Changelog(Activity):
    """Manages keeping a changelog up-to-date.

    This activity takes a number of different input parameters as
    configuration.

    :filename: str, path to input file. The default is 'CHANGELOG'.
    :pattern: str, Python regex that is used to find the location in the file
              where new changelog entries should be placed. The default is
              '.. current developments'.
    :header: str or callable that accepts a single version argument, this
             is the replacement that goes above the new merge entries.
             This should contain a string that matches the pattern arg
             so that the next release may be inserted automatically.
             The default value is:

             .. code-block:: rst

                 .. current developments

                 v$VERSION

                 ====================

    :news: str, path to directory containing news files. The default is 'news'.
    :ignore: list of str, regexes of filenames in the news directory to ignore.
             The default is ['TEMPLATE'].
    :latest: str, file to write just the latest part of the changelog to.
        This defaults to ``$REVER_DIR/LATEST``. This is evaluated in the
        current environment.
    """

    def __init__(self, *, deps=frozenset()):
        super().__init__(name='changelog', deps=deps, func=self._func,
                         desc="Manages keeping a changelog up-to-date.")
        self._re_cache = {}

    def _func(self, filename='CHANGELOG', pattern='.. current developments',
              header='.. current developments\n\nv$VERSION\n'
                     '====================\n\n',
              news='news', ignore=('TEMPLATE',),
              latest='$REVER_DIR/LATEST'):
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
                if val == 'None':
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
