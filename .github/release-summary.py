#!/usr/bin/env python3
#
# Name:    release-summary.py
# Purpose: After a release, send the owner (Olly) a private Telegram message from the DigiNode Tools Releases bot:
#          what was published (with links, and whether each announcement worked), then a ready-made Reddit post for
#          r/Digibyte (title and body to copy, and a link to Reddit's post page with the title filled in).
#          Used by the "Release DigiNode Tools" GitHub Action. Posting to Reddit is left to the owner on purpose.
#
# Usage:
#   .github/release-summary.py preview VERSION NOTES_FILE   Print the messages (nothing is sent)
#   .github/release-summary.py send VERSION NOTES_FILE      Send them
#
# Sending needs TELEGRAM_BOT_TOKEN and TELEGRAM_OWNER_CHAT_ID (the owner's Telegram user ID). The workflow also passes
# what happened: GITHUB_RELEASE_URL, TELEGRAM_POST_URL / TELEGRAM_OUTCOME and BLUESKY_POST_URL / BLUESKY_OUTCOME.

import html
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request

SUBREDDIT = "Digibyte"
RELEASE_NOTES_URL = "https://diginode.tools/release-notes/"
SPONSOR_URL = "https://diginode.tools/sponsors/"
MAX_TEXT = 4000   # Telegram allows 4096 characters per message


def read_notes(path):
    """Return [(type, title, text, images)] for each '- Type: text' line (same format as the announcement scripts)."""
    notes = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            m = re.match(r"^- (New|Improvement|Fix): (.+)$", line.strip())
            if m:
                t = re.match(r"^\*\*(.+?)\*\*\s*[-–—]\s*(.+)$", m.group(2))
                title, text = (t.group(1), t.group(2)) if t else (None, m.group(2))
                notes.append((m.group(1), title, text, []))
                continue
            img = re.match(r"^!\[(.*)\]\((https://\S+)\)$", line.strip())
            if img and notes:
                notes[-1][3].append((img.group(2), img.group(1)))
    return notes


def reddit_post(version, notes):
    """The title and markdown body of a Reddit post about the release."""
    titles = [t for _, t, _, _ in notes if t]
    title = f"DigiNode Tools v{version} released"
    if titles:
        listed = ", ".join(titles[:3]) + (" and more" if len(titles) > 3 else "")
        title += f": {listed}"
    title = title[:297] + "..." if len(title) > 300 else title   # Reddit allows 300 characters

    lines = [f"I've just released DigiNode Tools v{version}. DigiNode Tools makes it easy to run your own DigiByte "
             f"node on a Raspberry Pi or Linux server.", "", "**What's new**", ""]
    for note_type, note_title, text, images in notes:
        heading = f"**{note_type}: {note_title}** - " if note_title else f"**{note_type}:** "
        lines.append(f"- {heading}{text}")
        for url, _alt in images:
            lines.append(f"  ([screenshot]({url}))")
    lines += ["", "**To update:** run `diginode-setup` and choose Update.", "",
              f"Release notes: {RELEASE_NOTES_URL}", "",
              f"*(I'm the developer of DigiNode Tools. It's free - if you find it useful, you can "
              f"support it at {SPONSOR_URL})*"]
    return title, "\n".join(lines)


def build_messages(version, notes_file):
    """Return the messages to send the owner (Telegram HTML)."""
    notes = read_notes(notes_file)
    if not notes:
        sys.exit(f"ERROR: no release notes found in {notes_file}")

    def status(name, outcome, url):
        if outcome == "success" and url:
            return f"✅ {name}: <a href=\"{html.escape(url)}\">view</a>"
        if outcome in ("success", "skipped") or not outcome:
            return f"➖ {name}: not posted (not set up)"
        return f"❌ {name}: failed - see the GitHub issue"

    gh_url = os.environ.get("GITHUB_RELEASE_URL", "")
    summary = [f"📦 <b>DigiNode Tools v{version} was released</b>", "",
               f"✅ GitHub release: <a href=\"{html.escape(gh_url)}\">view</a>" if gh_url else "✅ GitHub release",
               status("Telegram group", os.environ.get("TELEGRAM_OUTCOME", ""), os.environ.get("TELEGRAM_POST_URL", "")),
               status("Bluesky thread", os.environ.get("BLUESKY_OUTCOME", ""), os.environ.get("BLUESKY_POST_URL", "")),
               "", "<b>What was published:</b>"]
    summary += [f"• {html.escape(t or text[:60], quote=False)}" for _, t, text, _ in notes]

    title, body = reddit_post(version, notes)
    submit_url = (f"https://old.reddit.com/r/{SUBREDDIT}/submit?selftext=true&title="
                  + urllib.parse.quote(title))
    reddit_intro = ("🟠 <b>Post it on Reddit?</b> (only if this release is worth it)\n\n"
                    "1. Tap the title and the body below to copy them.\n"
                    f"2. <a href=\"{html.escape(submit_url)}\">Open the r/{SUBREDDIT} post page</a> "
                    "(the title is filled in), paste the body, and post.\n\n"
                    f"<b>Title:</b>\n<code>{html.escape(title, quote=False)}</code>")

    messages = ["\n".join(summary), reddit_intro]
    # The body, ready to copy (a code block is tap-to-copy in Telegram). Split if it's too long for one message.
    escaped = html.escape(body, quote=False)
    chunk = ""
    for para in escaped.split("\n"):
        if len(chunk) + len(para) + 20 > MAX_TEXT:
            messages.append(f"<pre>{chunk}</pre>")
            chunk = ""
        chunk = f"{chunk}\n{para}" if chunk else para
    messages.append(f"<pre>{chunk}</pre>")
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


def main():
    if len(sys.argv) != 4 or sys.argv[1] not in ("preview", "send"):
        print("Usage: release-summary.py preview|send VERSION NOTES_FILE")
        sys.exit(1)
    mode, version, notes_file = sys.argv[1:]
    messages = build_messages(version, notes_file)
    if mode == "preview":
        for n, m in enumerate(messages, 1):
            print(f"--- Private message {n}/{len(messages)} ({len(m)} characters)")
            print(m)
        return
    if not os.environ.get("TELEGRAM_BOT_TOKEN") or not os.environ.get("TELEGRAM_OWNER_CHAT_ID"):
        print("The owner's Telegram ID (TELEGRAM_OWNER_CHAT_ID) isn't set - skipping the private summary")
        return
    for m in messages:
        call("sendMessage", {"chat_id": os.environ["TELEGRAM_OWNER_CHAT_ID"], "text": m, "parse_mode": "HTML",
                             "link_preview_options": json.dumps({"is_disabled": True})})
    print(f"Sent the release summary to the owner ({len(messages)} messages)")


if __name__ == "__main__":
    main()
