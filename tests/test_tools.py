"""Rever tools tests"""
import os
import tempfile

import pytest

from rever.tools import indir, render_authors, hash_url, replace_in_file

@pytest.mark.parametrize('inp, pattern, new, leading_whitespace, exp', [
    ('__version__ = "wow.mom"', '__version__\s*=.*', '__version__ = "WAKKA"',
     True, '__version__ = "WAKKA"\n'),
    ('    __version__ = "wow.mom"', '    __version__\s*=.*',
     '    __version__ = "WAKKA"', False, '    __version__ = "WAKKA"\n'),
    ('    __version__ = "wow.mom"', '__version__\s*=.*', '__version__ = "WAKKA"',
     True, '    __version__ = "WAKKA"\n'),
])
def test_replace_in_file(inp, pattern, new, leading_whitespace, exp):
    with tempfile.NamedTemporaryFile('w+t') as f:
        f.write(inp)
        f.seek(0)
        replace_in_file(pattern, new, f.name, leading_whitespace)
        f.seek(0)
        obs = f.read()
    assert exp == obs


def test_indir():
    cur = os.getcwd()
    new = os.path.dirname(cur)
    with indir(new):
        assert os.getcwd() == new
    assert os.getcwd() == cur


def test_render_authors():
    for a, b in zip([(), ('Jane Doe'), ('Jane Doe', 'John Smith')], ['', 'Jane Doe', 'Jane Doe and John Smith']):
        assert render_authors(a) == b


def test_hash_url_http():
    hash_url('http://python.org')


def test_hash_url_ftp():
    has_url('ftp://ftp.astron.com/pub/file/file-5.33.tar.g')
