#!/usr/bin/env bash
#
# Name:    release.sh
# Purpose: Release DigiNode Tools. Used by the "Release DigiNode Tools" GitHub Action (.github/workflows/release.yml),
#          and can be run locally for testing.
#
# Version numbers are YY.MM.NN: the year and month of the release, then 01 for the first release that month, 02 for
# the second, and so on (e.g. v26.10.01). On develop, the version is a placeholder that is always newer than the
# latest release; the real number is set when it is released.
#
# Usage:
#   .github/release.sh version            Print the version the next release will have (from today's date and the tags)
#   .github/release.sh prepare VERSION    Set VERSION and today's date in the scripts and release notes, and write the
#                                         release notes for GitHub to $NOTES_FILE (default: release-notes.md)
#   .github/release.sh bump VERSION       After VERSION is released: set the next placeholder version on develop, and
#                                         start a new "Unreleased" section in the release notes
#   .github/release.sh due                Exit 0 if the scheduled release is due: it's a release Tuesday (every other
#                                         Tuesday, from FIRST_RELEASE_DAY), 10:00 or later (UK time), and there are
#                                         release notes under "Unreleased". Says why or why not.
#   .github/release.sh plan               What a run of the release workflow should do: prints release=true/false,
#                                         source=preview/develop and cut=true/false, for $GITHUB_OUTPUT
#   .github/release.sh build SOURCE       Prepare the release from SOURCE, merge it into main and tag it (nothing is
#                                         pushed). Prints the version.
#   .github/release.sh after VERSION SOURCE  Get develop ready after VERSION was released from SOURCE
#   .github/release.sh cut                Start a new Sponsors Preview from develop (nothing is pushed)
#   .github/release.sh archive            Keep the latest 10 releases in docs/release_notes.md (shown on the website)
#                                         and move older ones to the top of docs/release_notes_more.md. 'prepare' does
#                                         this automatically.
#
# Release notes go under a "### DigiNode Tools - Unreleased" heading at the top of docs/release_notes.md, optionally
# starting with an "Intro: ..." line that sums up the whole release, and an "Announce: ..." line: what the website
# posts on Bluesky and Nostr with the release's blog post (hashtags and all - see .github/announce.py; it's left out of
# the GitHub release, Telegram and everything else). Each release has a "### DigiNode Tools vYY.MM.NN - YYYY-MM-DD"
# heading.
#
# Sponsors Preview: each release goes to sponsors two weeks before everyone else. On a release Tuesday:
#   1. What sponsors have had for the last two weeks (the preview branch) is released to everyone.
#   2. What is on develop becomes the new preview. The preview branch is develop at that moment, with the version it
#      will be released as. On develop, its notes move under "### DigiNode Tools - Sponsors Preview (DATE)", above
#      the release notes, and a new "Unreleased" section starts for the release after that.
# The preview branch is moved with a force push each time: DigiNode Tools installs it with a fresh clone.
# A fix for the current preview goes on develop and is cherry-picked onto preview, its note under the Sponsors Preview
# heading on develop and "Unreleased" on preview.

set -euo pipefail

# The workflow runs a copy of this script from outside the checkout (it switches branches as it goes)
ROOT=${RELEASE_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}
SETUP="$ROOT/diginode-setup.sh"
DASHBOARD="$ROOT/diginode.sh"
NOTES="$ROOT/docs/release_notes.md"
MORE="$ROOT/docs/release_notes_more.md"
KEEP_RELEASES=10    # How many releases release_notes.md (and so the website) shows
FIRST_RELEASE_DAY=2026-10-20   # The first scheduled release (a Tuesday); then every RELEASE_EVERY_DAYS days
RELEASE_EVERY_DAYS=14
UNRELEASED="### DigiNode Tools - Unreleased"
PREVIEW_HEADING="### DigiNode Tools - Sponsors Preview"
PREVIEW_MIN_DAYS=7             # A preview younger than this isn't released by the schedule (a second run the same day)
TODAY=${RELEASE_TODAY:-$(date -u +%Y-%m-%d)}   # RELEASE_TODAY can be set for testing

