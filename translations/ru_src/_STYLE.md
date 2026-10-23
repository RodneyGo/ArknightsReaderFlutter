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
- For opponents, start with **ты** in both directions, including the Doctor.
  If a character deliberately retains **Вы** during a confrontation, record
  why and anchor it to a line. For example, Hellagur's restrained, pointed
  courtesy to Cronin (*Теперь — Вы. Какая поэтичная справедливость, господин
  Кронин.*, `act3d0_06_end #88`) is a deliberate exception. Do not switch
  registers solely because a character belongs to an opposing faction.
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
| Ceylon | Educated and formal, earnest, stubborn; becomes direct when defending her choices | *Я не тепличный цветок и не маленькая несмышлёная принцесса!* `act3d0_06_beg #110` |
| Schwarz | Laconic, disciplined; respectful distance masks attachment to Ceylon | *Госпожа, Вы моя подруга. Всегда ею были.* `act3d0_06_beg #129` |
| Skyfire | Proud academic, impatient and theatrical; technical precision amid bickering | *Прованс, ты точно-точно уверена, что мне нельзя сжечь здесь всё дотла?* `act3d0_01_beg #10` |
| Provence | Practical and friendly, gently teasing; firm about professional duty | *Ты уже в десятый раз за час жалуешься, принцесса.* `act3d0_01_beg #13` |
| Eyjafjalla | Careful, clear scientific explanations; polite and modest | *По возможности я рекомендую как можно скорее начать эвакуацию.* `act3d0_st02 #10` |
| Hellagur | Restrained veteran; measured observations, dry humour | *Теперь — Вы. Какая поэтичная справедливость, господин Кронин.* `act3d0_06_end #88` |
| Herman | Courteous, reflective, pragmatic; controlled authority | *Я не ищу понимания, Доктор.* `act3d0_st05 #97` |
| Cronin | Patronizing bureaucratic politeness that breaks into greed and rage | *Но Вы — особый случай, поэтому я готов всё Вам объяснить.* `act3d0_02_beg #91` |
| Ifrit | Blunt and excitable; rough language conceals practical kindness | *Сама прибежала помогать — теперь не вздумай улизнуть!* `act11d7_st01 #421` |
| Vigna | Energetic, frank, playful; music fan eager to act | *Хе-хе, давно хотела попробовать.* `act3d0_05_beg #122` |
| Sora | Bright, conversational; enthusiastic about music | *Уж в музыке я разбираюсь — во всех жанрах!* `act3d0_st01 #157` |
| D.D.D. | Female; exuberant stage patter, demanding of her own creative work | *Теперь, когда он мне понятнее, остаётся его раздвигать.* `act3d0_ex01_end #38` |
| Emperor | Swagger, showmanship, teasing threats; occasional rhymed boasts | *Ты так бессилен, что вышел весь пар, или виной мой блистательный дар?* `act3d0_ex03_end #132` |
| Elysium | Talkative, friendly, easily sidetracked; exuberant fan | *Наконец-то дозвонился...* `act11d7_st01 #18` |
| Thorns | Literal, terse, analytical; helps without seeking gratitude | *Я просто шёл помочь другу разобраться с неприятностями. Немного отклонился от пути.* `act11d7_st01 #325` |
| Cutter | Reserved, apologetic and self-doubting; practical when encouraged | *Я не сдаюсь, просто не хочу доставлять ещё больше неприятностей.* `act11d7_st01 #399` |
| Beeswax | Gentle and contemplative; takes rough compliments literally | *Это место, куда я в конце концов должна вернуться, куда бы ни ушла.* `act11d7_st01 #485` |
| Aya | Playful, elusive; casual chatter turns lyrical and unsettling | *Но это не море.* `act11d7_st01 #580` |
| Alty | Informal, digressive and teasing, with unsettling insight beneath it | *Кстати, почему бы не поговорить о временах, когда мы ещё видели звёзды?* `act3d0_ex06_end #19` |
| Lava | Direct, impatient, practical; warmth shows through short replies | *Всё хорошо. Я понимаю.* `act16d5_08_beg #100` |
| Kroos | Relaxed and teasing until her experience demands precision; restrained grief | *Война изматывает. Нужно быть начеку.* `act16d5_08_beg #94` |
| Nian | Irreverent, exuberant, fond of food and teasing; turns grave about her origins | *Страшное место этот Yan.* `act16d5_10_beg #652` |
| Mr. Nothing | Male; florid courtesy, proverbs and comic evasions; plain anger about his master | *«Правила»! Да это убийство!* `act16d5_06_end #227` |
| Saga | Female; warm, candid Buddhist traveller; lightly archaic but readable | *Если поступать от чистого сердца и жить свободно, в согласии с собой, нечего бояться.* `act16d5_08_end #282` |
| Dusk | Aloof, terse, proud; sustained philosophical arguments, sharp banter with Nian | *Если у тебя уже есть свои мысли, зачем спрашивать меня?* `act16d5_08_end #149` |
| Dawn / Shopkeeper | Female; quiet, perceptive, cryptic, later intimate and frail | *Как думаешь... счастливую я прожила жизнь?* `act16d5_st03 #90` |
| Storyteller | Courteous, theatrical storyteller; fables use a measured literary register | *Разумеется, с картины.* `act16d5_01_beg #19` |
| Beagle | Female; warm, cheerful and considerate toward her old squadmate | *Может, останешься ещё на несколько дней? Я о тебе позабочусь!* `act16d5_10_beg #346` |
| Lin | Male elder, the man with a cane; laconic authority, not Lin Yühsia | *Встань. Я сам тебя вынудил. Незачем становиться на колени.* `act16d5_10_beg #182` |

