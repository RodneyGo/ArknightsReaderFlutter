#!/usr/bin/env python3
"""Lint RU story overlays for translation-consistency errors.

Joins every translated line in translations/ru_src/*.json back to its EN source
and flags:
  1. first-person gender-agreement mismatches vs the speaker's canonical sex;
  2. `names` entries that disagree with the canonical glossary (_GLOSSARY.json);
  3. place-name policy violations (keep-Latin names transliterated, or the
     Chernobog -> Чернобог exception not applied);
  4. `{...}` markup tokens that differ between an RU line and its EN source.
See translations/ru_src/_RULES.md and _GLOSSARY.json.

Usage:  python tool/gender_audit.py
Stdlib only. Caches fetched sources under <scriptdir>/.src_cache/.
"""
import json, os, re, glob, sys, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
RU = os.path.join(HERE, "..", "translations", "ru_src")
GLOSSARY = os.path.join(RU, "_GLOSSARY.json")
CACHE = os.path.join(HERE, ".src_cache")
# Story-source mirrors: m31ns first, GitHub fallback (same order the app uses).
MIRRORS = [
    "https://r2.m31ns.top/en_US/gamedata/story/{}.json",
    "https://raw.githubusercontent.com/050644zf/ArknightsStoryJson/main/en_US/gamedata/story/{}.json",
]
UA = "Mozilla/5.0 (gender_audit)"

FEMALE = {"Amiya", "Ch'en", "Kal'tsit", "Hoshiguma", "Texas", "Exusiai", "Franka",
          "Liskarm", "Nearl", "Dobermann", "Misha", "Frostleaf", "Meteorite",
          "Jessica", "FrostNova", "Talulah", "W", "Crownslayer", "Little Girl",
          "Girl's Voice", "Another Girl's Voice",
          # Children of Ursus (act10d5)
          "Leto", "Rosalind", "Beehunter", "Sonya", "Mousse", "Anna", "Lada",
          "Natalya", "Zima", "Istina", "Gummy", "Perfumer", "Absinthe",
          "Instructor Grace", "Woman", "Ursus Woman",
          # Necessary Solutions (main_5)
          "Swire", "Blaze", "Fumizuki",
          # Operational Intelligence (act4d0)
          "Ifrit", "Magallan", "Closure", "Simone", "Vermeil", "Projekt Red",
          "Heavyrain",
          # Partial Necrosis (main_6)
          "GreyThroat", "Lin Yühsia", "Petrova", "Rosmontis",
          "Censor", "Nine"}  # "Madam Censor" — 06-04_beg; Nine (ex-L.G.D.) F
MALE = {"Skullshatterer", "Mephisto", "Faust", "Wei Yenwu", "Ace", "Ursus Captain",
        "Boy's Voice", "Young Man's Voice", "Heavily-Armed Man",
        "Andrey", "Matterhorn", "Valery", "Man",
        # Operational Intelligence (act4d0)
        "Patriot", "Hellagur", "Flamebringer", "Executor", "Scout",
        "Old Huntsman", "Reunion Blademaster",
        # Partial Necrosis (main_6). "Sasha" is Faust's real name (Mephisto
        # calls him that in 06-06_beg; Faust answers "Goodbye, Eno") — MALE,
        # i.e. Александр, not Александра. The name is unisex in Russian and the
        # EN flashback never marks gender, so this is easy to get backwards.
        "Eno", "Sasha", "Elderly Male Voice"}

# Masculine first-person markers (explicit verb/adjective list = low false-positive).
MASC = re.compile(r"\b(понял|готов(?!а)|уверен(?!а)|должен|виноват(?!а)|благодарен|"
                  r"обязан(?!а)|рад(?!а)|ждал|хотел|сказал|думал|решил|пришёл|пришел|"
                  r"вернулся|вспомнил|разглядел|разозлил|закончил|увидел|доверил|"
                  r"просил|потерял|видел(?!а)|свидетелем|полон|напугал(?!а)|испугал(?!а))\b")
FEM = re.compile(r"\b(поняла|готова|уверена|должна|виновата|благодарна|обязана|рада|"
                 r"ждала|хотела|сказала|думала|решила|пришла|вернулась|вспомнила|"
                 r"разглядела|разозлила|закончила|увидела|доверила|просила|потеряла|"
                 r"видела|свидетельницей|полна|напугала|испугала)\b")


def sex(name):
    return "F" if name in FEMALE else "M" if name in MALE else "?"


TOKEN = re.compile(r"\{[^}]*\}")  # {@nickname}, {@ba.xxx}, etc.


def load_glossary():
    try:
        g = json.load(open(GLOSSARY, encoding="utf-8"))
    except Exception as e:
        print(f"  ! could not read _GLOSSARY.json: {e}", file=sys.stderr)
        return {}, [], {}
    return (g.get("names") or {}, g.get("places_keep_latin") or [],
            g.get("places_transliterate") or {})


