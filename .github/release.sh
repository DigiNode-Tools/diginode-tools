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
#   .github/release.sh schedule DAYS      Schedule the next release for DAYS days from today, by writing the date to
#                                         .github/release-on (commit it to develop). "cancel" removes it.
#   .github/release.sh due                Exit 0 if a scheduled release is due today (the date in .github/release-on has
#                                         arrived and there are release notes), and say why or why not
#
# Release notes go under a "DigiNode Tools - Unreleased" heading at the top of docs/release_notes.md.

set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
SETUP="$ROOT/diginode-setup.sh"
DASHBOARD="$ROOT/diginode.sh"
NOTES="$ROOT/docs/release_notes.md"
UNRELEASED="DigiNode Tools - Unreleased"
TODAY=$(date -u +%Y-%m-%d)
RELEASE_ON_FILE="$ROOT/.github/release-on"

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
        rm -f "$RELEASE_ON_FILE"   # The scheduled release (if any) is happening now
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

        rm -f "$RELEASE_ON_FILE"
        echo "Develop is now v$next (placeholder until the next release)"
        ;;

    schedule)
        days="${2:?schedule needs a number of days, or cancel}"
        if [ "$days" = "cancel" ]; then
            rm -f "$RELEASE_ON_FILE"
            echo "The scheduled release has been cancelled"
            exit 0
        fi
        [[ "$days" =~ ^[0-9]+$ ]] && [ "$days" -ge 1 ] && [ "$days" -le 90 ] || fail "Days must be a number from 1 to 90"
        # GNU date (GitHub Actions, Linux), or BSD date (Mac)
        on=$(date -u -d "+$days days" +%Y-%m-%d 2>/dev/null || date -u -v+"$days"d +%Y-%m-%d)
        echo "$on" > "$RELEASE_ON_FILE"
        echo "The next release is scheduled for $on"
        ;;

    due)
        if [ ! -f "$RELEASE_ON_FILE" ]; then
            echo "No release is scheduled"
            exit 1
        fi
        on=$(tr -d '[:space:]' < "$RELEASE_ON_FILE")
        [[ "$on" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || fail ".github/release-on doesn't contain a date (YYYY-MM-DD): $on"
        if [[ "$TODAY" < "$on" ]]; then
            echo "The next release is scheduled for $on - not yet"
            exit 1
        fi
        if [ "$(unreleased_entries)" -eq 0 ]; then
            echo "A release was scheduled for $on, but there is nothing under \"$UNRELEASED\" in docs/release_notes.md"
            exit 1
        fi
        echo "The release scheduled for $on is due"
        ;;

    *)
        sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
        exit 1
        ;;
esac
