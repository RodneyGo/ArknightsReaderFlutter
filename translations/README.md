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
— that's what makes already-installed clients revalidate. Without it the version
is kept, so edits can go unnoticed by clients that cached the old index.

Commit `ru_src/`, `ru/`, `ru_index.json` and `assets/ru_index.json` together, or
the index hashes won't match the overlays being served.

## Coverage

An overlay's `names` map applies to the whole chapter but `lines` only where
present, so a partial file renders RU speaker names over English text. Translate
every line of a chapter before shipping it — including `decision` lines, which
carry no speaker name and are the only place the Doctor speaks. See
`ru_src/_RULES.md` for the full rules and `ru_src/_STYLE.md` for voice/register.
