"""Rever tools tests"""
import os

from rever.tools import indir


def test_indir():
    cur = os.getcwd()
    new = os.path.dirname(cur)
    with indir(new):
        assert os.getcwd() == new
    assert os.getcwd() == cur
