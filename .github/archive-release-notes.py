#!/usr/bin/env python3
#
# Name:    archive-release-notes.py
# Purpose: Keep the latest releases in docs/release_notes.md (which is shown on the diginode.tools website) and move
#          older releases to the top of docs/release_notes_more.md (on GitHub). release_notes.md ends with a link to
#          the earlier releases; release_notes_more.md starts with a link back to the latest release notes.
#          Run by '.github/release.sh prepare' (and 'release.sh archive').
#
# Usage:   archive-release-notes.py NOTES_FILE MORE_FILE KEEP

import re
import sys

HEADING = re.compile(r"^### DigiNode Tools v")
EARLIER_LINK = ("[View earlier releases]"
                "(https://github.com/DigiNode-Tools/diginode-tools/blob/main/docs/release_notes_more.md)")
MORE_HEADER = ["## DigiNode Tools Release Notes - Earlier Releases", "",
               "[View the latest release notes](https://diginode.tools/release-notes/)", ""]


def strip_blank_end(lines):
    while lines and not lines[-1].strip():
        lines.pop()
    return lines


def main():
    notes_path, more_path, keep = sys.argv[1], sys.argv[2], int(sys.argv[3])

    with open(notes_path, encoding="utf-8") as f:
        lines = f.read().split("\n")
    lines = strip_blank_end([l for l in lines if not l.startswith("[View earlier releases]")])   # Added back below
    starts = [i for i, l in enumerate(lines) if HEADING.match(l)]
    moved = []
    if len(starts) > keep:
        moved = strip_blank_end(lines[starts[keep]:])
        lines = strip_blank_end(lines[:starts[keep]])
    with open(notes_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines + ["", EARLIER_LINK, ""]))

    try:
        with open(more_path, encoding="utf-8") as f:
            more = f.read().split("\n")
    except FileNotFoundError:
        more = []
    more_starts = [i for i, l in enumerate(more) if HEADING.match(l)]
    older = strip_blank_end(more[more_starts[0]:]) if more_starts else []
    body = moved + ([""] if moved and older else []) + older
    with open(more_path, "w", encoding="utf-8") as f:
        f.write("\n".join(MORE_HEADER + body + [""]))

    moved_count = sum(1 for l in moved if HEADING.match(l))
    print(f"release_notes.md: {min(len(starts), keep)} releases; moved {moved_count} to release_notes_more.md")


if __name__ == "__main__":
    main()
