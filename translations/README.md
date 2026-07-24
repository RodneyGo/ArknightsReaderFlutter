# Translations

Russian story overlays. The app loads the EN chapter as the base and overlays a
translation on top, keyed by the chapter's `storyTxt` path; untranslated chapters
fall back to English.

## Layout

| Path | | |
| --- | --- | --- |
| `ru_src/` | **authored** | Edit here. Flat overlays keyed by their internal `path` field, plus `_GLOSSARY.json`, `_RULES.md`, `_STYLE.md`. |
| `ru/` | *generated* | Path-mirrored copy served over jsDelivr. **Wiped and rebuilt on every run — never edit.** |
| `ru_index.json` | *generated* | `{version, entries: {path: sha1}}` — tells the app what's translated and when it changed. |
| `../assets/ru_index.json` | *generated* | Bundled fallback copy shipped in the APK. |

## Updating a translation

1. Edit or add an overlay in `ru_src/`. Every file needs a `path` matching the
   chapter's `storyTxt`; files without one (the glossary) are skipped.
2. Lint it: `python tool/gender_audit.py`
3. Regenerate and publish:

```bash
python tool/gen_ru_repo.py --bump
```

`--bump` increments the index `version`. **Pass it whenever any overlay changed**
— that's what makes already-installed clients revalidate. `refreshIndex()` bails
out on `idx.version == _index.version`, so without a bump clients fetch the new
index, see the same version and *discard it* — the work never reaches anyone.

4. Commit `ru_src/`, `ru/`, `ru_index.json` and `assets/ru_index.json` together
   (or the index hashes won't match the overlays being served) and push to `main`.
5. **Purge the CDN — publishing is not finished without this:**

```bash
python tool/purge_ru_cdn.py
```

## Why the purge step exists

The app fetches from jsDelivr (`cdn.jsdelivr.net/gh/<repo>@main/translations`), so
pushing to `main` is what "publishes" — there is no CI and no app release needed.
But **jsDelivr caches `@main` URLs for hours**, and the two failure modes are
asymmetric:

- a **brand-new overlay** is served immediately (nothing cached to be stale);
- **`ru_index.json` is served from cache**, still listing the old set.

Since the index is the switch — `overlayFor()` returns null for any path the index
doesn't list — a stale index makes the new chapters invisible even though their
files are already downloadable. The push looks successful and nothing appears.
`purge_ru_cdn.py` clears the index plus the overlays changed in HEAD, then
verifies the live index version matches the local one.

## Coverage

An overlay's `names` map applies to the whole chapter but `lines` only where
present, so a partial file renders RU speaker names over English text. Translate
every line of a chapter before shipping it — including `decision` lines, which
carry no speaker name and are the only place the Doctor speaks. See
`ru_src/_RULES.md` for the full rules and `ru_src/_STYLE.md` for voice/register.