| Bison | Earnest young male courier; polite questions become decisive commands | *Просто раскидайте их.* `act5d0_10_beg #242` |
| Mostima | Calm, teasing, elusive; philosophical without solemnity | *Я уважаю старших и забочусь о младших.* `act5d0_10_beg #176` |
| Croissant | Warm, brisk, commercial-minded; colloquial without an invented regional accent | *Хе-хе. Реклама — важный источник дохода!* `act5d0_st03 #139` |
| Gambino | Proud, explosive mafia boss; coarse speech and fixation on honour | *Я больше не стану трусом.* `act5d0_09_beg #182` |
| Capone | Calculating, cynical; practical survival behind contempt | *Мы будем жить здесь, в Lungmen.* `act5d0_09_beg #213` |
| Rat King / Lin | Measured paternal authority; dry humour turns into credible menace | *Крысиный король ещё жив. Твой черёд умирать не настал.* `act5d0_st02 #348` |
| Jaye | Plain, laconic, helpful; unwittingly intimidating appearance | *Я не шучу.* `act5d0_st02 #41` |
| Waai Fu | Direct, earnest sense of justice; practical student behind heroic diction | *Но когда у меня на глазах негодяи обижают невиновных, я не могу сидеть сложа руки...* `act5d0_st02 #48` |
| Uncle Tung | Blunt old friend; affectionate barbs, mortality and everyday trade | *Честно говоря, рост цен на продукты для меня куда опаснее мафии.* `act5d0_st02 #305` |
| Yith | Very formal, matter-of-fact, unperturbed by absurdity | *Мы привыкли к такому поведению.* `act5d0_10_end #50` |
| Butler (act5d0) | Male; punctilious deference, controlled professionalism | *Благодарю за понимание. А Вы берегите себя, молодой господин.* `act5d0_10_end #360` |
| Eurill | Genial businessman and Bison's father; cheerful calculation | *Разве это на меня похоже?* `act5d0_ex01_end #151` |
| Suffering? / Chosen Overseer? / Treasure Guardian? | One woman; exasperated professional, sharp banter with Mostima | *Откуда мне знать!* `act5d0_st03 #280` |
| Lappland | Mocking, gleefully menacing; short instructions after long provocations | *Я досчитаю до десяти. / Бегите.* `act5d0_ex02_end #106–107` |

### Doctor ↔ FrostNova — address and continuity

- The Doctor and FrostNova address each other with **ты** throughout chapter 6, including
  `level_st_06-02`, `level_main_06-13_end`, `level_main_06-14_beg` and
  `level_main_06-15_end`. Example: *Ты победила.* (`06-13_end #200`).
- Preserve feminine singular agreement: *ты говорила*, *ты не обещала*,
  *ты не согласна*. Apply this to every answer option, not just speaker labels.
- FrostNova addresses the Doctor in masculine singular: *Ты не убил меня...*
  (`st_06-02 #41`), *Возвращайся, Доктор, к своим.* (`06-13_end #241`).
- Keep other speakers' addresses and true group plurals: `06-14_beg #518`
  refers to those deceived by Talulah; `06-13_end #210` greets the Yeti squad.
  FrostNova's `st_06-02 #273, #343-344` refer to Rhodes Island collectively;
  `st_06-02 #404` threatens everyone, and `06-15_end #153` addresses both the
  Doctor and Amiya. Invitations to fight the whole squad also remain plural.

### Heart of Surging Flame — relationship and continuity notes

