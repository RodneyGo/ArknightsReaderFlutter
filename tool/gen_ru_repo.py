#!/usr/bin/env python3
"""Generate the Russian-translation repo layout + index from the legacy flat folder.

The web app kept overlays as flat files (`level_act10d5_st01.json`) keyed by an
internal `path` field. For on-demand fetching we mirror that path into a folder
tree so the URL derives directly from the chapter's storyTxt, and we emit an
index (with a per-overlay hash) so the app knows what's translated and when a
translation changed.

Outputs (relative to the Flutter project root):
  translations/ru/<path>.json    the overlays, path-mirrored (jsDelivr-served)
  translations/ru_index.json     {version, entries: {path: sha1}} (jsDelivr-served)
  assets/ru_index.json           bundled fallback copy (shipped in the APK)

Usage:
  python tool/gen_ru_repo.py [--src <legacy ru dir>] [--bump]

--bump increments the index `version` (do this whenever any overlay changes so
clients revalidate). Without it, version is kept from the existing index, or 1.
"""

import argparse
import hashlib
import json
import os
import shutil

# Legacy source: the original web app's ru folder.
DEFAULT_SRC = os.path.join(
    os.path.dirname(__file__),
    "..", "..",
    "BetterPhoneReader", "src", "data", "ru",
)

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
OUT_TREE = os.path.join(ROOT, "translations", "ru")
OUT_INDEX = os.path.join(ROOT, "translations", "ru_index.json")
BUNDLED_INDEX = os.path.join(ROOT, "assets", "ru_index.json")


def canonical(obj) -> str:
    """Stable JSON text (sorted keys) so the hash only changes on real edits."""
    return json.dumps(obj, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default=DEFAULT_SRC)
    ap.add_argument("--bump", action="store_true")
    args = ap.parse_args()

    src = os.path.normpath(args.src)
    if not os.path.isdir(src):
        raise SystemExit(f"source ru dir not found: {src}")

    # Reset the output tree so deleted translations don't linger.
    if os.path.isdir(OUT_TREE):
        shutil.rmtree(OUT_TREE)
    os.makedirs(OUT_TREE, exist_ok=True)

    entries: dict[str, str] = {}
    written = 0
    skipped = 0
    for name in sorted(os.listdir(src)):
        if not name.endswith(".json"):
            continue
        with open(os.path.join(src, name), encoding="utf-8") as f:
            data = json.load(f)
        path = data.get("path")
        if not isinstance(path, str) or not path:
            skipped += 1  # _GLOSSARY.json and friends carry no path
            continue

        text = canonical(data)
        entries[path] = hashlib.sha1(text.encode("utf-8")).hexdigest()

        dest = os.path.join(OUT_TREE, *path.split("/")) + ".json"
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        with open(dest, "w", encoding="utf-8") as f:
            f.write(text)
        written += 1

    # Version: bump on request, else keep the previous, else start at 1.
    prev_version = 0
    if os.path.exists(OUT_INDEX):
        try:
            with open(OUT_INDEX, encoding="utf-8") as f:
                prev_version = int(json.load(f).get("version", 0))
        except Exception:
            prev_version = 0
    version = prev_version + 1 if (args.bump or prev_version == 0) else prev_version

    index = {"version": version, "entries": entries}
    index_text = canonical(index)

    os.makedirs(os.path.dirname(OUT_INDEX), exist_ok=True)
    with open(OUT_INDEX, "w", encoding="utf-8") as f:
        f.write(index_text)
    os.makedirs(os.path.dirname(BUNDLED_INDEX), exist_ok=True)
    with open(BUNDLED_INDEX, "w", encoding="utf-8") as f:
        f.write(index_text)

    print(f"overlays written: {written}  (skipped {skipped} non-overlay files)")
    print(f"index version: {version}  entries: {len(entries)}")
    print(f"  {OUT_INDEX}")
    print(f"  {BUNDLED_INDEX}")


if __name__ == "__main__":
    main()
