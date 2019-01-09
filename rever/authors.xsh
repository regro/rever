"""Utilities for dealing with authorship files."""
import os
import sys
import datetime
import itertools

from lazyasd import lazyobject

from rever import vcsutils


@lazyobject
def YAML():
    from ruamel.yaml import YAML as y
    return y


def _verify_names_emails_aliases(y, by_names, by_emails, filename):
    aes = vcsutils.authors_emails()
    msgs = []
    for author, email in aes:
        if author not in by_names and email not in by_emails:
            # new author
            entry = {'name': author, 'email': email}
            y.append(entry)
            by_names[author] = by_emails[email] = entry
        elif author in by_names:
            # check that email matches known email
            entry = by_emails.get(email, None)
            if entry is None:
                msgs.append(
                    "{author!r} does not have {email!r} listed! "
                    "Please add the email to {author!r} in {filename!r}. "
                    "For example:\n\n"
                    "- name: {author}\n"
                    "  email: {email}\n\n"
                    "Or add an alternative email:\n\n"
                    "- name: {author}\n"
                    "  email: person@example.com\n"
                    "  alternate_emails:\n"
                    "    - {email}\n"
                    "\n".format(author=author, email=email, filename=filename))
            elif entry["name"] != author and author not in entry.get("aliases", []):
                msgs.append(
                    "The email {email!r} is associated in version control with "
                    "{author!r}, but is currently assigned to " + entry["name"] + "."
                    "Please either add {author} as an alias to " + entry["name"] + " in "
                    "{filename!r} with:\n\n"
                    "- name: " + entry["name"] + "\n"
                    "  email: {email}\n"
                    "  aliases:\n"
                    "    - {author}\n\n"
                    "or remove {email} from " + entry["name"] + ".\n"
                    "\n")
                msgs[-1] = msgs[-1].format(author=author, email=email, filename=filename)
        elif email in by_emails:
            # check that author matches known name
            entry = by_names.get(author, None)
            if entry is None:
                msgs.append(
                    "{email!r} does not have {author!r} listed! "
                    "Please add the name to {email!r} in {filename!r}. "
                    "For example:\n\n"
                    "- name: {author}\n"
                    "  email: {email}\n\n"
                    "Or add an alias:\n\n"
                    "- name: Some Body Else\n"
                    "  email: {email}\n"
                    "  aliases:\n"
                    "    - {author}\n"
                    "\n".format(author=author, email=email, filename=filename))
            elif entry["email"] != email and email not in entry.get("alternate_emails", []):
                msgs.append(
                    "The author {author!r} is associated in version control with "
                    "{email!r}, but is currently assigned to " + entry["email"] + "."
                    "Please either add {email} as an alternate email to " + entry["email"] + " in "
                    "{filename!r} with:\n\n"
                    "- name: {author}\n"
                    "  email: " + entry["email"] + "\n"
                    "  alternate_emails:\n"
                    "    - {email}\n\n"
                    "or remove {author} from " + entry["email"] + ".\n"
                    "\n")
                msgs[-1] = msgs[-1].format(author=author, email=email, filename=filename)
    if not msgs:
        # no errors
        return
    # have errors
    msg = "\n\n----\n\n".join(msgs).strip()
    print(msg, file=sys.stderr)
    raise RuntimeError("Duplicated author/email combos")


def load_metadata(filename, return_yaml=False):
    """Loads author metadata file."""
    yaml = YAML()
    if os.path.exists(filename):
        with open(filename) as f:
            y = yaml.load(f)
    else:
        y = yaml.load("[]")
    if return_yaml:
        return y, yaml
    else:
        return y


def update_metadata(filename):
    """Takes a YAML metadata filename and updates it with the current repo
    information, if possible.
    """
    # get the initial YAML
    y, yaml = load_metadata(filename, return_yaml=True)
    # verify names and emails
    by_names = {}
    by_emails = {}
    for x in y:
        # names
        by_names[x["name"]] = x
        by_names.update({a: x for a in x.get('aliases', [])})
        # emails
        by_emails[x["email"]] = x
        by_emails.update({e: x for e in x.get('alternate_emails', [])})
    _verify_names_emails_aliases(y, by_names, by_emails, filename)
    # update with content
    now = datetime.datetime.now()
    cpe = vcsutils.commits_per_email()
    fcpe = None
    for x in y:
        x["num_commits"] = cpe.get(x["email"], 0) + sum([cpe.get(a, 0) for a in x.get("alternate_emails", [])])
        # only compute first commits if needed.
        if "first_commit" not in x:
            if fcpe is None:
                fcpe = vcsutils.first_commit_per_email()
            fcs = [fcpe.get(x["email"], now)] + [fcpe.get(a, now) for a in x.get("alternate_emails", [])]
            x["first_commit"] = min(fcs)
    # write back out
    with open(filename, 'w') as f:
        yaml.dump(y, f)
    return y


MAILMAP_HEADER = """# This file was autogenerated by rever: https://regro.github.io/rever-docs/
# This prevent git from showing duplicates with various logging commands.
# See the git documentation for more details. The syntax is:
#
#   good-name <good-email> bad-name <bad-email>
#
# You can skip bad-name if it is the same as good-name and is unique in the repo.
#
# This file is up-to-date if the command git log --format="%aN <%aE>" | sort -u
# gives no duplicates.
"""

def write_mailmap(metadata, filename):
    """Writes a mailmap file from the metadata (list of author dicts) provided."""
    lines = [MAILMAP_HEADER]
    nepair = "{name} <{email}>"
    for author in metadata:
        good = nepair.format(**author)
        if "aliases" not in author and "alternate_emails" not in author:
            # single name & email combo
            lines.append(good)
            continue
        aliases = author.get("aliases", [author["name"]])
        alt_emails = author.get("alternate_emails", [author["email"]])
        for bad_name, bad_email in itertools.product(aliases, alt_emails):
            bad = nepair.format(name=bad_name, email=bad_email)
            lines.append(good + " " + bad)
    lines.append('')
    s = "\n".join(lines)
    with open(filename, 'w') as f:
        f.write(s)