- Translate the entire `act3d0` chapter list, including the opening vote scene,
  the EX scenes, and **OF-ST6** (`activities/act11d7/level_act11d7_st01`). The
  latter belongs to this event despite being stored under a different activity.
- Ceylon uses **ты** with Schwarz; Schwarz uses **Вы / госпожа** with Ceylon,
  even while learning to accept their friendship. Their changing relationship
  is not a reason to silently change every address to **ты**.
- Skyfire and Provence, Thorns and Elysium, and Penguin Logistics colleagues
  use **ты** among themselves. Doctor and Amiya retain **ты**. Formal strangers
  and the Doctor's conversations with adult operators use **Вы**. Cronin's
  collapse into threats and Emperor's taunts deliberately use a rougher register.
- Skyfire's nickname for Provence is **Пушистый хвост**. The setting's proper
  names, including Siesta and Alive Until Sunset, stay in Latin as in the glossary.
- The self-narration and choices in OF-ST6 belong to **Thorns**, not the Doctor.
  Check scene context rather than assuming every `decision` has the same speaker.
- OF-ST6 #57 deliberately has **45 whitespace-separated words**: Thorns counts
  them in #63 after setting a thirty-word limit. Preserve the joke when editing.
- D.D.D. is female (explicitly referred to as *she* in `act3d0_ex03_end #12–16`).
  Emperor's *Penguin from the West* epithet is **Пингвин с Запада**, referring to
  him personally; it is not a translation of the company name Penguin Logistics.


### Who Is Real — relationship and continuity notes

- Cover all 17 `act16d5` entries, WR-ST-1 through WR-ST-3: 2,278 visible
  lines. There are no additional `act16d5` entries in the supplied archive meta
  table. The supplied `ArknightsStoryJson-main/en_US` files are the EN source.
- Lava, Kroos and Nian use **ты** with one another; Lava and Saga also use
  **ты** as companions. Mr. Nothing addresses his benefactors with **Вы**;
  Lava and Kroos keep **Вы** with him. His *благодетельница* and proverb-heavy
  courtesy persist even when the others challenge his honesty (`06_end #194–201`).
- Saga uses **Вы** with Mr. Nothing and Dusk (deference to the master), **ты**
  with Dawn. Dusk uses **ты** with Saga. Dawn and Lava use **Вы** mutually.
  Dawn and Dusk, and the two sisters, use **ты**. Keep actual group plurals.
- Mr. Nothing keeps respectful **Вы** to Lin even under threat (`10_beg #141`),
  because his teacher specifically forbade disrespecting Lin. Lin uses **ты**.
  Kroos initially addresses an unidentified Dusk with **Вы** (`10_beg #679–683`),
  then **ты** once the hostile encounter is clear (`#695`). Mr. Nothing retains
  his ingratiating courtesy in the same confrontation (`#689`). These are
  deliberate voice/scene exceptions to the opponents' default **ты** rule.
- Storyteller is a male persona; Dusk can speak through that persona. Dawn's
  **Вы / сударь** to Storyteller in WR-ST-2 (`#84–99`) maintains that persona
  while she makes her point. Do not force feminine agreement into every line
  under this label, or infer that every appearance is the same encounter.
- **Shopkeeper is Dawn**, a woman (`04_beg #487`); check earlier anonymous
  appearances too. The opening unlabelled recollection in `05_end` belongs to
  Dawn. `Villager` covers different people, including Ah Jan's mother and the
  grieving wife in `05_end #78–80`; determine agreement from each scene.
- The `Greytail` in Mr. Nothing's dream is male (`10_beg #292`: *big guy*),
  unlike the female character with the same EN label in chapter 7. The glossary
  speaker label stays **Грейтейл**; the gang's name **Greytails** stays Latin.
- Dawn's name is **Доун**, with its meaning explained in `04_beg #487` and
  `05_beg #130`; do not replace the personal name with a translated noun.
  Mr. Nothing's comic alias splits into **«Ни» да «что»** (`01_beg #147`), with
  **брат Ни** in `02_beg #117`. Storyteller's descriptive pen name is
  **Отшельник, варящий зонты**. Titles of tales and paintings are translated;
  named places, including Mt. Sky and Elegant Garden, remain Latin.
- Dreams in `10_beg` are hypothetical lives, not confirmations of historical
  events. Keep the sequence and transitions intact. Repeated mountain, water,
  moon and painting imagery links the fables to the ending; preserve it.
- Audit false positive: `level_act16d5_06_end #209` is spoken by Mr. Nothing
  (*Я уже смирился...*); *она сказала* refers to his female teacher. Both
  agreements are intentional. Do not rewrite the line just to silence the lint.

