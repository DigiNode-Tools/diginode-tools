#!/usr/bin/env bash
#
# Name:    telegram-announce.sh
# Purpose: Announce a DigiNode Tools release in the DigiNode Tools Telegram group (posted by @diginode_tools_bot,
#          "DigiNode Tools Releases"), and pin it. Used by the "Release DigiNode Tools" GitHub Action after a
#          release is published.
#
# Usage:
#   .github/telegram-announce.sh preview VERSION NOTES_FILE   Print the message (nothing is sent)
#   .github/telegram-announce.sh send VERSION NOTES_FILE      Send and pin the message
#
# NOTES_FILE is the release notes written by 'release.sh prepare' (a heading, then "- New: ..." lines).
# Sending needs TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID (GitHub secrets).

set -euo pipefail

MODE="${1:-}"
VERSION="${2:?version needed}"
NOTES_FILE="${3:?notes file needed}"
[ -f "$NOTES_FILE" ] || { echo "ERROR: $NOTES_FILE not found" >&2; exit 1; }

RELEASE_URL="https://github.com/DigiNode-Tools/diginode-tools/releases/tag/v$VERSION"
SPONSOR_URL="https://github.com/sponsors/DigiNode-Tools"
MAX_LENGTH=4000   # Telegram allows 4096 characters

# Escape text for Telegram's HTML formatting
html() {
    sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
}

# One line per release note: 🆕 New, ✨ Improvement, 🔧 Fix
notes=$(grep '^- ' "$NOTES_FILE" | sed 's/^- //' | html | sed -E \
    -e 's/^New: /🆕 <b>New:<\/b> /' \
    -e 's/^Improvement: /✨ <b>Improvement:<\/b> /' \
    -e 's/^Fix: /🔧 <b>Fix:<\/b> /')
[ -n "$notes" ] || { echo "ERROR: no release notes found in $NOTES_FILE" >&2; exit 1; }

header="🚀 <b>DigiNode Tools v$VERSION is out!</b>"
footer="To update, run <code>diginode-setup</code> and choose <b>Update</b>.
<a href=\"$RELEASE_URL\">Release notes on GitHub</a>

❤️ DigiNode Tools is free, and I build it in my spare time. If you find it useful, please consider <a href=\"$SPONSOR_URL\">sponsoring me</a>. Thank you!"

build() {
    printf '%s\n\n%s\n\n%s' "$header" "$1" "$footer"
}

# Notes separated by blank lines. If it's too long, include as many notes as fit, then point to the release notes.
shown=""
all_fit="yes"
budget=$(( MAX_LENGTH - ${#header} - ${#footer} - 60 ))
while IFS= read -r line; do
    candidate="${shown:+$shown$'\n\n'}$line"
    if [ "${#candidate}" -gt "$budget" ]; then
        all_fit="no"
        break
    fi
    shown="$candidate"
done <<< "$notes"
if [ "$all_fit" = "no" ]; then
    shown="$shown"$'\n\n'"…and more - see the release notes below."
fi
message=$(build "$shown")

case "$MODE" in

    preview)
        echo "$message"
        echo
        echo "(${#message} characters)"
        ;;

    send)
        : "${TELEGRAM_BOT_TOKEN:?TELEGRAM_BOT_TOKEN is not set}"
        : "${TELEGRAM_CHAT_ID:?TELEGRAM_CHAT_ID is not set}"
        api="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}"

        response=$(curl -sS --max-time 30 "$api/sendMessage" \
            --data-urlencode "chat_id=$TELEGRAM_CHAT_ID" \
            --data-urlencode "text=$message" \
            --data-urlencode "parse_mode=HTML" \
            --data-urlencode "disable_notification=true" \
            --data-urlencode 'link_preview_options={"is_disabled":true}')
        if [ "$(echo "$response" | jq -r '.ok')" != "true" ]; then
            echo "ERROR: Telegram didn't accept the message: $(echo "$response" | jq -r '.description // "no response"')" >&2
            exit 1
        fi
        message_id=$(echo "$response" | jq -r '.result.message_id')
        echo "Posted the release announcement in Telegram (message $message_id)"

        # Pin it, so the latest release shows at the top of the group. The post above was sent silently, and the pin
        # notifies everyone instead - including members who have muted the group - so each member gets one notification.
        response=$(curl -sS --max-time 30 "$api/pinChatMessage" \
            --data-urlencode "chat_id=$TELEGRAM_CHAT_ID" \
            --data-urlencode "message_id=$message_id" \
            --data-urlencode "disable_notification=false")
        if [ "$(echo "$response" | jq -r '.ok')" = "true" ]; then
            echo "Pinned it"
        else
            # The post was sent silently, so without the pin nobody was notified - report it
            echo "ERROR: posted, but couldn't pin it (so members weren't notified): $(echo "$response" | jq -r '.description // "no response"')" >&2
            exit 1
        fi
        ;;

    *)
        sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'
        exit 1
        ;;
esac
