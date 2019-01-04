"""Utilities for dealing with authorship files."""
import os
import sys

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
        if author not in by_names and email not in by_email:
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
                    "\n\n")
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
                    "\n\n")
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
                    "- name: Some Body\n"
                    "  email: {email}\n"
                    "  aliases:\n"
                    "    - {author}\n"
                    "\n\n")
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
                    "\n\n")
    if not msg:
        # no errors
        return
    # have errors
    msg = "\n----\n".join(msgs).format(author=author, email=email, filename=filename).strip()
    print(msg, file=sys.stderr)
    raise RuntimeError("Duplicated author/email combos")


def update_metadate(filename):
    """Takes a YAML metadata filename and updates it with the current repo
    information, if possible.
    """
    # get the initial YAML
    y = YAML()
    if os.path.exists(filename):
        with open(filename) as f:
            y.load(f)
    else:
        y.load("[]")
    # update with content
    by_names = {}
    by_emails = {}
    for x in y:
        # names
        by_names[x["name"]] = x
        by_names.update({a: x for a in x.get('aliases', [])})
        # emails
        by_emails[x["email"]] = x
        by_emails.update({e: x for e in x.get('alternate_emails', [])})
    _verify_names_emails_aliases(y, by_names, by_emails)
    # write back out
    with open(filename, 'w') as f:
        y.dump(f)
    return y
