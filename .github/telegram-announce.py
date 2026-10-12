#!/usr/bin/env python3
#
# Name:    telegram-announce.py
# Purpose: Announce a DigiNode Tools release in the DigiNode Tools Telegram group (posted by @diginode_tools_bot,
#          "DigiNode Tools Releases"). Used by the "Release DigiNode Tools" GitHub Action after a release is published.
#
# Usage:
#   .github/telegram-announce.py preview VERSION NOTES_FILE   Print the messages (nothing is sent)
#   .github/telegram-announce.py send VERSION NOTES_FILE      Send them, and pin the first one
#
# The announcement is a short series of messages, in release note order:
#   1. The header and a summary - pinned WITH a notification (so every member, including those who muted the
#      group, gets exactly one notification). All the other messages are sent silently.
#   2. Each note that has a screenshot: the screenshot, with the note as its caption.
#   3. Notes without screenshots are grouped into text messages.
#   4. The last message ends with how to update, the release link and the sponsor line.
# The header and sponsor line rotate (wording in .github/announcements.json, shared with the Bluesky announcement).
# NOTES_FILE is the release notes written by 'release.sh prepare'; screenshots are '![alt](url)' lines under a note.
# Sending needs TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID (GitHub secrets).

import html
import json
import os
import re
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request

RELEASE_URL = "https://github.com/DigiNode-Tools/diginode-tools/releases/tag/v{version}"
SPONSOR_URL = "https://github.com/sponsors/DigiNode-Tools"
LABELS = {"New": "New", "Improvement": "Improvement", "Fix": "Fix"}
EMOJI = {"New": "✨", "Improvement": "🛠️", "Fix": "🐛"}
MAX_TEXT = 4000      # Telegram allows 4096 characters per message
MAX_CAPTION = 1000   # ...and 1024 per photo caption
HERE = os.path.dirname(os.path.abspath(__file__))


def release_count():
    try:
        tags = subprocess.run(["git", "-C", HERE, "tag", "-l", "v*"], capture_output=True, text=True, check=True).stdout
        return len(tags.split())
    except Exception:
        return 0


def read_notes(path):
    """Return [(type, title, text, images)] for each '- Type: text' line in the release notes. A note can start with a
    short bold title ('- New: **Title** - text'), used in the TL;DR; images is [(url, alt)] from '![alt](url)' lines
    under the note."""
    notes = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            m = re.match(r"^- (New|Improvement|Fix): (.+)$", line.strip())
            if m:
                t = re.match(r"^\*\*(.+?)\*\*\s*[-–—]\s*(.+)$", m.group(2))
                title, text = (t.group(1), t.group(2)) if t else (short_title(m.group(2)), m.group(2))
                notes.append((m.group(1), title, text, []))
                continue
            img = re.match(r"^!\[(.*)\]\((https://\S+)\)$", line.strip())
            if img and notes:
                notes[-1][3].append((img.group(2), img.group(1)))
    return notes


def short_title(text):
    """For a note without a title: its first sentence, cut to about 60 characters."""
    first = re.split(r"(?<=[.!?])\s", text, maxsplit=1)[0].rstrip(".")
    return first if len(first) <= 60 else first[:57].rsplit(" ", 1)[0] + "…"


def plural(n, one, many):
    return f"{n} {one if n == 1 else many}"


def build_messages(version, notes_file):
    """Return the messages in order. Each is ("text", html) or ("photos", [(url, caption_html)])."""
    with open(os.path.join(HERE, "announcements.json"), encoding="utf-8") as f:
        wording = json.load(f)
    n = release_count()
    header = wording["headers"][n % len(wording["headers"])]
    sponsor = wording["sponsor_lines"][n % len(wording["sponsor_lines"])]
    notes = read_notes(notes_file)
    if not notes:
        sys.exit(f"ERROR: no release notes found in {notes_file}")

    counts = {t: sum(1 for nt, _, _, _ in notes if nt == t) for t in LABELS}
    parts = []
    if counts["New"]:
        parts.append(plural(counts["New"], "new feature", "new features"))
    if counts["Improvement"]:
        parts.append(plural(counts["Improvement"], "improvement", "improvements"))
    if counts["Fix"]:
        parts.append(plural(counts["Fix"], "fix", "fixes"))
    summary = parts[0] if len(parts) == 1 else ", ".join(parts[:-1]) + " and " + parts[-1]
    summary = summary[0].upper() + summary[1:]

    title = header["text"].replace("{version}", version)
    # The pinned message: a TL;DR of the release - one line per note (its title)
    tldr = "\n".join(f"{EMOJI[t]} {html.escape(nt_title, quote=False)}" for t, nt_title, _, _ in notes)
    messages = [("text", f"{header['emoji']} <b>{html.escape(title, quote=False)}</b>\n\n{tldr}\n\n{summary} - details below 👇")]

    footer = (f"To update, run <code>diginode-setup</code> and choose <b>Update</b>.\n"
              f"<a href=\"{RELEASE_URL.format(version=version)}\">Release notes on GitHub</a>\n\n"
              f"{html.escape(sponsor['text'], quote=False)} <a href=\"{SPONSOR_URL}\">{html.escape(sponsor['link_text'], quote=False)}</a>")

    pending = []   # Notes without screenshots, waiting to be sent together

    def flush():
        while pending:
            text = ""
            while pending and len(text) + len(pending[0]) + 2 <= MAX_TEXT - len(footer) - 2:
                text = f"{text}\n\n{pending.pop(0)}" if text else pending.pop(0)
            if not text:   # A single note too long for a message (very unlikely) - cut it
                text = pending.pop(0)[:MAX_TEXT - len(footer) - 10] + "…"
            messages.append(("text", text))

    for note_type, note_title, text, images in notes:
        note = (f"{EMOJI[note_type]} <b>{LABELS[note_type]}: {html.escape(note_title, quote=False)}</b>\n"
                f"{html.escape(text, quote=False)}")
        if images:
            flush()
            caption = note if len(note) <= MAX_CAPTION else note[:MAX_CAPTION - 1] + "…"
            photos = [(url, caption if i == 0 else "") for i, (url, _alt) in enumerate(images[:10])]
            messages.append(("photos", photos))
        else:
            pending.append(note)
    flush()

    # The footer goes at the end of the last text message, or as its own message
    if messages[-1][0] == "text" and len(messages) > 1 and len(messages[-1][1]) + len(footer) + 2 <= MAX_TEXT:
        messages[-1] = ("text", f"{messages[-1][1]}\n\n{footer}")
    else:
        messages.append(("text", footer))
    return messages


