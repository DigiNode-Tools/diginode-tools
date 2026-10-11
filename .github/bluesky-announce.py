#!/usr/bin/env python3
#
# Name:    bluesky-announce.py
# Purpose: Announce a DigiNode Tools release on Bluesky as a thread (from the DigiNode Tools account). Used by the
#          "Release DigiNode Tools" GitHub Action after a release is published.
#
# Usage:
#   .github/bluesky-announce.py preview VERSION NOTES_FILE   Print the thread (nothing is posted)
#   .github/bluesky-announce.py send VERSION NOTES_FILE      Post the thread
#
# The thread: a first post with the header and a summary, one reply per release note (a long note continues in the
# next reply, split between sentences - Bluesky allows 300 characters per post), and a last reply with how to update
# and the sponsor line. The header and sponsor line rotate (wording in .github/announcements.json, shared with the
# Telegram announcement). NOTES_FILE is the release notes written by 'release.sh prepare'.
# Posting needs BLUESKY_HANDLE and BLUESKY_APP_PASSWORD (an app password, not the account password).

import datetime
import json
import os
import re
import subprocess
import sys
import urllib.error
import urllib.request

RELEASE_URL = "https://github.com/DigiNode-Tools/diginode-tools/releases/tag/v{version}"
SPONSOR_URL = "https://github.com/sponsors/DigiNode-Tools"
MAX_CHARS = 290          # Bluesky allows 300 graphemes per post; counting code points (never fewer) keeps us safely under
PDS = "https://bsky.social/xrpc"
LABELS = {"New": "✨ New:", "Improvement": "🛠️ Improvement:", "Fix": "🐛 Fix:"}
HASHTAGS_LINE = "#DigiByte #DGB #DigiNode"   # Added to the first post
INLINE_TAGS = ["DigiNode", "DigiByte"]      # The first mention of each in a post becomes a hashtag
HERE = os.path.dirname(os.path.abspath(__file__))


def release_count():
    try:
        tags = subprocess.run(["git", "-C", HERE, "tag", "-l", "v*"], capture_output=True, text=True, check=True).stdout
        return len(tags.split())
    except Exception:
        return 0


def read_notes(path):
    """Return [(type, text)] for each '- Type: text' line in the release notes."""
    notes = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            m = re.match(r"^- (New|Improvement|Fix): (.+)$", line.strip())
            if m:
                notes.append((m.group(1), m.group(2)))
    return notes


def plural(n, one, many):
    return f"{n} {one if n == 1 else many}"


def split_text(text, limit):
    """Split text into chunks of at most limit characters, between sentences where possible, never mid-word."""
    chunks = []
    sentences = re.split(r"(?<=[.!?])\s+", text)
    current = ""
    for sentence in sentences:
        candidate = f"{current} {sentence}".strip()
        if len(candidate) <= limit:
            current = candidate
            continue
        if current:
            chunks.append(current)
        # A single sentence longer than the limit: split it between words
        while len(sentence) > limit:
            cut = sentence.rfind(" ", 0, limit)
            cut = cut if cut > 0 else limit
            chunks.append(sentence[:cut])
            sentence = sentence[cut:].strip()
        current = sentence
    if current:
        chunks.append(current)
    return chunks


def build_thread(version, notes_file):
    """Return the thread as a list of posts. Each post is (text, links), links being [(link_text, url)]."""
    with open(os.path.join(HERE, "announcements.json"), encoding="utf-8") as f:
        wording = json.load(f)
    n = release_count()
    header = wording["headers"][n % len(wording["headers"])]
    sponsor = wording["sponsor_lines"][n % len(wording["sponsor_lines"])]
    notes = read_notes(notes_file)
    if not notes:
        sys.exit(f"ERROR: no release notes found in {notes_file}")

    counts = {t: sum(1 for nt, _ in notes if nt == t) for t in LABELS}
    parts = []
    if counts["New"]:
        parts.append(plural(counts["New"], "new feature", "new features"))
    if counts["Improvement"]:
        parts.append(plural(counts["Improvement"], "improvement", "improvements"))
    if counts["Fix"]:
        parts.append(plural(counts["Fix"], "fix", "fixes"))
    summary = parts[0] if len(parts) == 1 else ", ".join(parts[:-1]) + " and " + parts[-1]

    release_url = RELEASE_URL.format(version=version)
    posts = [(f"{header['emoji']} {header['text'].replace('{version}', version)}\n\n"
              f"{summary[0].upper() + summary[1:]} 🧵\n\nRelease notes\n\n{HASHTAGS_LINE}", [("Release notes", release_url)])]

    for note_type, text in notes:
        label = LABELS[note_type]
        chunks = split_text(text, MAX_CHARS - len(label) - 1 - len(INLINE_TAGS))   # Room for the # signs
        posts.append((add_inline_tags(f"{label} {chunks[0]}"), []))
        for chunk in chunks[1:]:
            posts.append((add_inline_tags(chunk), []))

    link_text = sponsor["link_text"]
    posts.append((add_inline_tags(f"To update, run diginode-setup and choose Update.\n\n{sponsor['text']} {link_text}"),
                  [(link_text, SPONSOR_URL)]))

    for text, _ in posts:
        if len(text) > 300:
            sys.exit(f"ERROR: a post is too long ({len(text)} characters): {text[:60]}...")
    return posts


