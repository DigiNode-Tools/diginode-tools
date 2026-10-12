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

RELEASE_NOTES_URL = "https://diginode.tools/release-notes/"
SPONSOR_URL = "https://github.com/sponsors/DigiNode-Tools"
MAX_CHARS = 290          # Bluesky allows 300 graphemes per post; counting code points (never fewer) keeps us safely under
PDS = "https://bsky.social/xrpc"
LABELS = {"New": "New", "Improvement": "Improvement", "Fix": "Fix"}
EMOJI = {"New": "✨", "Improvement": "🛠️", "Fix": "🐛"}
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
    """Return the thread as a list of posts. Each post is (text, links, images): links [(link_text, url)], images
    [(url, alt)] (Bluesky allows up to 4 images per post)."""
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

    # The first post: a TL;DR of the release (one line per note) if it fits, otherwise a count of the changes
    title_line = f"{header['emoji']} {header['text'].replace('{version}', version)}"
    tldr = "\n".join(f"{EMOJI[t]} {nt_title}" for t, nt_title, _, _ in notes)
    notes_link = [("See recent release notes", RELEASE_NOTES_URL)]
    first = f"{title_line}\n\n{tldr}\n\nDetails below 🧵 See recent release notes.\n\n{HASHTAGS_LINE}"
    if len(first) <= MAX_CHARS:
        posts = [(first, notes_link, [])]
    else:
        # Too long for one post: the counts first, then the TL;DR as the second post (if that fits)
        first = f"{title_line}\n\n{summary[0].upper() + summary[1:]} 🧵\n\nSee recent release notes.\n\n{HASHTAGS_LINE}"
        posts = [(first, notes_link, [])]
        tldr_post = f"In this release:\n\n{tldr}"
        if len(tldr_post) <= MAX_CHARS:
            posts.append((tldr_post, [], []))

    for note_type, note_title, text, images in notes:
        label = f"{EMOJI[note_type]} {LABELS[note_type]}: {note_title}\n\n"
        first_limit = MAX_CHARS - len(label) - len(INLINE_TAGS)   # Room for the # signs
        chunks = split_text(text, first_limit)
        if len(chunks) > 1:   # Re-split the rest with the full length available
            rest = text[len(chunks[0]):].strip()
            chunks = [chunks[0]] + split_text(rest, MAX_CHARS - len(INLINE_TAGS))
        posts.append((add_inline_tags(f"{label}{chunks[0]}"), [], images[:4]))   # Screenshots go on the note's first post
        for chunk in chunks[1:]:
            posts.append((add_inline_tags(chunk), [], []))

    link_text = sponsor["link_text"]
    posts.append((add_inline_tags(f"To update, run diginode-setup and choose Update.\n\n{sponsor['text']} {link_text}"),
                  [(link_text, SPONSOR_URL)], []))

    # Number the posts: 1/ 2/ 3/ ... (the splitting above leaves room for this)
    posts = [(f"{n}/ {text}", links, images) for n, (text, links, images) in enumerate(posts, 1)]

    for text, _, _ in posts:
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


def png_size(data):
    """Width and height of a PNG (from its header), so Bluesky shows it at the right shape."""
    if data[:8] == b"\x89PNG\r\n\x1a\n":
        return int.from_bytes(data[16:20], "big"), int.from_bytes(data[20:24], "big")
    return None


def upload_image(url, alt, token):
    """Download an image and upload it to Bluesky. Returns the embed entry, or None if it can't be used."""
    try:
        with urllib.request.urlopen(url, timeout=30) as response:
            data = response.read()
            mime = response.headers.get_content_type()
    except Exception as e:
        print(f"WARNING: couldn't download {url} ({e}) - posting without it")
        return None
    if len(data) > 950_000:   # Bluesky's limit is about 1 MB
        print(f"WARNING: {url} is too big for Bluesky ({len(data)} bytes) - posting without it")
        return None
    request = urllib.request.Request(f"{PDS}/com.atproto.repo.uploadBlob", data=data, method="POST",
                                     headers={"Content-Type": mime, "Authorization": f"Bearer {token}"})
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            blob = json.load(response)["blob"]
    except urllib.error.HTTPError as e:
        print(f"WARNING: couldn't upload {url} to Bluesky ({e.code}) - posting without it")
        return None
    entry = {"alt": alt, "image": blob}
    size = png_size(data)
    if size:
        entry["aspectRatio"] = {"width": size[0], "height": size[1]}
    return entry


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
    for number, (text, links, images) in enumerate(posts, 1):
        record = {
            "$type": "app.bsky.feed.post",
            "text": text,
            "langs": ["en"],
            "createdAt": datetime.datetime.now(datetime.timezone.utc).isoformat().replace("+00:00", "Z"),
        }
        facets = link_facets(text, links) + tag_facets(text)
        if facets:
            record["facets"] = facets
        if images:
            embeds = [e for e in (upload_image(url, alt, token) for url, alt in images) if e]
            if embeds:
                record["embed"] = {"$type": "app.bsky.embed.images", "images": embeds}
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
        for number, (text, links, images) in enumerate(posts, 1):
            print(f"--- Post {number}/{len(posts)} ({len(text)} characters)")
            print(text)
            for link_text, url in links:
                print(f"    [link: \"{link_text}\" -> {url}]")
            for url, alt in images:
                print(f"    [image: {url.rsplit('/', 2)[-2]}/{url.rsplit('/', 1)[-1]} - alt: \"{alt[:60]}...\"]")
            tags = [f["features"][0]["tag"] for f in tag_facets(text)]
            if tags:
                print(f"    [hashtags: {', '.join('#' + t for t in tags)}]")
        return
    send(posts)


if __name__ == "__main__":
    main()