def call(method, params):
    token = os.environ["TELEGRAM_BOT_TOKEN"]
    data = urllib.parse.urlencode(params).encode("utf-8")
    try:
        with urllib.request.urlopen(f"https://api.telegram.org/bot{token}/{method}", data=data, timeout=60) as r:
            result = json.load(r)
    except urllib.error.HTTPError as e:
        try:
            result = json.load(e)
        except Exception:
            result = {"ok": False, "description": f"HTTP {e.code}"}
    if not result.get("ok"):
        sys.exit(f"ERROR: Telegram {method} failed: {result.get('description', 'no response')}")
    return result["result"]


def send(messages):
    if not os.environ.get("TELEGRAM_BOT_TOKEN") or not os.environ.get("TELEGRAM_CHAT_ID"):
        sys.exit("ERROR: TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID must be set")
    chat = os.environ["TELEGRAM_CHAT_ID"]
    common = {"chat_id": chat, "parse_mode": "HTML", "disable_notification": "true"}
    first_id = None

    for number, (kind, content) in enumerate(messages, 1):
        if kind == "text":
            result = call("sendMessage", {**common, "text": content,
                                          "link_preview_options": json.dumps({"is_disabled": True})})
        elif len(content) == 1:
            url, caption = content[0]
            result = call("sendPhoto", {**common, "photo": url, "caption": caption})
        else:
            media = [{"type": "photo", "media": url, **({"caption": c, "parse_mode": "HTML"} if c else {})}
                     for url, c in content]
            result = call("sendMediaGroup", {"chat_id": chat, "disable_notification": "true",
                                             "media": json.dumps(media)})
        print(f"Sent {number}/{len(messages)}")

        if number == 1:
            # Pin the first message WITH a notification - the one notification each member gets
            first_id = result["message_id"]
            call("pinChatMessage", {"chat_id": chat, "message_id": first_id, "disable_notification": "false"})
            print("Pinned it")

    print(f"Posted the release announcement in Telegram ({len(messages)} messages)")

    # Tell the workflow where it is (for the summary sent to the owner). Supergroup IDs are -100<id>; links use <id>.
    if os.environ.get("GITHUB_OUTPUT") and first_id:
        link_id = chat[4:] if chat.startswith("-100") else chat.lstrip("-")
        with open(os.environ["GITHUB_OUTPUT"], "a") as f:
            f.write(f"post_url=https://t.me/c/{link_id}/{first_id}\n")


def main():
    if len(sys.argv) != 4 or sys.argv[1] not in ("preview", "send"):
        print("Usage: telegram-announce.py preview|send VERSION NOTES_FILE")
        sys.exit(1)
    mode, version, notes_file = sys.argv[1:]
    messages = build_messages(version, notes_file)
    if mode == "preview":
        for number, (kind, content) in enumerate(messages, 1):
            if kind == "text":
                print(f"--- Message {number}/{len(messages)}{' (pinned, with a notification)' if number == 1 else ''}"
                      f" ({len(content)} characters)")
                print(content)
            else:
                print(f"--- Message {number}/{len(messages)}: screenshot")
                for url, caption in content:
                    print(f"    [photo: {'/'.join(url.split('/')[-2:])}]")
                    if caption:
                        print(f"    Caption: {caption}")
        return
    send(messages)


if __name__ == "__main__":
    main()