fail() { echo "ERROR: $1" >&2; exit 1; }

# Count the release notes under the Unreleased heading
unreleased_entries() {
    awk -v h="$UNRELEASED" '$0 == h { on = 1; next } on && /^### DigiNode Tools v/ { exit } on && /^- / { n++ } END { print n + 0 }' "$NOTES"
}

# The heading of the preview on develop (with the day it started), if there is one
preview_heading() {
    grep -m1 "^$PREVIEW_HEADING" "$NOTES" || true
}

# How many days old the preview is
preview_age_days() {
    local day
    day=$(preview_heading | sed -E 's/.*\(([0-9-]+)\).*/\1/')
    python3 -c "import datetime as d, sys; print((d.date.fromisoformat(sys.argv[1]) - d.date.fromisoformat(sys.argv[2])).days)" "$TODAY" "$day"
}

# The first release Tuesday after the given day (YYYY-MM-DD)
next_release_day() {
    python3 -c "import datetime as d, sys
first = d.date.fromisoformat(sys.argv[1]); day = d.date.fromisoformat(sys.argv[2]); every = int(sys.argv[3]); n = first
while n <= day: n += d.timedelta(days=every)
print(n.isoformat())" "$FIRST_RELEASE_DAY" "$1" "$RELEASE_EVERY_DAYS"
}

