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
# The announcement is a short series of messages (Olly 2026-11-17: details live in the blog post on diginode.tools):
#   1. The header, the release's Intro (the 'Intro:' line in docs/release_notes.md) and "Learn more here:" with a link
#      to its blog post - pinned WITH a notification (so every member, including those who muted the group, gets
#      exactly one notification). All the other messages are sent silently. Without an Intro, the notes' titles are
#      listed instead.
#   2. Each note that has a screenshot: the screenshot, captioned with the note's title and the screenshot's short
#      caption ('![alt](url "Caption")'; the note's text if it has none). Notes without screenshots are only in the
#      blog post.
#   3. A last message: how to update, and the sponsor call to action.
# The header rotates (wording in .github/announcements.json); the sponsor text is its "telegram_sponsor".
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

POST_URL = "https://diginode.tools/release/v{version}/"   # finds the release's blog post (diginode.tools)
SPONSOR_URL = "https://diginode.tools/sponsors/"
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
    under the note, with its optional caption: [(url, alt, caption)]."""
    notes = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            m = re.match(r"^- (New|Improvement|Fix): (.+)$", line.strip())
            if m:
                t = re.match(r"^\*\*(.+?)\*\*\s*[-–—]\s*(.+)$", m.group(2))
                title, text = (t.group(1), t.group(2)) if t else (short_title(m.group(2)), m.group(2))
                notes.append((m.group(1), title, text, []))
                continue
            img = re.match(r'^!\[(.*)\]\((https://\S+)(?:\s+"([^"]*)")?\)$', line.strip())   # optional "caption" after the address
            if img and notes:
                notes[-1][3].append((img.group(2), img.group(1), img.group(3) or ""))
    return notes


def short_title(text):
    """For a note without a title: its first sentence, cut to about 60 characters."""
    first = re.split(r"(?<=[.!?])\s", text, maxsplit=1)[0].rstrip(".")
    return first if len(first) <= 60 else first[:57].rsplit(" ", 1)[0] + "…"


def plural(n, one, many):
    return f"{n} {one if n == 1 else many}"


def read_intro(version):
    """The 'Intro:' line under this release's heading in docs/release_notes.md, as plain text ('' if none)."""
    heading = f"### DigiNode Tools v{version} "
    found = False
    try:
        with open(os.path.join(HERE, "..", "docs", "release_notes.md"), encoding="utf-8") as f:
            for line in f:
                if line.startswith(heading):
                    found = True
                elif found and line.startswith("### "):
                    break
                elif found and line.startswith("Intro:"):
                    intro = line[len("Intro:"):].strip()
                    intro = re.sub(r"\*\*(.+?)\*\*", r"\1", intro)
                    return re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", intro)
    except OSError:
        pass
    return ""


def build_messages(version, notes_file):
    """Return the messages in order. Each is ("text", html) or ("photos", [(url, caption_html)])."""
    with open(os.path.join(HERE, "announcements.json"), encoding="utf-8") as f:
        wording = json.load(f)
    header = wording["headers"][release_count() % len(wording["headers"])]
    sponsor = wording["telegram_sponsor"]
    notes = read_notes(notes_file)
    if not notes:
        sys.exit(f"ERROR: no release notes found in {notes_file}")

    title = header["text"].replace("{version}", version)
    intro = read_intro(version)
    if intro:
        body = html.escape(intro, quote=False)
    else:   # no Intro line: list the notes' titles
        body = "\n".join(f"{EMOJI[t]} {html.escape(nt_title, quote=False)}" for t, nt_title, _, _ in notes)
    post_url = POST_URL.format(version=version)
    messages = [("text", f"{header['emoji']} <b>{html.escape(title, quote=False)}</b>\n\n{body}\n\n"
                         f"Learn more here: <a href=\"{post_url}\">{post_url}</a>")]

    for note_type, note_title, text, images in notes:
        if not images:
            continue
        heading = f"{EMOJI[note_type]} <b>{LABELS[note_type]}: {html.escape(note_title, quote=False)}</b>"
        photos = []
        for i, (url, _alt, caption) in enumerate(images[:10]):
            if i == 0:
                c = f"{heading}\n{html.escape(caption or text, quote=False)}"
                photos.append((url, c if len(c) <= MAX_CAPTION else c[:MAX_CAPTION - 1] + "…"))
            else:
                photos.append((url, ""))
        messages.append(("photos", photos))

    messages.append(("text", f"To update, run <code>diginode-setup</code> and choose <b>Update</b>.\n\n"
                             f"{html.escape(sponsor['text'], quote=False)} "
                             f"<a href=\"{SPONSOR_URL}\">{html.escape(sponsor['link_text'], quote=False)}</a>"))
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
