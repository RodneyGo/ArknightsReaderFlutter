#!/usr/bin/env python3
"""Purge the published RU translation files from jsDelivr's CDN cache.

REQUIRED after pushing translations. jsDelivr caches `@main` URLs, so a push
alone does NOT publish: the CDN keeps serving the OLD `ru_index.json` for hours.
And because the app treats the index as the switch — `overlayFor()` returns null
for any path the index doesn't list — a stale index makes brand-new chapters
invisible even though their overlay files are already being served fine.

Purging the index is the part that actually matters. Overlays are purged too so a
CORRECTED translation isn't served stale (a new file is never stale; an edited
one is).

Usage:
  python tool/purge_ru_cdn.py            # index + every overlay changed in HEAD
  python tool/purge_ru_cdn.py --all      # index + all overlays (slow)
  python tool/purge_ru_cdn.py --index    # index only

Stdlib only.
"""
import argparse
import json
import os
import subprocess
import sys
import urllib.request

REPO = "RodneyGo/ArknightsReaderFlutter"
BRANCH = "main"
PURGE = f"https://purge.jsdelivr.net/gh/{REPO}@{BRANCH}/"
CDN = f"https://cdn.jsdelivr.net/gh/{REPO}@{BRANCH}/"
ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
INDEX_REL = "translations/ru_index.json"


def purge(rel: str) -> bool:
    try:
        req = urllib.request.Request(PURGE + rel, headers={"User-Agent": "purge_ru_cdn"})
        with urllib.request.urlopen(req, timeout=60) as r:
            return json.loads(r.read()).get("status") in ("finished", "pending")
    except Exception as e:
        print(f"  ! {rel}: {e}", file=sys.stderr)
        return False


def changed_overlays() -> list[str]:
    """Overlay paths touched by the last commit."""
    try:
        out = subprocess.run(
            ["git", "show", "--name-only", "--pretty=format:", "HEAD"],
            cwd=ROOT, capture_output=True, text=True, check=True).stdout
    except Exception:
        return []
    return [l.strip() for l in out.splitlines()
            if l.strip().startswith("translations/ru/") and l.strip().endswith(".json")]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--index", action="store_true")
    args = ap.parse_args()

    targets = [INDEX_REL]
    if args.all:
        base = os.path.join(ROOT, "translations", "ru")
        for d, _, fs in os.walk(base):
            for f in fs:
                if f.endswith(".json"):
                    targets.append(os.path.relpath(os.path.join(d, f), ROOT).replace("\\", "/"))
    elif not args.index:
        targets += changed_overlays()

    print(f"purging {len(targets)} path(s)...")
    ok = sum(purge(t) for t in targets)
    print(f"purged {ok}/{len(targets)}")

    # Verify the index the app will actually receive.
    try:
        req = urllib.request.Request(CDN + INDEX_REL, headers={"User-Agent": "purge_ru_cdn"})
        with urllib.request.urlopen(req, timeout=60) as r:
            live = json.loads(r.read())
        with open(os.path.join(ROOT, INDEX_REL), encoding="utf-8") as f:
            local = json.load(f)
        same = live.get("version") == local.get("version")
        print(f"live index version {live.get('version')} / local {local.get('version')} "
              f"-> {'IN SYNC' if same else 'STILL STALE (retry shortly)'}")
        print(f"live entries: {len(live.get('entries', {}))}")
        return 0 if same and ok == len(targets) else 1
    except Exception as e:
        print(f"  ! could not verify live index: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
