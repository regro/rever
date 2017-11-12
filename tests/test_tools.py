"""Rever tools tests"""
import os

from rever.tools import indir, render_authors, hash_url


def test_indir():
    cur = os.getcwd()
    new = os.path.dirname(cur)
    with indir(new):
        assert os.getcwd() == new
    assert os.getcwd() == cur


def test_render_authors():
    for a, b in zip([(), ('Jane Doe'), ('Jane Doe', 'John Smith')], ['', 'Jane Doe', 'Jane Doe and John Smith']):
        assert render_authors(a) == b


def test_hash_url():
    hash_url('http://python.org')