# The next free version in the month of the given day (YYYY-MM-DD)
version_for_day() {
    local prefix last
    prefix="v$(python3 -c "import datetime as d, sys; print(d.date.fromisoformat(sys.argv[1]).strftime('%y.%m'))" "$1")."
    last=$(git -C "$ROOT" tag -l "${prefix}*" | sed "s/^${prefix//./\\.}//" | grep -E '^[0-9]+$' | sort -n | tail -1 || true)
    printf '%s%02d\n' "${prefix#v}" $(( 10#${last:-0} + 1 ))
}

# The version after this one, as a placeholder that is always newer
version_after() {
    [[ "$1" =~ ^([0-9]{2})\.([0-9]{2})\.([0-9]{2})$ ]] || fail "Version must look like 26.10.01"
    printf '%s.%s.%02d\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" $(( 10#${BASH_REMATCH[3]} + 1 ))
}

# Set the version number everywhere it appears in the two scripts
set_version() {
    local ver="$1"
    sed -i.bak -E \
        -e "s/^(#[[:space:]]+Name:[[:space:]]+DigiNode Setup v).*/\1$ver/" \
        -e "s/^DGNT_VER_LIVE=.*/DGNT_VER_LIVE=$ver/" \
        -e "s/^# Last Updated: .*/# Last Updated: $TODAY/" "$SETUP"
    sed -i.bak -E \
        -e "s/^(#[[:space:]]+Name:[[:space:]]+DigiNode Dashboard v).*/\1$ver/" \
        -e "s/^DGNT_VER_LOCAL=.*/DGNT_VER_LOCAL=$ver/" \
        -e "s/^# Last Updated: .*/# Last Updated: $TODAY/" "$DASHBOARD"
    rm -f "$SETUP.bak" "$DASHBOARD.bak"

    grep -q "^DGNT_VER_LIVE=$ver$" "$SETUP" || fail "Couldn't set DGNT_VER_LIVE in diginode-setup.sh"
    grep -q "^DGNT_VER_LOCAL=$ver$" "$DASHBOARD" || fail "Couldn't set DGNT_VER_LOCAL in diginode.sh"
    grep -qE "Name:[[:space:]]+DigiNode Setup v$ver$" "$SETUP" || fail "Couldn't set the Name line in diginode-setup.sh"
    grep -qE "Name:[[:space:]]+DigiNode Dashboard v$ver$" "$DASHBOARD" || fail "Couldn't set the Name line in diginode.sh"
}

case "${1:-}" in

    version)
        cd "$ROOT"
        version_for_day "$TODAY"
        ;;

    prepare)
        ver="${2:?prepare needs a version}"
        [[ "$ver" =~ ^[0-9]{2}\.[0-9]{2}\.[0-9]{2}$ ]] || fail "Version must look like 26.10.01"

        # The release notes must have an Unreleased section, with something in it
        grep -qx "$UNRELEASED" "$NOTES" || fail "docs/release_notes.md has no \"$UNRELEASED\" heading"
        entries=$(unreleased_entries)
        [ "$entries" -gt 0 ] || fail "There is nothing under \"$UNRELEASED\" in docs/release_notes.md"

        set_version "$ver"
        heading="DigiNode Tools v$ver - $TODAY"
        sed -i.bak "s/^$UNRELEASED\$/### $heading/" "$NOTES" && rm -f "$NOTES.bak"

        # The announcement for Bluesky and Nostr (posted by the website): add any missing hashtags, warn if it's
        # missing or too long. It stays in release_notes.md for the website to read.
        "$ROOT/.github/announce.py" fix "$NOTES" "### $heading"

        # The GitHub release shows the heading (as plain text), a blank line, then the entries (as earlier releases).
        # An "Intro: ..." line (the release's summary, also the website post's first paragraph) becomes a paragraph
        # of its own above the entries. The "Announce: ..." line (for Bluesky and Nostr) is left out.
        notes_file="${NOTES_FILE:-$ROOT/release-notes.md}"
        {
            echo "$heading"
            echo ""
            awk -v h="### $heading" '$0 == h { on = 1; next } on && /^### DigiNode Tools v/ { exit } on && !/^\[View earlier releases\]/' "$NOTES" | sed '/^[[:space:]]*$/d' \
                | awk '/^Announce:/ { next } /^Intro:/ { sub(/^Intro:[[:space:]]*/, ""); print; print ""; next } { print }'
        } > "$notes_file"

        # The website shows the latest releases; older ones move to release_notes_more.md
        "$ROOT/.github/archive-release-notes.py" "$NOTES" "$MORE" "$KEEP_RELEASES"

        # A summary of this release for the DigiNode Widgets (website banner) and anyone else who wants it
        "$ROOT/.github/latest-release-json.py" "$notes_file" "$ROOT/docs/latest-release.json" "$ver" "$TODAY" \
            "$FIRST_RELEASE_DAY" "$RELEASE_EVERY_DAYS"
        echo "Prepared v$ver ($entries release notes)"
        ;;

    bump)
        ver="${2:?bump needs the version that was just released}"
        [[ "$ver" =~ ^([0-9]{2})\.([0-9]{2})\.([0-9]{2})$ ]] || fail "Version must look like 26.10.01"
        next=$(version_after "$ver")
        set_version "$next"

        # Start a new Unreleased section above the release that was just made
        grep -qx "$UNRELEASED" "$NOTES" && { echo "Develop is now v$next (placeholder until the next release)"; exit 0; }
        awk -v h="$UNRELEASED" 'done != 1 && /^### DigiNode Tools v/ { print h; print ""; done = 1 } { print }' "$NOTES" > "$NOTES.new"
        mv "$NOTES.new" "$NOTES"
        echo "Develop is now v$next (placeholder until the next release)"
        ;;

    due)
        # Scheduled release, every other Tuesday: the workflow runs at 09:07 and 10:07 UTC every Tuesday, so that one
        # run is at 10:xx UK time whether or not it's summer time. Release only on a release Tuesday (FIRST_RELEASE_DAY,
        # then every RELEASE_EVERY_DAYS days), at 10:00 UK time or later, if there is anything to release.
        # (Once released, "Unreleased" is empty again, so the second run does nothing.)
        uk_day=${UK_DAY:-$(TZ=Europe/London date +%Y-%m-%d)}   # UK_DAY and UK_HOUR can be set for testing
        days=$(python3 -c "import datetime as d, sys; print((d.date.fromisoformat(sys.argv[1]) - d.date.fromisoformat(sys.argv[2])).days)" "$uk_day" "$FIRST_RELEASE_DAY")
        if [ "$days" -lt 0 ] || [ $(( days % RELEASE_EVERY_DAYS )) -ne 0 ]; then
            next=$(python3 -c "import datetime as d, sys
first = d.date.fromisoformat(sys.argv[1]); today = d.date.fromisoformat(sys.argv[2]); every = int(sys.argv[3])
n = first if today <= first else first + d.timedelta(days=-(-(today - first).days // every) * every)
print(n.strftime('%A %d %B %Y'))" "$FIRST_RELEASE_DAY" "$uk_day" "$RELEASE_EVERY_DAYS")
            echo "No release today - the next scheduled release is on $next"
            exit 1
        fi
        uk_hour=${UK_HOUR:-$(TZ=Europe/London date +%H)}
        if [ "$((10#$uk_hour))" -lt 10 ]; then
            echo "It's ${uk_hour}:xx UK time - the release happens at 10:00"
            exit 1
        fi
        entries=$(unreleased_entries)
        if [ "$entries" -eq 0 ]; then
            echo "Nothing to release - there is nothing under \"$UNRELEASED\" in docs/release_notes.md"
            exit 1
        fi
        echo "The scheduled release is due ($entries release notes)"
        ;;

    plan)
        # Scheduled runs: is it a release Tuesday, at 10:00 UK time or later? (MANUAL=true skips this and the age check.)
        # EMERGENCY=true releases develop straight to everyone, when there is no preview waiting.
        manual=${MANUAL:-false}; emergency=${EMERGENCY:-false}
        pending=no; [ -n "$(preview_heading)" ] && pending=yes
        entries=$(unreleased_entries)
        if [ "$emergency" = "true" ]; then
            [ "$pending" = "no" ] || fail "A Sponsors Preview is waiting: release that instead (a fix goes on the preview branch too)"
            [ "$entries" -gt 0 ] || fail "There is nothing under \"$UNRELEASED\" in docs/release_notes.md"
            echo "Emergency release of develop to everyone" >&2
            printf 'release=true\nsource=develop\ncut=false\n'
            exit 0
        fi
        if [ "$manual" != "true" ]; then
            uk_day=${UK_DAY:-$(TZ=Europe/London date +%Y-%m-%d)}
            uk_hour=${UK_HOUR:-$(TZ=Europe/London date +%H)}
            days=$(python3 -c "import datetime as d, sys; print((d.date.fromisoformat(sys.argv[1]) - d.date.fromisoformat(sys.argv[2])).days)" "$uk_day" "$FIRST_RELEASE_DAY")
            if [ "$days" -lt 0 ] || [ $(( days % RELEASE_EVERY_DAYS )) -ne 0 ] || [ "$((10#$uk_hour))" -lt 10 ]; then
                echo "Not a release time (next release day: $(next_release_day "$uk_day"))" >&2
                printf 'release=false\nsource=\ncut=false\n'
                exit 0
            fi
            if [ "$pending" = "yes" ] && [ "$(RELEASE_TODAY=$uk_day preview_age_days)" -lt "$PREVIEW_MIN_DAYS" ]; then
                echo "This preview only started on $(preview_heading | sed -E 's/.*\((.*)\).*/\1/') - nothing more to do today" >&2
                printf 'release=false\nsource=\ncut=false\n'
                exit 0
            fi
        fi
        release=false; [ "$pending" = "yes" ] && release=true
        cut=false; [ "$entries" -gt 0 ] && cut=true
        echo "Release the preview: $release. Start a new preview from develop: $cut ($entries notes)." >&2
        printf 'release=%s\nsource=%s\ncut=%s\n' "$release" "$([ "$release" = true ] && echo preview)" "$cut"
        ;;

    build)
        source_branch="${2:?build needs a source branch}"
        exec 3>&1 1>&2   # Only the version goes to stdout: the workflow reads it
        cd "$ROOT"
        git checkout -q "$source_branch"
        ver=$(version_for_day "$TODAY")
        git rev-parse -q --verify "refs/tags/v$ver" > /dev/null && fail "Tag v$ver already exists"
        "$0" prepare "$ver"
        git commit -qam "Release v$ver"
        tools_from=${TOOLS_FROM:-develop}
        git checkout -q main
        # main should always end up matching what is released: if a file was also changed on main, the release's
        # version wins, so the merge can't stop with a conflict. The release tooling always comes from develop.
        git merge --no-ff -q -X theirs "$source_branch" -m "Release v$ver (merge $source_branch into main)"
        if [ "$source_branch" != "$tools_from" ]; then
            git checkout -q "$tools_from" -- .github
            git diff --cached --quiet || git commit -q --amend --no-edit
        fi
        git tag -a "v$ver" -m "DigiNode Tools v$ver"
        echo "$ver" >&3
        ;;

    after)
        ver="${2:?after needs the version}"; source_branch="${3:?after needs the source branch}"
        cd "$ROOT"
        git checkout -q develop
        if [ "$source_branch" != "develop" ]; then
            # The preview's notes become this release's, as on main. Anything newer stays under Unreleased.
            old=$(preview_heading)
            day=$(sed -n "s/^### DigiNode Tools v$ver - //p" <(git show "main:docs/release_notes.md") | head -1)
            [ -n "$old" ] && [ -n "$day" ] || fail "Couldn't find the preview's notes to mark as released"
            python3 - "$NOTES" "$old" "### DigiNode Tools v$ver - $day" <<'PYEOF'