def add_inline_tags(text):
    """Turn the first mention of each INLINE_TAGS word in a post into a hashtag (e.g. DigiNode Setup -> #DigiNode Setup)."""
    for word in INLINE_TAGS:
        if re.search(rf"(?<![\w#]){word}\b", text) and f"#{word}" not in text:
            text = re.sub(rf"(?<![\w#]){word}\b", f"#{word}", text, count=1)
    return text


def tag_facets(text):
    """Bluesky marks hashtags separately, by their position in the text in UTF-8 bytes."""
    facets = []
    for m in re.finditer(r"(?<![\w#])#(DigiNode|DigiByte|DGB)\b", text):
        start = len(text[:m.start()].encode("utf-8"))
        end = len(text[:m.end()].encode("utf-8"))
        facets.append({
            "index": {"byteStart": start, "byteEnd": end},
            "features": [{"$type": "app.bsky.richtext.facet#tag", "tag": m.group(1)}],
        })
    return facets


def link_facets(text, links):
    """Bluesky marks links separately, by their position in the text in UTF-8 bytes."""
    facets = []
    encoded = text.encode("utf-8")
    for link_text, url in links:
        start = encoded.rfind(link_text.encode("utf-8"))
        if start < 0:
            continue
        facets.append({
            "index": {"byteStart": start, "byteEnd": start + len(link_text.encode("utf-8"))},
            "features": [{"$type": "app.bsky.richtext.facet#link", "uri": url}],
        })
    return facets


def api(method, body, token=None):
    request = urllib.request.Request(f"{PDS}/{method}", data=json.dumps(body).encode("utf-8"), method="POST",
                                     headers={"Content-Type": "application/json"})
    if token:
        request.add_header("Authorization", f"Bearer {token}")
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.load(response)
    except urllib.error.HTTPError as e:
        sys.exit(f"ERROR: Bluesky {method} failed: {e.code} {e.read().decode('utf-8', 'replace')[:300]}")


def send(posts):
    handle = os.environ.get("BLUESKY_HANDLE")
    password = os.environ.get("BLUESKY_APP_PASSWORD")
    if not handle or not password:
        sys.exit("ERROR: BLUESKY_HANDLE and BLUESKY_APP_PASSWORD must be set")

    session = api("com.atproto.server.createSession", {"identifier": handle, "password": password})
    token, did = session["accessJwt"], session["did"]

    root = parent = None
    for number, (text, links) in enumerate(posts, 1):
        record = {
            "$type": "app.bsky.feed.post",
            "text": text,
            "langs": ["en"],
            "createdAt": datetime.datetime.now(datetime.timezone.utc).isoformat().replace("+00:00", "Z"),
        }
        facets = link_facets(text, links) + tag_facets(text)
        if facets:
            record["facets"] = facets
        if parent:
            record["reply"] = {"root": root, "parent": parent}
        result = api("com.atproto.repo.createRecord",
                     {"repo": did, "collection": "app.bsky.feed.post", "record": record}, token)
        parent = {"uri": result["uri"], "cid": result["cid"]}
        root = root or parent
        print(f"Posted {number}/{len(posts)}")

    post_id = root["uri"].rsplit("/", 1)[-1]
    print(f"Posted the release thread on Bluesky: https://bsky.app/profile/{handle}/post/{post_id}")


def main():
    if len(sys.argv) != 4 or sys.argv[1] not in ("preview", "send"):
        print(__doc__ or "Usage: bluesky-announce.py preview|send VERSION NOTES_FILE")
        sys.exit(1)
    mode, version, notes_file = sys.argv[1:]
    posts = build_thread(version, notes_file)
    if mode == "preview":
        for number, (text, links) in enumerate(posts, 1):
            print(f"--- Post {number}/{len(posts)} ({len(text)} characters)")
            print(text)
            for link_text, url in links:
                print(f"    [link: \"{link_text}\" -> {url}]")
            tags = [f["features"][0]["tag"] for f in tag_facets(text)]
            if tags:
                print(f"    [hashtags: {', '.join('#' + t for t in tags)}]")
        return
    send(posts)


if __name__ == "__main__":
    main()
