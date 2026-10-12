#!/usr/bin/env python3
#
# Name:    latest-release-json.py
# Purpose: Write docs/latest-release.json: a small summary of the latest DigiNode Tools release (version, date, a short
#          summary built from the release notes' titles, and links). It's read by the DigiNode Widgets (WordPress
#          plugin and website embed, https://github.com/DigiNode-Tools/diginode-widgets), and anyone else who wants
#          to show the latest release. Run by '.github/release.sh prepare'.
#
#          Public address: https://raw.githubusercontent.com/DigiNode-Tools/diginode-tools/main/docs/latest-release.json
#          Keep the existing fields as they are - other people's sites may rely on them. Adding fields is fine.
#
# Usage:   latest-release-json.py NOTES_FILE OUT_FILE VERSION DATE FIRST_RELEASE_DAY RELEASE_EVERY_DAYS
#          NOTES_FILE is the release's notes as written by 'release.sh prepare' (one '- Type: **Title** - text' per line).

import datetime
import json
import re
import sys

RELEASE_NOTES_URL = "https://diginode.tools/release-notes/"
GITHUB_URL = "https://github.com/DigiNode-Tools/diginode-tools/releases/tag/v{version}"


def main():
    notes_file, out_file, version, date, first_day, every = sys.argv[1:7]

    highlights = []
    with open(notes_file, encoding="utf-8") as f:
        for line in f:
            m = re.match(r"^- (New|Improvement|Fix): (.+)$", line.strip())
            if not m:
                continue
            t = re.match(r"^\*\*(.+?)\*\*\s*[-–—]\s*(.+)$", m.group(2))
            title = t.group(1) if t else re.split(r"(?<=[.!?])\s", m.group(2), maxsplit=1)[0].rstrip(".")[:60]
            highlights.append({"type": m.group(1), "title": title})

    # A one-line summary from the first titles: "A, b and c." (fewer if it gets long)
    titles = [h["title"] for h in highlights]
    summary = ""
    for n in (3, 2, 1):
        picked = titles[:n]
        if not picked:
            break
        rest = [p[0].lower() + p[1:] if p[:2] != p[:2].upper() else p for p in picked[1:]]   # Keep acronyms
        text = picked[0] if len(picked) == 1 else ", ".join([picked[0]] + rest[:-1]) + " and " + rest[-1]
        if len(titles) > n:
            text = ", ".join([picked[0]] + rest) + " and more"
        summary = text + "."
        if len(summary) <= 90:
            break

    # The next scheduled release (every RELEASE_EVERY_DAYS days from FIRST_RELEASE_DAY), after this release
    released = datetime.date.fromisoformat(date)
    first = datetime.date.fromisoformat(first_day)
    step = int(every)
    nxt = first
    while nxt <= released:
        nxt += datetime.timedelta(days=step)

    data = {
        "name": "DigiNode Tools",
        "version": version,
        "tag": f"v{version}",
        "date": date,
        "summary": summary,
        "highlights": highlights,
        "release_notes_url": RELEASE_NOTES_URL,
        "github_url": GITHUB_URL.format(version=version),
        "next_release": nxt.isoformat(),
        "release_schedule": "Every other Tuesday",
        # The release Tuesdays: first_release_day, then every every_days days. A release only happens on one if there
        # are unreleased notes on develop, so widgets should only show the next one when there are.
        "schedule": {"first_release_day": first_day, "every_days": step},
        "unreleased_notes_url": "https://raw.githubusercontent.com/DigiNode-Tools/diginode-tools/develop/docs/release_notes.md",
    }
    with open(out_file, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write("\n")
    print(f"latest-release.json: v{version} - {summary}")


if __name__ == "__main__":
    main()