def source_lines(path):
    """Return {id: {"name": speaker, "text": content}} for the EN source."""
    fn = path.split("/")[-1] + ".json"
    fp = os.path.join(CACHE, fn)
    if not os.path.exists(fp):
        os.makedirs(CACHE, exist_ok=True)
        data = None
        for tpl in MIRRORS:
            try:
                req = urllib.request.Request(tpl.format(path), headers={"User-Agent": UA})
                data = urllib.request.urlopen(req, timeout=30).read()
                break
            except Exception:
                continue
        if data is None:
            print(f"  ! could not fetch source for {path}", file=sys.stderr)
            return None
        open(fp, "wb").write(data)
    o = json.load(open(fp, encoding="utf-8"))
    out = {}
    for l in o.get("storyList", []):
        a = l.get("attributes") or {}
        text = a.get("content") or a.get("text") or a.get("options") or ""
        out[str(l["id"])] = {"name": (a.get("name") or "").strip(),
                             "text": text if isinstance(text, str) else ""}
    return out


def main():
    gnames, keep_latin, transliterate = load_glossary()
    # Cyrillic stems that must NOT appear (keep-Latin places / factions / countries).
    # Extend as new drift is found; Latin is indeclinable so any inflected Cyrillic
    # form (Урсуса, Казимеже, ...) collapses back to the Latin name.
    forbidden_cyr = {
        "Роудс": "Rhodes Island", "Айленд": "Rhodes Island",
        "Урсус": "Ursus", "Казимеж": "Kazimierz", "Лунмен": "Lungmen",
        "Виктори": "Victoria", "Пингвин": "Penguin Logistics",
        "Блэкстил": "Blacksteel", "Рейн": "Rhine Lab",
    }

    gender, gloss, place, token = [], [], [], []
    for jf in sorted(glob.glob(os.path.join(RU, "*.json"))):
        base = os.path.basename(jf)
        if base.startswith("_"):
            continue
        d = json.load(open(jf, encoding="utf-8"))

        # (2) name glossary consistency
        for en, ru in (d.get("names") or {}).items():
            if en in gnames and gnames[en] != ru:
                gloss.append((base, en, ru, gnames[en]))

        src = source_lines(d["path"])
        if src is None:
            continue
        for lid, txt in (d.get("lines") or {}).items():
            sp = src.get(lid, {}).get("name", "")
            g = sex(sp)
            has1p = bool(re.search(r"\b[Яя]\b", txt))
            # (1) gender agreement
            if g == "F" and has1p and MASC.search(txt) and not FEM.search(txt):
                gender.append((base, lid, sp, "needs F", txt))
            elif g == "M" and has1p and FEM.search(txt) and not MASC.search(txt):
                gender.append((base, lid, sp, "needs M", txt))
            # (3) place-name policy
            for stem, correct in forbidden_cyr.items():
                if stem in txt:
                    place.append((base, lid, f"keep Latin '{correct}'", txt))
                    break
            for lat, cyr in transliterate.items():
                if re.search(r"\b" + re.escape(lat) + r"\b", txt):
                    place.append((base, lid, f"use '{cyr}' not '{lat}'", txt))
                    break
            # (4) {...} token preservation vs EN source
            en_txt = src.get(lid, {}).get("text", "")
            if en_txt:
                # case-insensitive: parse.ts replaces both {@nickname}/{@Nickname}
                en_tok = sorted(t.lower() for t in TOKEN.findall(en_txt))
                ru_tok = sorted(t.lower() for t in TOKEN.findall(txt))
                if en_tok != ru_tok:
                    token.append((base, lid, TOKEN.findall(en_txt),
                                  TOKEN.findall(txt)))

    rc = 0
    if gender:
        rc = 1
        print(f"\n[gender] {len(gender)} candidate agreement mismatches "
              "(review — some may be 2nd/3rd-person false positives):")
        for f, lid, sp, need, txt in gender:
            print(f"  [{f} #{lid}] {sp} ({need}): {txt[:90]}")
    if gloss:
        rc = 1
        print(f"\n[glossary] {len(gloss)} name(s) disagree with _GLOSSARY.json:")
        for f, en, ru, want in gloss:
            print(f"  [{f}] {en!r}: {ru!r} should be {want!r}")
    if place:
        rc = 1
        print(f"\n[place] {len(place)} place-name policy violation(s):")
        for f, lid, msg, txt in place:
            print(f"  [{f} #{lid}] {msg}: {txt[:80]}")
    if token:
        rc = 1
        print(f"\n[token] {len(token)} line(s) with mismatched {{...}} markup:")
        for f, lid, en, ru in token:
            print(f"  [{f} #{lid}] EN {en} vs RU {ru}")
    if rc == 0:
        print("OK — no gender, glossary, place-name, or token issues found.")
    return rc


if __name__ == "__main__":
    sys.exit(main())
