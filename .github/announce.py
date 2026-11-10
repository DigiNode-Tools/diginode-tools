#!/usr/bin/env python3
"""The release's announcement: the "Announce: ..." line of a release in docs/release_notes.md.

It's what the diginode.tools website posts on Bluesky and Nostr with the release's blog post (the blog post's link,
with its share card, goes underneath). It never appears in the GitHub release, Telegram, the release banner or the
blog post itself - release.sh leaves it out of all of them.

Write it in your own words: what's new, in a line or two. Mention @digibyte.org only when the release is about
DigiByte Core (it's optional). #DigiByte and #DigiNode are added at the end if they aren't there already.
Bluesky allows 300 characters (the link doesn't count - it becomes a card).

Usage:
  announce.py fix NOTES_MD HEADING    Add any missing hashtags to the Announce line under HEADING (e.g.
                                      "### DigiNode Tools v26.11.02 - 2026-11-17"), in place, and print it.
                                      Warns (doesn't fail) if there's no Announce line or it's too long - the website
                                      then uses a plain announcement made from the release's titles.
  announce.py show NOTES_MD [HEADING] Print the Announce line (default: under "Unreleased"), with its length.
"""
import re
import sys
import unicodedata

HASHTAGS = ["#DigiByte", "#DigiNode"]
LIMIT = 300
UNRELEASED = "### DigiNode Tools - Unreleased"


def length(text):
    """Roughly what Bluesky counts (graphemes): characters, not counting joiners, emoji variation selectors, skin
    tones or combining marks."""
    return sum(1 for c in text
               if c not in "‍️︎" and not 0x1F3FB <= ord(c) <= 0x1F3FF and not unicodedata.combining(c))


def with_hashtags(text):
    text = text.strip()
    missing = [h for h in HASHTAGS if not re.search(re.escape(h) + r"\b", text, re.I)]
    return f"{text} {' '.join(missing)}" if missing else text


def find(lines, heading):
    """Index of the Announce line under heading, or None (and whether the heading exists)."""
    on = False
    for n, line in enumerate(lines):
        if line.rstrip("\n") == heading:
            on = True
            continue
        if on and line.startswith("### DigiNode Tools"):
            break
        if on and re.match(r"^Announce:", line):
            return n, True
    return None, on


def warn(msg):
    print(f"::warning::{msg}", file=sys.stderr)


def main():
    if len(sys.argv) < 3 or sys.argv[1] not in ("fix", "show"):
        sys.exit(__doc__)
    cmd, path = sys.argv[1], sys.argv[2]
    heading = sys.argv[3] if len(sys.argv) > 3 else UNRELEASED
    with open(path, encoding="utf-8") as f:
        lines = f.readlines()
    n, found_heading = find(lines, heading)
    if not found_heading:
        sys.exit(f"ERROR: no \"{heading}\" heading in {path}")
    if n is None:
        warn("This release has no 'Announce: ...' line in docs/release_notes.md, so the website will announce it "
             "on Bluesky and Nostr with a plain line made from the release's titles.")
        return
    text = lines[n].split(":", 1)[1].strip()
    if cmd == "fix":
        text = with_hashtags(text)
        lines[n] = f"Announce: {text}\n"
        with open(path, "w", encoding="utf-8") as f:
            f.writelines(lines)
    count = length(with_hashtags(text))
    print(text)
    print(f"({count} of {LIMIT} characters{', with the hashtags added' if cmd == 'show' else ''})")
    if count > LIMIT:
        warn(f"The Announce line is {count} characters - Bluesky allows {LIMIT}. The website will use a plain "
             "announcement made from the release's titles instead. Shorten it in docs/release_notes.md.")


if __name__ == "__main__":
    main()
