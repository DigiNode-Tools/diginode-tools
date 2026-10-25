#!/usr/bin/env python3
#
# Name:    release-summary.py
# Purpose: After a release, send the owner (Olly) a private Telegram message from the DigiNode Tools Releases bot:
#          what was published (with links, and whether each announcement worked), then a ready-made Reddit post for
#          r/Digibyte (title and body to copy, and a link to Reddit's post page with the title filled in), then a
#          ready-made Ko-fi post (title and text to copy, and the release's screenshots as an album to save and attach).
#          Used by the "Release DigiNode Tools" GitHub Action. Posting to Reddit and Ko-fi is left to the owner: Reddit
#          on purpose, and Ko-fi has no way for a program to post.
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
KOFI_NEW_POST_URL = "https://ko-fi.com/blog/editor?back=true"
EMOJI = {"New": "✨", "Improvement": "🛠️", "Fix": "🐛"}   # As in the Bluesky TL;DR
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


SPONSORS_DATA_URL = "https://raw.githubusercontent.com/DigiNode-Tools/diginode-sponsors/main/"
FEATURES_URL = "https://diginode.tools/features/"
RPI_GUIDE_URL = "https://diginode.tools/raspberry-pi-setup/"
REDDIT_PLANS = 4   # How many of sponsor-info.json's plans the Reddit post lists


def sponsors_data(name):
    """A JSON file from diginode-sponsors (sponsor-info.json, dgb-donate.json, featured.json), or {} if unavailable."""
    try:
        with urllib.request.urlopen(SPONSORS_DATA_URL + name, timeout=20) as r:
            return json.load(r)
    except Exception as e:   # The post still works without it - just with less detail
        print(f"Note: couldn't read {name} from diginode-sponsors ({e})", file=sys.stderr)
        return {}


def reddit_post(version, notes):
    """The title and markdown body of a Reddit post about the release.

    Written for r/Digibyte readers who may not know DigiNode Tools: what it is first, then what's new, then a clear
    ask to support it - with the pitch, plans, tiers and links from diginode-sponsors' sponsor-info.json (the same
    text as the Sponsors page), and the current DGB address from dgb-donate.json."""
    titles = [t for _, t, _, _ in notes if t]
    title = f"DigiNode Tools v{version} released"
    if titles:
        listed = ", ".join(titles[:3]) + (" and more" if len(titles) > 3 else "")
        title += f": {listed}"
    title = title[:297] + "..." if len(title) > 300 else title   # Reddit allows 300 characters

    info = sponsors_data("sponsor-info.json")
    links = info.get("links", {})
    page = links.get("page", SPONSOR_URL)

    lines = [f"I've just released **DigiNode Tools v{version}**.", "",
             "**New to DigiNode Tools?** It's a free set of tools that makes it easy to run your own DigiByte full "
             "node - on a Raspberry Pi, or any Ubuntu or Debian server at home or in the cloud. **DigiNode Setup** "
             "installs and configures everything through simple menus, so no Linux experience is needed, and "
             "**DigiNode Dashboard** shows how your node is doing at a glance. Every node helps keep the DigiByte "
             f"network decentralised and secure. See everything it can do: {FEATURES_URL}", "",
             "It's free, its code is public, and I build it in my spare time - so it depends on sponsors and "
             "donations. If you'd like to see it keep improving, please consider supporting it (details below 💙).",
             "", f"**What's new in v{version}**", ""]
    for note_type, note_title, text, images in notes:
        heading = f"**{note_type}: {note_title}** - " if note_title else f"**{note_type}:** "
        lines.append(f"- {heading}{text}")
        for url, _alt in images:
            lines.append(f"  ([screenshot]({url}))")
    lines += ["", "**Already running a DigiNode?** Run `diginode-setup` and choose Update.", "",
              f"**Want to run one?** Follow the step-by-step Raspberry Pi guide: {RPI_GUIDE_URL} - or on Ubuntu or "
              "Debian, run `curl -sSL setup.diginode.tools | bash`", "",
              f"Full release notes: {RELEASE_NOTES_URL}", "", "---", "", "**💙 Please support DigiNode Tools**", ""]
    if info.get("pitch"):
        lines += [info["pitch"], ""]
    # The first few plans (the rest, and what support pays for, are on the Sponsors page - keeps the post short)
    plans = info.get("plans", [])[:REDDIT_PLANS]
    if plans:
        lines += ["Sponsorship brings these closer - some of the things I'd like to build next:", ""]
        lines += [f"- {p}" for p in plans] + [f"- ...and more: {page}", ""]

    tiers = {t.get("name"): t for t in info.get("tiers", [])}
    monthly = [t["monthly"] for t in info.get("tiers", []) if t.get("monthly") and t.get("name") != "Featured Sponsor"]
    ways = ["**Ways to support:**", ""]
    ways.append(f"- **Sponsor monthly on GitHub**" + (f" (from ${min(monthly)}/month)" if monthly else "")
                + f": {links.get('github', 'https://github.com/sponsors/DigiNode-Tools')}")
    ways.append(f"- **Donate once, or monthly, on Ko-fi** (card or PayPal): {links.get('kofi', 'https://ko-fi.com/diginode')}")
    address = sponsors_data("dgb-donate.json").get("address", "")
    if re.fullmatch(r"dgb1[02-9ac-hj-np-z]{20,90}", address or ""):
        ways.append(f"- **Send DGB** to the DigiNode Tools donation address: `{address}`")
    featured = tiers.get("Featured Sponsor")
    places = info.get("featured_places", 0)
    if featured and places:
        taken = len(sponsors_data("featured.json").get("featured", []))
        free = max(0, places - taken)
        if free:
            # Same promise as the Featured Sponsor tier's perk in sponsor-info.json
            ways.append(f"- **For businesses and projects:** become a Featured Sponsor (${featured.get('monthly')}/month) "
                        "and put your brand in front of DigiByte node runners: your logo and link on the diginode.tools "
                        "home page and sponsors page, and on the DigiNode Tools GitHub page, plus your name and link "
                        "shown to everyone using DigiNode Setup and DigiNode Dashboard. "
                        f"{free} of {places} places {'is' if free == 1 else 'are'} free.")
    lines += ways + ["", f"Everything about sponsoring, and where your support goes: {page}", "",
                     "Thank you! - Olly (I'm the developer of DigiNode Tools)"]
    return title, "\n".join(lines)


