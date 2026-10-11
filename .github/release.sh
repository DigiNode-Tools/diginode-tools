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
#   .github/release.sh due                Exit 0 if the weekly release is due: it's 10:00 or later (UK time) and there
#                                         are release notes under "Unreleased". Says why or why not.
#
# Release notes go under a "DigiNode Tools - Unreleased" heading at the top of docs/release_notes.md.

set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
SETUP="$ROOT/diginode-setup.sh"
DASHBOARD="$ROOT/diginode.sh"
NOTES="$ROOT/docs/release_notes.md"
UNRELEASED="DigiNode Tools - Unreleased"
TODAY=$(date -u +%Y-%m-%d)

fail() { echo "ERROR: $1" >&2; exit 1; }

# Count the release notes under the Unreleased heading
unreleased_entries() {
    awk -v h="$UNRELEASED" '$0 == h { on = 1; next } on && /^DigiNode Tools v/ { exit } on && /^- / { n++ } END { print n + 0 }' "$NOTES"
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
        prefix="v$(date -u +%y.%m)."
        last=$(git tag -l "${prefix}*" | sed "s/^${prefix//./\\.}//" | grep -E '^[0-9]+$' | sort -n | tail -1 || true)
        printf '%s%02d\n' "${prefix#v}" $(( 10#${last:-0} + 1 ))
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
        sed -i.bak "s/^$UNRELEASED\$/$heading/" "$NOTES" && rm -f "$NOTES.bak"

        # The GitHub release shows the heading, a blank line, then the entries (the same as earlier releases)
        notes_file="${NOTES_FILE:-$ROOT/release-notes.md}"
        {
            echo "$heading"
            echo ""
            awk -v h="$heading" '$0 == h { on = 1; next } on && /^DigiNode Tools v/ { exit } on' "$NOTES" | sed '/^[[:space:]]*$/d'
        } > "$notes_file"
        echo "Prepared v$ver ($entries release notes)"
        ;;

    bump)
        ver="${2:?bump needs the version that was just released}"
        [[ "$ver" =~ ^([0-9]{2})\.([0-9]{2})\.([0-9]{2})$ ]] || fail "Version must look like 26.10.01"
        next=$(printf '%s.%s.%02d' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" $(( 10#${BASH_REMATCH[3]} + 1 )))
        set_version "$next"

        # Start a new Unreleased section above the release that was just made
        awk -v h="$UNRELEASED" 'done != 1 && /^DigiNode Tools v/ { print h; print ""; done = 1 } { print }' "$NOTES" > "$NOTES.new"
        mv "$NOTES.new" "$NOTES"
        echo "Develop is now v$next (placeholder until the next release)"
        ;;

    due)
        # Weekly release (Tuesdays): the workflow runs at 09:07 and 10:07 UTC, so that one run is at 10:xx UK time
        # whether or not it's summer time. Release at 10:00 UK time or later, if there is anything to release.
        # (Once released, "Unreleased" is empty again, so the second run does nothing.)
        uk_hour=${UK_HOUR:-$(TZ=Europe/London date +%H)}   # UK_HOUR can be set for testing
        if [ "$((10#$uk_hour))" -lt 10 ]; then
            echo "It's ${uk_hour}:xx UK time - the weekly release happens at 10:00"
            exit 1
        fi
        entries=$(unreleased_entries)
        if [ "$entries" -eq 0 ]; then
            echo "Nothing to release - there is nothing under \"$UNRELEASED\" in docs/release_notes.md"
            exit 1
        fi
        echo "The weekly release is due ($entries release notes)"
        ;;

    *)
        sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
        exit 1
        ;;
esac
