# RU translation — Style & method (craft guide)

Companion to `_RULES.md`. `_RULES.md` is the **hard** layer (must / never,
lint-backed: gender, glossary, ты/Вы, typography, tokens, vocatives). This file
is the **soft** layer: how a chapter is actually translated, and what the voice
should sound like. It's calibration, not gospel — "match this voice", never
"use these exact words". Everything below is anchored to real line ids so it can
be re-checked against the corpus.

---

## Prime directive: idiomatic Russian, never a calque

Translate the **meaning + tone** of a line, then rebuild it in natural Russian —
never English syntax dressed in Russian words. The corpus already sets this bar:

- Localize idioms. "stuck between a rock and a hard place" →
  *застревать между молотом и наковальней* (`level_main_01-03_beg #46`), not a
  word-for-word rendering.
- Use Russian rhythm: drop the copula, lean on the em-dash predicate
  (*Отступление — наш главный приоритет!* `level_main_00-04_beg #28`).
- Add the spoken particles Russian needs and English lacks — *ну, вот, же, -то*
  (*Ну же, Гамми, вставай!* `level_act10d5_st01 #26`).

---

## Process — how a chapter is made (context first, not line-by-line)

The information you need for line 5 often first appears at line 300. So never
translate top-to-bottom blind. Five phases:

### 1. Read-through
Read the whole EN script end to end before translating a single line.

### 2. Characterize every speaker (esp. new ones)
Scan **all** of a character's lines and read surface behaviour off concrete
signals, then map each signal to a Russian decision:

| Signal in their lines            | What it tells you        | Russian decision                     |
|----------------------------------|--------------------------|--------------------------------------|
| Sentence length & fragments      | Impulsive vs measured    | Clipped vs periodic syntax           |
| Vocabulary sophistication        | Age / education / status | Simple vs bookish lexicon            |
| Interjections, self-talk         | Childlike / nervous      | Density of *ну, вот, же, -то*        |
| How they address others          | Deference / intimacy     | **ты vs Вы** per relationship        |
| Verbal tics, catchphrases        | Running device           | One fixed Russian handling           |
| Emotional volatility             | Cold / warm / explosive  | Punctuation & interjection energy    |

**Worked example — Gummy**, characterized purely by scanning her lines:
parenthetical self-talk (*Ну же, Гамми, вставай!* `#26`), simple words, treated
like a kid (*опять обращаются со мной как с ребёнком* `#51`), cheerful clipped
lines (*Справлюсь. Намного легче щита.* `#101`). → **childlike-warm register,
ты with friends, high particle density, short sentences.** The voice falls out
of the behaviour scan, not out of any single line.

### 3. Lock the maps before translating
- New names → add to `_GLOSSARY.json` first, so they're consistent from line 1.
- Draw the **ты/Вы grid** for everyone present (who defers to whom, who's close).
- Decide recurring-gag / catchphrase handling once.

### 4. Translate
With all of the above fixed, applying `_RULES.md` + this guide.

### 5. Coherence pass
Re-read the Russian **against itself** (not the English) for voice drift,
calques, and register slips. Then run `python tool/gender_audit.py`.

Cost note: the read-through means reading a big episode twice before shipping a
line. That's deliberate — it's cheaper than discovering at line 300 that a
"formal" character is actually a sardonic teenager and redoing 50 lines.

---

## Register by scene type

Arknights swings between genres; pitch the register to the scene:

| Scene type                        | Register                                   | Anchor                                   |
|-----------------------------------|--------------------------------------------|------------------------------------------|
| **Military / tactical**           | Terse, imperative, nominalized commands    | *Цель — возвышенность на юге. Огонь!* `00-10_beg #62` |
| **Slice-of-life**                 | Warm, casual, spoken; short + interjections| *Хмф! Ну вот, опять…* `act10d5_st01 #51` |
| **Lore / monologue**              | Cold, measured, literary; longer periods   | *Чернобог холодно закрывал глаза на то, как мы умирали…* `03-02_end #127` |
| **Menace / flippancy**            | Mocking, mock-affectionate                 | *мой дорогой кролик из Чернобога?* `04-09_beg #119` |

---

## Character-voice registry (append-only)

One row per recurring speaker: defining trait + a real anchor line. Extend this
as new episodes introduce characters (characterize first — phase 2).

| Character   | Voice                                              | Anchor                         |
|-------------|----------------------------------------------------|--------------------------------|
| Amiya       | Soft, earnest, slightly formal; trusting           | *Ситуация ясна. Я доверяю решениям Доктора…* `01-03_beg #49` |
| Dobermann   | Clipped command Russian; nominal constructions     | *Отступление — наш главный приоритет!* `00-04_beg #28` |
| Kal'tsit    | Cold, precise, no filler; controlled anger         | *Чернобог… заслужил гибель!* `03-02_end #132` |
| Gummy       | Childlike, cheerful, simple; heavy interjections   | *Справлюсь. Намного легче щита.* `act10d5_st01 #101` |
| W           | Sardonic, teasing, mock-affectionate               | *…мой дорогой кролик из Чернобога?* `04-09_beg #119` |
| Doctor ({@nickname}) | Mostly addressed, rarely speaks; stays masculine | (addressed with Вы by operators) |

---

## Pitfalls the lint can't catch (semantic — stay vigilant)

- **Trailing-name vocatives.** English `…, Amiya` at line end is usually direct
  address → comma-set **nominative** (*…, Амия*), never a conjoined accusative
  object (*…и Амию*). Cross-check neighbouring lines. (See `_RULES.md`.)
- **Calqued idioms.** If a phrase reads oddly literal, it's probably an English
  idiom — find the Russian equivalent.
- **English copula structure.** "X is Y" → em-dash predicate (*X — Y*), not
  *X есть Y*.
- **Ambiguous "you".** Resolve ты/Вы from the relationship, and singular/plural
  from who's being addressed — the English hides both.