def kofi_post(version, notes):
    """The title and plain-text body of a Ko-fi post about the release, for the people who support DigiNode Tools."""
    title = f"DigiNode Tools v{version} is out"
    lines = ["Thank you for supporting DigiNode Tools! Here's what your support has helped make happen in this release.",
             "", "TL;DR"]
    lines += [f"{EMOJI.get(t, '•')} {nt or text[:80]}" for t, nt, text, _ in notes]
    lines += ["", "What's new", ""]
    for note_type, note_title, text, _images in notes:
        lines += [f"{note_type}: {note_title}" if note_title else f"{note_type}:", text, ""]
    lines += ["To update, run diginode-setup and choose Update.", "",
              f"Release notes, with screenshots: {RELEASE_NOTES_URL}", "",
              "Thank you!", "Olly"]
    return title, "\n".join(lines)


def chunked_pre(text):
    """The text as tap-to-copy code blocks (Telegram HTML), split if it's too long for one message."""
    messages, chunk = [], ""
    for para in html.escape(text, quote=False).split("\n"):
        if len(chunk) + len(para) + 20 > MAX_TEXT:
            messages.append(f"<pre>{chunk}</pre>")
            chunk = ""
        chunk = f"{chunk}\n{para}" if chunk else para
    messages.append(f"<pre>{chunk}</pre>")
    return messages


def build_messages(version, notes_file):
    """Return the messages to send the owner: Telegram HTML strings, or ("album", [(image_url, caption)])."""
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

    # The body, ready to copy (a code block is tap-to-copy in Telegram)
    messages = ["\n".join(summary), reddit_intro] + chunked_pre(body)

    k_title, k_body = kofi_post(version, notes)
    images = [(url, alt) for _, _, _, imgs in notes for url, alt in imgs][:10]   # Telegram albums hold up to 10
    kofi_intro = ("☕ <b>Post it on Ko-fi?</b> (your supporters see it in their feed)\n\n"
                  "1. Tap the title and the text below to copy them.\n"
                  f"2. <a href=\"{html.escape(KOFI_NEW_POST_URL)}\">Open a new Ko-fi post</a>, paste them, "
                  + ("and attach the screenshots from the album below (save them first).\n\n" if images else
                     "and post.\n\n")
                  + f"<b>Title:</b>\n<code>{html.escape(k_title, quote=False)}</code>")
    messages += [kofi_intro] + chunked_pre(k_body)
    if images:
        messages.append(("album", images))
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
            if isinstance(m, tuple):
                print(f"--- Private message {n}/{len(messages)} (album of {len(m[1])} screenshots)")
                print("\n".join(f"{url}  ({alt})" for url, alt in m[1]))
            else:
                print(f"--- Private message {n}/{len(messages)} ({len(m)} characters)")
                print(m)
        return
    if not os.environ.get("TELEGRAM_BOT_TOKEN") or not os.environ.get("TELEGRAM_OWNER_CHAT_ID"):
        print("The owner's Telegram ID (TELEGRAM_OWNER_CHAT_ID) isn't set - skipping the private summary")
        return
    for m in messages:
        if isinstance(m, tuple):
            if len(m[1]) == 1:   # An album needs at least 2
                url, alt = m[1][0]
                call("sendPhoto", {"chat_id": os.environ["TELEGRAM_OWNER_CHAT_ID"], "photo": url, "caption": alt[:1024]})
            else:
                media = [{"type": "photo", "media": url, "caption": alt[:1024]} for url, alt in m[1]]
                call("sendMediaGroup", {"chat_id": os.environ["TELEGRAM_OWNER_CHAT_ID"], "media": json.dumps(media)})
            continue
        call("sendMessage", {"chat_id": os.environ["TELEGRAM_OWNER_CHAT_ID"], "text": m, "parse_mode": "HTML",
                             "link_preview_options": json.dumps({"is_disabled": True})})
    print(f"Sent the release summary to the owner ({len(messages)} messages)")


if __name__ == "__main__":
    main()
