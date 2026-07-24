# RU translation — Rules refference 

> This is the **hard** layer — must/never, mostly lint-backed. For voice, register,
> and the translation *method* (read-through, characterizing new speakers), see
> the companion **`_STYLE.md`** (soft/craft layer).

Russian past-tense verbs and short adjectives agree with the speaker's sex
(«я понял/поняла», «готов/готова», «уверен/уверена», «пришёл/пришла»). English
is genderless, so when translating you MUST know the speaker's (and any
referenced character's) sex and match the agreement.

## Policy
- **Doctor ({@nickname}) = MASCULINE.** The player picks the Doctor's sex, but
  this translation defaults the Doctor to male everywhere (self-reference and
  lines addressed to the Doctor stay masculine: «Ты не смог…», «ты обязан…»).
- For a **named** character, use the canonical sex below.
- For **generic NPCs** (Reunion Member, Guard, Medic, L.G.D. Agent, Civilian,
  Rioter, Operators…) gender is context-dependent — read the scene. The source
  sometimes encodes it (Male/Female, Boy's/Girl's Voice, Heavily-Armed Man,
  Ursus Captain = M).
- For organisations/countries/cities don't translate and leave the original name.

## Canonical sex of speaking characters
**Female:** Amiya, Ch'en, Kal'tsit, Hoshiguma, Texas, Exusiai, Franka, Liskarm,
Nearl, Dobermann, Misha, Frostleaf, Meteorite, Jessica, FrostNova, Talulah, W,
Crownslayer, Little Girl, Girl's Voice, Another Girl's Voice.

**Male:** Skullshatterer, Mephisto, Faust, Wei Yenwu, Ace, Ursus Captain,
Boy's Voice, Young Man's Voice, Heavily-Armed Man.

## Names & terminology — canonical glossary
`_GLOSSARY.json` is the single source of truth. `gender_audit.py` reads it and
flags any `ru/*.json` that disagrees, so **never invent a new spelling ad-hoc**:
- **`names`** — every EN speaker maps to exactly one RU form. Add new characters
  here first, then use them. (This is why `Ребёнок` must not also appear as
  `Ребенok` — same speaker, one form.)
- **`places_keep_latin`** — place / faction / company / country proper nouns stay
  in **Latin** inside Russian prose: `Rhodes Island`, `Reunion`, `Ursus`,
  `Lungmen`, `Penguin Logistics`, `Blacksteel`, `PRTS`, `W`, `L.G.D.`
- **`places_transliterate`** — the *only* exception: **`Chernobog → Чернобог`**.
- **`terms`** — recurring lore words use the established RU form: Oripathy →
  орипатия, Originium → оригиниум, Infected → Заражённый, Catastrophe →
  Катастрофа, Originium Arts → **Искусство** (there is **no magic** in this
  setting — Arts is always Искусство, never магия; a Caster's ability is her
  Искусство).

## Ты / Вы (T–V distinction)
English "you" is genderless *and* register-less; Russian forces a choice. Pick
deliberately and stay consistent within a relationship for the whole arc:
- Operators/staff address **the Doctor** with **Вы** (respect for command); the
  Doctor and Amiya use **ты** with each other (close, familiar).
- Reunion ↔ captives, interrogations, threats → **ты** (contempt / dominance).
- Children, close friends, squadmates in the field → **ты**.
- Strangers, officials, formal briefings → **Вы**.
When dumping EN lines to translate, annotate the register alongside sex (below).

## Direct address (vocative) — do not turn into an object
English frequently ends a line with `, <Name>` / `, Doctor` as **direct address**
to the listener, not as a second grammatical object. Render it as a comma-set
**nominative**, never an accusative/conjoined object:
- `I think highly of Dr. {@nickname}, Amiya...`
  → «Я очень высоко ценю Доктора {@nickname}, **Амия**...»  (address)
  → **NOT** «...ценю Доктора {@nickname} **и Амию**...»  (wrong: "value D. and A.")
Cross-check the surrounding lines — if the speaker is talking *to* that character,
the trailing name is a vocative. This is semantic; the lint cannot catch it.

## Typography
- Quotations: guillemets `«…»` (nested → `„…“`). Not straight `"` or curly `“”`.
- Dash: `—` (spaced) for dialogue and parentheticals; **not** ` - `.
- Interrupted / cut-off speech: `—`, not the English `--`.
- Keep `ё` everywhere (Заражённый, Ребёнок, ещё). Do not flatten to `е`.
- Ellipsis: `...` (three dots) — used uniformly across the corpus.

## Markup — never touch
Preserve template tokens and inline markup **verbatim**: `{@nickname}` (the
Doctor's name), any `{…}` token, inline tags, and `\n`. A dropped/edited token
silently corrupts the line. The audit flags a RU line whose `{…}` token set
differs from its EN source.

## Coverage / atomicity
`names` is applied to the **whole** chapter but `lines` only where present, and
missing lines fall back to **English**. So a half-done file shows RU speaker
names over English text. Finish every line in a chapter before shipping it.

### Four visible props — `decision` is the Doctor's voice, do not skip it
`applyRu` overlays `content`, `text` **and `options`**, so a chapter's translatable
ids come from **four** props, not two:

| prop | field | what it is |
| --- | --- | --- |
| `name` / `multiline` | `content` | dialogue (has `name`) or narration (no `name`) |
| `subtitle` / `sticker` | `text` | on-screen captions |
| `decision` | `options` | **the player's / Doctor's own lines** |

`decision` lines are easy to miss because they carry no speaker name — but they are
the only place the Doctor speaks. A chapter without them reads as if the player is
mute (this happened to *Business as Usual*, act10d5 st06). Rules for them:
- Options are **`;`-separated**; keep the separator and the **exact option count**.
- A lone `......` option is the "say nothing" choice — leave it as `......`.
- The Doctor is masculine and follows the T–V table above: **ты** with Amiya and
  with children/teens; **Вы** with adult operators, officers and outsiders.

### Verify ids, don't eyeball them
Always diff the RU `lines` keys against the EN source ids programmatically before
shipping. Two failure modes the eye misses:
1. **Missing ids** — whole classes of line (esp. `decision`, and the opening
   time/place narration) silently fall back to English.
2. **Off-by-one shifts** — every line present but seated on the neighbouring id, so
   the text is subtly wrong for a whole block (this happened in act10d5 st03
   #297–301). Cross-check that "marker" lines (`......`, `?`, `——`) line up on both
   sides; if a short EN line maps to a long RU line, the block has slipped.

## Workflow for new episodes
0. **Read the whole EN script first** and characterize each speaker (esp. new
   ones) before translating a line — see the Process in `_STYLE.md`.
1. When dumping EN lines to translate, annotate each with `speaker (sex, ты/Вы)`
   so you write correct agreement **and** register up front.
2. Apply `_GLOSSARY.json` for all names, places, and terms; add new characters to
   it up front so they're consistent from line 1.
3. Translate meaning-first in each character's voice (`_STYLE.md`).
4. Coherence pass: re-read the RU against itself for voice drift and calques.
5. Run the lint: `python tool/gender_audit.py` (joins each ru/*.json line to
   its source speaker; flags first-person gender-agreement mismatches,
   glossary/name disagreements, place-name policy violations, and `{…}` token
   mismatches). Review + fix before building.


