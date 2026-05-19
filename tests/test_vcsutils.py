"""Tests for rever.vcsutils."""
import os
import subprocess

import pytest

from rever import environ, vcsutils


def _make_commit(path, filename, message, author_name, author_email):
    """Write a file and commit it in the given directory."""
    filepath = os.path.join(path, filename)
    with open(filepath, "w") as f:
        f.write(message)
    env = {
        **os.environ,
        "GIT_AUTHOR_NAME": author_name,
        "GIT_AUTHOR_EMAIL": author_email,
        "GIT_COMMITTER_NAME": author_name,
        "GIT_COMMITTER_EMAIL": author_email,
    }
    subprocess.run(["git", "add", filepath], check=True)
    subprocess.run(["git", "commit", "-m", message], check=True, env=env)


@pytest.fixture
def two_author_repo(gitrepo):
    """Extend the base gitrepo with commits from two distinct authors."""
    _make_commit(gitrepo, "a1.txt", "alice commit 1", "Alice", "alice@example.com")
    _make_commit(gitrepo, "a2.txt", "alice commit 2", "Alice", "alice@example.com")
    _make_commit(gitrepo, "b1.txt", "bob commit 1", "Bob", "bob@example.com")
    yield gitrepo


def test_commits_per_email_without_tty(two_author_repo):
    """git_commits_per_email must return correct counts when stdin is not a TTY.

    Regression test: ``git shortlog`` without an explicit revision reads from
    stdin. In non-interactive environments (CI, subprocess, agent runners)
    stdin is empty/closed, so shortlog exits immediately and every author gets
    0 commits. The fix is to always pass HEAD when no ``since`` boundary is
    given.
    """
    cpe = vcsutils.commits_per_email()
    assert cpe.get("alice@example.com") == 2, cpe
    assert cpe.get("bob@example.com") == 1, cpe


def test_commits_per_author_without_tty(two_author_repo):
    """git_commits_per_author must return correct counts when stdin is not a TTY.

    Same root cause as test_commits_per_email_without_tty — both functions
    share the same ``git shortlog`` pattern.
    """
    cpa = vcsutils.commits_per_author()
    assert cpa.get("Alice <alice@example.com>") == 2, cpa
    assert cpa.get("Bob <bob@example.com>") == 1, cpa


def test_commits_per_email_with_since(two_author_repo):
    """When a ``since`` tag is given the range X...HEAD form is still used."""
    vcsutils.tag("v0")
    _make_commit(two_author_repo, "a3.txt", "alice commit 3", "Alice", "alice@example.com")

    cpe = vcsutils.commits_per_email(since="v0")
    assert cpe.get("alice@example.com") == 1, cpe
    assert "bob@example.com" not in cpe, cpe