import sys
p, old, new = sys.argv[1:4]
t = open(p, encoding="utf-8").read()
assert t.count(old + "\n") == 1
open(p, "w", encoding="utf-8").write(t.replace(old + "\n", new + "\n"))
PYEOF
            "$ROOT/.github/archive-release-notes.py" "$NOTES" "$MORE" "$KEEP_RELEASES"
            git checkout -q main -- docs/latest-release.json
        fi
        "$0" bump "$ver"
        git add -A docs diginode-setup.sh diginode.sh
        git commit -qm "Develop: placeholder version for the next release"
        ;;

    cut)
        exec 3>&1 1>&2   # Only the version goes to stdout: the workflow reads it
        cd "$ROOT"
        git checkout -q develop
        [ -z "$(preview_heading)" ] || fail "There is already a Sponsors Preview waiting to be released"
        [ "$(unreleased_entries)" -gt 0 ] || fail "There is nothing under \"$UNRELEASED\" in docs/release_notes.md"
        release_day=$(next_release_day "$TODAY")
        ver=$(version_for_day "$release_day")

        # The preview branch: develop now, with the version it will be released as. Its notes stay under "Unreleased",
        # which is what tells the website's banner that a release is coming.
        git checkout -q -B preview develop
        set_version "$ver"
        git commit -q --allow-empty -am "Sponsors Preview v$ver (to be released on $release_day)"

        # Develop: these notes are spoken for, and new ones start again under a new Unreleased heading
        git checkout -q develop
        sed -i.bak "s/^$UNRELEASED\$/$UNRELEASED\n\n$PREVIEW_HEADING ($TODAY)/" "$NOTES" && rm -f "$NOTES.bak"
        set_version "$(version_after "$ver")"
        git commit -qam "Sponsors Preview v$ver started: develop moves on to the next release"
        echo "$ver" >&3
        ;;

    archive)
        "$ROOT/.github/archive-release-notes.py" "$NOTES" "$MORE" "$KEEP_RELEASES"
        ;;

    *)
        sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'
        exit 1
        ;;
esac