---

### Code of Brawl — relationships, aliases and continuity

- Coverage: all 27 `act5d0` scenes (2,921 visible texts), including ENTRY,
  CB-ST1–3 and CB-EX1–3. `story_review_meta_table.json` adds no other scenes.
  The opening first-person recollection in CB-ST1 is **Bison**, not the Doctor.
  Both live EN sources match the supplied archive's visible IDs and content
  except `09_end #5`: the archive has `00:38 A.M.`, the mirrors `0:38 A.M.`.
  Both denote the same time; the RU caption is `00:38`.
- Bison uses **Вы** with the adult couriers, Emperor and his butler; the crew
  uses **ты** with him. The butler returns **Вы / молодой господин**. Penguin
  Logistics colleagues use **ты** among themselves, including Emperor.
  Exusiai and Mostima are old friends; keep their intimate, teasing **ты**.
- Opponents normally use **ты**, including Bison facing the mafia. Exceptions
  are deliberate: Mostima keeps **Вы** with the Rat King during their poised
  negotiation and duel (`08_end #53–79`, `10_beg #145–175`). He uses **ты**.
  Capone and initially Gambino use **Вы** when formally paying their respects
  in the earlier meeting (`10_beg #47–78`); Gambino breaks into **ты** at #65.
  The later confrontation (`09_beg`) uses **ты**. This is chronology and intent,
  not an automatic switch for elders or enemies.
- Mafia subordinates use **Вы** to their bosses and the Rat King. Jaye uses
  **Вы** to Uncle Tung and the Rat King, **ты** with Waai Fu. Uncle Tung, Lin
  and Wei speak as old acquaintances using **ты**. Eurill and Wei retain
  businesslike **Вы**; Emperor is familiarly irreverent with everyone.
- Yith maintains professional **Вы**, including with the sharp anonymous
  Laterano visitor (`08_end #17–23`, `10_end #58–62`). Mostima uses **Вы** to
  Yith. Her visitor uses **ты**, as she does with Mostima. In `08_end`,
  `10_end`, and the later conversation in CB-ST3, this visitor is a woman.
  Do not assign that sex to every `???` label: EX3 has multiple anonymous fans.
- `Suffering?`, `Chosen Overseer?`, and `Treasure Guardian?` are the same
  visitor's deliberately absurd **temporary duty titles**, not her personal
  name (`st03 #256–301, #370`). Translate their meanings as **Страдание**,
  **Избранная надзирательница**, **Хранительница сокровищ**, with the source's
  question marks in speaker labels. Likewise **Рыцарь гробниц** and
  **Суперприлипала**. This preserves the jokes at #287 and #372 without
  inventing or revealing a personal name absent from this scenario.
- The bar is **The Ends of the Earth**: retain Latin under the place-name
  rule, including the earlier rendezvous clue (`04_end #31`, `st01 #189–195`).
  **Notarial Hall** remains Latin as an institution. The nonexistent
  **Treasure Guardians** organization in the joke at `st03 #292` also remains
  Latin. Family as kinship/mafia structure is **Семья**, not a new place name.
- **White Horse Kohl** (`06_beg #104`) is the exact material name from the EN
  item table, item 30074, named for its producer. Keep that name rather than
  inventing a chemical identity or interpreting it as a beverage brand.
  **А-Фил** is Jaye's nickname; **А-Фат** is the deceased boy. Preserve the
  distinction. Rat King's **Линь Грей** is not Lin Yühsia.
- Mostima's running disappearance joke becomes **Смостимилась** (`08_end #188`).
  Emperor's apparent deaths are intentional; do not soften them into injuries.
  His survival and the Rat King's staged shooting are explained in the ending.
- One EN speaker is literally `Mafioso `, with a trailing space (`09_beg #250`).
  The overlay and glossary include that exact alias because `applyRu` looks up
  names without trimming. Its translation is the ordinary **Мафиози**.
- New audit false positives, all intentional: `08_beg #77` (*он сказал*) is
  Exusiai referring to Emperor; `10_beg #14` (*дядя Хо сказал*) is the little
  girl quoting a man; `st03 #72` (*ты решил*) is Mostima addressing Bison.
  The place heuristic flags **Пингвины** as a nickname (`07_beg #157`,
  `st02 #116`) and **пингвин на двери** as the literal sign (`st01 #410`).
  None replaces an occurrence of the proper company name Penguin Logistics.
  Filenames here use the prefix `level_act5d0_` and suffix `.json`.

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
