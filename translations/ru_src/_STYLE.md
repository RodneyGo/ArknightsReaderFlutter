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
| Kal'tsit    | Cold, precise, no filler; controlled anger         | *Так что, когда настаёт день вроде сегодняшнего, когда возможно что угодно, Rhodes Island должен быть готов действовать по обстоятельствам.* `07-02_end #214` |
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
- The frightened captive Mafioso keeps **Вы** when asking Exusiai to spare
  him (`07_beg #64`). This is a plea for mercy after his account of the plan,
  not a hostile taunt. Exusiai's playful answer addresses him with **ты**.
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

### Il Siracusano — voices, relationships and continuity

All references below use `level_act21side_` and `.json`. Coverage is the 24
`act21side` review-table scenes, IS-ST-1 through IS-ST-4: 6,244 visible texts.
The supplied archive has no extra `act21side` meta-table scenes.

| Recurring speaker | Voice | RU anchor |
| --- | --- | --- |
| Texas | Laconic, practical; guarded affection and a clear wish to return home | *Я вернусь в Lungmen. Меня там ждут.* `act21side_02_beg #182` |
| Lavinia | Principled, precise; wounded conviction without inflated rhetoric | *Но если ты прямо сейчас меня не запрёшь, никто не помешает мне найти убийцу.* `03_end #220` |
| Leontuzzo | Controlled young strategist; courtesy gives way to concern | *Но как ты одна остановишь дождь?* `03_end #193` |
| Bernardo | Cultivated director and measured patriarch; theatre and power share his vocabulary | *Но увы, синьорина Сора, действительность логике не подчиняется.* `01_beg #122` |
| Demetri | Dry, efficient, ruthless; familiar banter with Leon | *Работаете на меня — получаете деньги. Лучше работа — больше платят. Всё просто.* `01_end #483` |
| Wallach | Urbane bargaining conceals ambition and impatience | *Ваш звёздный час, не так ли?* `01_end #574` |
| Giovanna / Caterina | Perceptive, theatrical and authoritative; personal grief behind the pose | *Люди редко бывают воплощённым злом, не правда ли?* `02_end #356` (before her alias is revealed) |
| Alberto | Laconic, absolute paternal authority; refuses to acknowledge sentiment | *Ты испачкала мой стол, Лаппланд.* `st01 #1243` |
| Rubio | Servile social polish; pragmatic, bitter arguments about ordinary lives | *Пусть мёртвые остаются мёртвыми.* `03_beg #459` |
| Ben / Benthonexigios | Wry observer and theatrical mentor; expansive but clear | *Запрет налагает театр, а не сама пьеса.* `01_end #115` |
| Zaaro | Imperious, ancient self-importance; promises and debts treated as natural law | *Пустоши всегда играют честно.* `st01 #182` |
| Agenir | Genial elder whose calm survives violence | *Ха-ха-ха! Хорошо, хорошо. Присаживайтесь. Для разговора с молодёжью любой день хорош.* `08_beg #397` |
| Danbrown / Carwash Worker | Plain everyday speech hiding old violence and resentment | *Вы не стали цивилизованнее. Вы стали лицемернее.* `09_beg #569, #673` |
| Lunacub | Direct, literal, spare; wolfish judgments without ornate speeches | *Ты никогда не бываешь один. А я не умею сражаться сразу со многими.* `09_beg #857` |
| Signora Sicilia | Unhurried authority; concise judgments and practical orders | *Всегда лучше выслушать и второе, и третье.* `09_end #787` |

- Texas, Lappland and Leon use **ты** with one another. Lavinia and Texas
  retain mutual **Вы**, including detention (`02_beg #765–767`), questioning
  (`02_end #191–248`) and cooperation. This is professional respect, not an
  automatic enemy/stranger rule. Lavinia and Leon/Bernardo use **ты**.
- Demetri addresses Lavinia with **Вы**, she addresses him with **ты**
  (`01_end #277–308`): his pointed courtesy resists her demand for cooperation.
  Mafia subordinates normally use **Вы** to their dons; familiar private
  exchanges and deliberate breaks in deference must follow scene context.
- Lavinia uses **ты** with Lappland after the hostile court intrusion
  (`04_end #442–453`). Lappland's **Вы / Ваша честь** back to her is pointed
  mockery (`st02 #101–112`), not deference to an opponent's rank.
- Bernardo and Rubio keep mutual **Вы** in formal negotiation, including the
  implied threat (`07_end #20–88`). Danbrown keeps **Вы** to Lavinia even in
  his threat (`07_end #157, #178`); she uses **ты**. His courtesy is deliberate.
- Texas and Giovanna use **ты**. Wallach uses **Вы** to Giovanna until the
  betrayal makes the break explicit: *донна. Нет... Ты... Джованна*
  (`08_beg #748`). Keep **ты** after that. Young visitors use **Вы** to Agenir,
  who uses **ты** back; this remains negotiation, including `07_end #280`.
- Rubio's unlabelled diary and his Radio speech are masculine. His second-person
  hypothetical (`08_end #253–283`) recounts his own past to Lavinia; it is not
  her biography. His daughter uses **Вы** to Lavinia, who uses **ты** to her.
- Sora and Bernardo/Caterina use mutual **Вы**. The couriers keep **ты** with
  one another. Texas and Zaaro, Emperor and Zaaro, and Lappland and Alberto
  use **ты**. A father/daughter confrontation is not formal deference.
- Wallach and Leon start their bargaining with **Вы** (`04_beg #115–156`),
  then Wallach's *брат* marks a move to **ты** (`#161–162`). Rubio keeps
  ingratiating **Вы** to powerful visitors; his exchange with Wallach is a
  veiled business threat, not a reason to replace every courtesy with **ты**.
- Lavinia first addresses the hitman as **ты**, then recognises her former
  colleague Bortolotti and switches to **Вы** (`03_beg #788–809`). He retains
  bitter **ты**. Preserve this deliberate appeal to the judge he used to be.
- Court Clerk is female in this event (portrait `avg_npc_697_1#1$1`, first
  shown at `01_beg #364`). Carwash Worker is Danbrown, male (`02_beg #340`).
  Caterina is Giovanna's pseudonym (`02_end #437`); retain each source label.
  The unnamed `???` speakers are not all the same person or the same sex.
- Sora plays Vivienne, while Exusiai reads the brother's male role in rehearsal
  (`01_end #15–35`). Use the character's performed role for agreement in the
  play, and the actress's own gender outside it. The ordinary play title is
  **«Смерть Техас»**; Croissant mangles it deliberately in `st02 #672`.
- Family names as organisations remain Latin: **семья Bellone / Saluzzo /
  Rossati**. Personal surnames are transliterated (**Бернардо Беллоне**,
  **Альберто Салуццо**, **Джованна Россати**, **Лаппланд Салуццо**). Preserve
  the distinction from kinship references such as **род Техас**, and from the
  proper organisation label **Famiglia Texas**. Cities, Grey Hall, theatres,
  the carwash and named institutions follow the keep-Latin glossary.
- **Владыка / Владычица / Владыки волков**, **Клык**, **район резервного ядра**
  and **командная башня** are stable terms. Red's **Бабушка** is a wolf's
  title/nickname, not proof of literal kinship. Lyudmila's mentor is a woman.
- Bernardo and Agenir retain mutual **Вы** in their final philosophical
  conversation (`09_end #325–336, #538, #572–604`), even though Agenir has a
  mission to end him: a deliberate courtesy between elders and a spiritual
  confidant. Bernardo initially addresses Zaaro as **Вы / дон**, then unmasks
  him and moves to **ты** (`09_end #666–679`). Sicilia welcomes Emperor with
  **Вы** (`10_end #388–392`); he keeps his irreverent **ты**. Leon uses **Вы**
  to Sicilia during negotiation (`10_end #416–426`).
- The final unlabelled funeral dialogue (`st04 #245–273`) alternates Demetri
  and Leon, not the Doctor. The old mentor in Lyudmila's recollection is female
  (`st04 #98, #119–120`); do not infer a man from **Maestro**.
- **Ни пуха ни пера / К чёрту** (`09_end #497–499`) localises the paired
  *In bocca al lupo / Crepi* well-wishing; do not confuse it with the faction
  Bocca di Lupo. Sicilia's **не мешай ходу событий** (`09_end #814`) preserves
  the four-word plan: let the famiglie's bloodlust run its course.
- Retain the recurring rain/shelter metaphor, the government/tablecloth image,
  the reprise of Lavinia's words, and Danbrown's **цивилизованнее / лицемернее**
  accusation when Leon turns it into a statement about **мы**. Do not smooth
  away the different layers of performance, flashback and present action.
- Both live EN sources (m31ns and ArknightsStoryJson main) were compared with
  the archive. All visible IDs and text match except `10_end #521, #523`:
  live **Bocca di Lupo** replaces archive **Bocca al Lupo**. The RU overlay
  uses the current name **Bocca di Lupo**; the supplied archive is unchanged.

- Audit review: the full run returns exit 1 with empty stderr: 46 gender
  candidates and four pre-existing place candidates. Twelve gender candidates
  belong to this arc and are false positives, explicitly reviewed below;
  the other 38 candidates predate this translation. There are no new glossary,
  place or token findings. Do not alter correct agreement just to silence lint.

| File (same act21side prefix) | ID | Why the agreement is correct |
| --- | --- | --- |
| `01_beg` | 425 | Court Clerk refers to an ideal **судья**, *каким должен быть*, not herself. |
| `02_end` | 94 | Demetri says **Техас должна**, describing a woman. |
| `02_end` | 464 | Giovanna says **ты должен** to Wallach. |
| `03_beg` | 24 | Exusiai asks **кто сказал**, then refers to herself as **слышала**; the heuristic is case-sensitive. |
| `03_beg` | 472 | Rubio asks his daughter **ты готова**. |
| `04_end` | 194 | Leon describes Texas with **она сказала / готова**; his own **не додумался** is masculine. |
| `06_end` | 211 | Lappland's **кто сказал** is an indefinite question, not masculine self-reference. |
| `08_beg` | 714 | Giovanna's **каким должен быть** modifies **финал**. |
| `10_beg` | 333 | Lappland addresses her father: **ты думал**. |
| `st01` | 757 | Bernardo's **Сора сама решила** refers to Sora. |
| `st01` | 1067 | Capone quotes Lappland's **я вас привела**. |
| `st02` | 497 | Alberto's **ты вернулась** addresses his daughter; **я выгнал** is masculine. |

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


## Hortus de Escapismo / The Masses' Travels — shared translation map

The two events share a cast and vocabulary. Their EN source is the supplied
ArknightsStoryJson archive, compared against both live application mirrors
(m31ns and 050644zf/ArknightsStoryJson) for all 43 scenes; displayed IDs, props
and attributes match. HE has 19 scenes / 3920 texts; MT has 24 / 5726.
The five MT challenge-book records in story_review_meta_table are separate
`textId` resources, not storyTxt scenes in this application's catalog.

### Shared terminology and relationships

- Names follow `_GLOSSARY.json`, including mentions in prose. Organizations,
  buildings and places in `places_keep_latin` remain Latin. Job titles translate:
  executor → исполнитель, nuncio → нунций, Legatus/Legati → легат/легаты,
  cardinal aide → помощник/помощница кардинала; the operator codename Executor
  retains its canonical name. Senior/seniora → господин/госпожа (courtesy,
  not a higher rank). Avus / Patruus / Amita → дедушка / дядюшка / тётушка.
- patron firearm → личное оружие; guardian gun → оружие-хранитель (MT distinguishes
  the wordings); Law → Закон, Empathy → эмпатия; sanctuary/sacrarium → святилище.
  Nativity → Рождение, Transfiguration → Преображение, enlightenment → просвещение,
  Nurturer → воспитатель, arborbeast → древозверь. Terms denote what the EN says;
  do not add explanations of the Law or turn religious belief into established fact.
- HE community friends/family use ты; residents address the abbot with Вы,
  he addresses them with ты. Gerald ↔ Stefano and Aulus ↔ Stefano use ты.
  Children address unfamiliar visiting adults with Вы; adults address children
  with ты, groups with lower-case plural вы. Fortuna ↔ Clément and
  Delfina ↔ Caroline are familiar ты. Fortuna → Serpilia is Вы; reverse is ты.
- Federico ↔ Richele/Serpilia/Oren/Lemuen/Arturia use ты in HE. Pope → Federico
  is ты, Federico → Pope is Вы. To unfamiliar adult residents Federico uses
  service-formal Вы, including pressure and questioning: HE01_beg #218–246,
  HE01_end #220–221, #417–419; HE03_beg #440–458 keeps the abbot's formal dispute.
  Raimund/Gerald address Federico with ты. This is a deliberate exception to
  default opponent ты: Federico states procedure and assessments rather than
  threatening, and explicitly denies trying to provoke anyone (HE01_beg #242).
- Richele retains conciliatory Вы toward Raimund and the abbot while negotiating
  (HE01_beg #206–208, #381–388; HE02_beg #197). Arturia addresses the abbot,
  Gerald and Clément with Вы; the abbot/Gerald use ты back. Her polite register
  continues under Gerald's warning (HE01_beg #284–330). Arturia ↔ Aulus use Вы
  in their theological exchange, including «достопочтенный епископ» (HE02_beg #91).
- Lemuen initially uses pointedly courteous Вы to her monstrous visitor
  (HE03_beg #514; HE03_end #13–89), then drops the courtesy in pursuit;
  the shift follows the initial hospitality joke. Lemuen ↔ Aulus remain Вы
  during combat and theological debate (HE05_beg #602–648, #775–787).
- MT Federico ↔ Cardinal Lemuen use formal Вы when discussing command and
  authority (MT09_beg #91); this does not retcon their familiar HE exchange.
  Doctor is masculine, Mon3tr → Doctor and Doctor → Mon3tr use Вы.
  Priestess addresses Doctor and Mon3tr with ты. Preserve genuine group plurals.

### Voice anchors from HE

| Character | Voice | Anchor |
|---|---|---|
| Federico | Literal, procedural, concise; does not invent emotion or jokes | «Это наиболее рациональное предположение.» `act26side_03_beg #52` |
| Yvangelista XI | Warm authority, playful without abandoning responsibility | «Спокойнее, Джованни. Кто не рискует, тот ничего не добьётся.» `act26side_st01 #100` |
| Arturia | Courteous, observant; describes feelings through music and growth | «М-м... Как сложны обертоны. Но в Вас скрыты и другие чувства...» `act26side_03_end #122` |
| Stefano / Abbot | Pastoral gentleness breaking into moral anguish | «Куда податься верующему, если вера предала саму себя?» `act26side_st01 #416` |
| Gerald | Worn, protective, plain-spoken; resists heroic rhetoric | «Клянусь, я не брошу ни одного из вас.» `act26side_03_end #315` |
| Clément | Hesitant, caring; practical concerns express helplessness | «Что я ещё могу придумать? Грядущая зима слишком холодна.» `act26side_03_end #194` |
| Raimund | Young, prickly, loyal; defensiveness masks attachment | «Неужели мы смиримся с тем, что сейчас происходит?» `act26side_st01 #495` |
| Fortuna | Earnest, hopeful, concrete; fractured speech under shock | «Теперь я наконец... такая же, как Раймунд и Каролина...» `act26side_04_beg #150` |
| Delfina | Blunt and passionate about belonging; avoid making her merely rude | «Это мой единственный дом. И моя единственная семья.» `act26side_02_beg #688` |
| Richele | Conversational mediator, humour softens blunt colleagues | *Мог бы добавить к этому «да» ещё пару слов.* `act26side_01_end #339` |
| Serpilia | Casual, sharp, wry; guilt disrupts her usual banter | «Если бы я не помогла тебе починить ружьё...» `act26side_04_beg #135` |
| Lemuen | Gentle teasing with firm command underneath | «Крошечный совет: может, иногда тебе стоит доверять чутью.» `act26side_04_beg #259` |
| Aulus | Patient theological persuasion, quiet and deliberate | «Но прежде всего я иду путём, который считаю верным.» `act26side_04_beg #54` |
| Oren | Pragmatic, conspiratorial, treats danger as a tactical opportunity | «Выслушаешь — поможешь?» `act26side_03_beg #339` |
| Estara | Shy, hesitant, seeks reassurance | «Он такой страшный...» `act26side_04_beg #354` |
| Erendel | Bold child, direct judgments and excitement | «Ага, большой дядя нас сразу нашёл!» `act26side_04_beg #341` |

The HE01 opening notebook is Andoain's male voice. Repeated memories preserve
wording across scenes. HE ST01 #49–54 contain literal `\n\n`, not actual newline
characters; keep their representation as well as their count. Exact punctuation-only
markers remain unchanged. Foreground speeches to a crowd use plural вы, not Вы.


Additional HE voices: Hyman's monster speech is fragmentary; once speech returns,
her exhausted care for the children stays restrained: «Латеранцы будут хорошо
обращаться с детьми?» (`act26side_st03 #282`). The Leithanien envoy remains
courteous even amid danger: «Прошу извинить: мы пригласили Вас в гости, а я
опоздала» (`act26side_08_end #261`). Aulus → Hyman is ты throughout, Hyman →
Aulus Вы; the epilogue does not reset their relationship from the opening scene.

Further HE narrator identities: 04_end opening, 08_beg #220–224 and 08_end
opening are Clément; 05_end prayer is Stefano. Anonymous speakers are Aulus
at 05_beg #294, Richele at 05_end #74, Oren at 06_beg #219, Lemuen at
07_beg #183, Stefano at 07_end #214 and Arturia at 03_end #215–218.
Reed is a male Sarkaz in this event, not the female operator. Leyla is female;
Sural is male. These contextual identities must not change unrelated stories.

HE audit review with the extended canonical cast (seven heuristic findings):
- `level_act26side_02_end.json #160`: Fortuna's «говорил» refers to grandfather
  Stefano; her own «я всегда знала» is feminine.
- `level_act26side_03_beg.json #375`: Serpilia reports what Clément «сказал»;
  her own «я не стала» is feminine.
- `level_act26side_06_beg.json #354`: Lemuen's «я одержала» is feminine;
  «тот гость хотел» refers to Aulus.
- `level_act26side_06_end.json #198, #318`: Oren's «ты сказала / думала»
  addresses Serpilia, not himself.
- `level_act26side_st01.json #359`: «беда пришла» describes the disaster;
  the abbot's own «я хоронил» is masculine.
- `level_act26side_st01.json #649`: Fortuna's «никто ... не говорил» uses
  grammatically masculine никто, not a masculine self-reference.
No heuristic was weakened or suppressed to clear these findings. All source
files are present; source-fetch failures in a preliminary run were resolved by
populating the audit cache from the archive already verified against both mirrors.


MT audit review (seventeen contextual gender-heuristic findings):
- `level_act42side_02_beg.json #99`: Amos refers to Vannini («ученица ... должна»).
- `level_act42side_02_beg.json #311`: Paganini addresses Exusiai («ты ... хотела»).
- `level_act42side_02_beg.json #463`: Andoain refers to the Matriarch («хотела»).
- `level_act42side_02_end.json #384`: Vannini describes Paganini («он думал»);
  her own forms are «немая» and «я смогла».
- `level_act42side_03_end.json #73`: Velliv's «должен» agrees with «Святой город».
- `level_act42side_04_beg.json #175`: Arturia's «не сказал» refers to Federico.
- `level_act42side_06_beg.json #108`: Lemuen refers to the male school director
  («пришёл ... попросил»); her own «я очнулась» is feminine.
- `level_act42side_06_end.json #344`: Amos refers to Fiammetta («вернулась»).
- `level_act42side_08_beg.json #485`: Lemuen addresses Andoain in the old mission
  flashback («ты подал ... решил»); the addressee is not Amos in the present.
- `level_act42side_09_beg.json #84`: Andoain reports a woman's words («она сказала»).
- `level_act42side_10_beg.json #785`: Aurela addresses her father («не пришёл»).
- `level_act42side_10_end.json #245, #644`: Patrizion addresses Vannini
  («ты должна»); the repeated recollection is intentionally identical.
- `level_act42side_st03.json #177`: Yvangelista's «пришла» agrees with «мысль»;
  his self-reference «я жевал» is masculine.
- `level_act42side_st03.json #501`: Lemuen refers to Amos («не сказал»), while
  her own «я подумала» is feminine.
- `level_act42side_st04.json #179, #193`: Priestess refers to / addresses the
  male Doctor («пришёл», «ты ... понял»), not herself.

Final structural checks cover HE's 3837 name texts, 17 multiline texts,
56 subtitles and 10 stickers, and MT's 5402 name texts, 45 multiline texts,
69 subtitles, 97 stickers and 113 decisions with 177 ordered options.
The only unchanged full texts are proper names: MT01_beg #341
«Via Jovita, Pagus Stevonus», MT09_beg #345 «Laterano.» and MTst04 #306 «Mon3tr.».
No dialogue is left in English. Canonical brace tokens, inline tags, actual
and literal newline representations, punctuation-only markers, ID sets and
paths are compared with EN. Existing v18 overlays remain semantically unchanged.


### MT relationship map and scene-specific exceptions
- Doctor↔Mon3tr and Doctor↔Exusiai mutual Вы per operator rules; all choices in owned scenes reviewed. Children are ты; adult replies to Doctor male. Priestess↔Doctor ты (intimate past and current personal conflict); Priestess→Mon3tr ты. Kal'tsit→Mon3tr ты in directive memory.
- Federico↔Arturia ты; Arturia uses ironic title “Ваше Блаженство” without changing the relationship. Federico↔Andoain Вы in official investigation; Arturia↔Andoain Вы. Federico→Pope Вы, Pope→Federico ты.
- Lemuen↔Mostima/Fiammetta/Andoain ты, including old mission flashbacks. 08_beg#485 “ты подал в отставку” addresses ANDOAIN (Captain#483, Andoain reply#488, name#500), not Amos.
- Lemuen↔Amos mutual Вы in07_end and08_beg#608–675. Deliberate transition to ты at08_beg#686 (“ты отличный следователь, Амос”) and#688 (“ты ещё на связи, Лемуэн”): dying man's vulnerable private confession and Lemuen's personal reassurance replace their earlier mutual titles. This is not merely caused by using first names. Agreed with root, documented for consistency.
- Federico↔Lemuen Вы in09_beg#90–95/#195: formal request to the saint exercising supreme emergency authority and his subsequent assignment to the cardinal. Root approved this situational register; earlier HE personal relationship stays ты.
- Federico↔Aurela Вы in07_end official standoff/biography and nonviolent explanation#414–418; ordinary angry errari→Federico ты. This is a formal confrontation exception to enemy-default ты, not a polite enemy template.
- Nurturer↔Andoain mutual Вы, aligned with B earlier scenes, no gratuitous change to ты. Matriarch→Andoain ты; Andoain→Matriarch Вы before his renunciation. Matriarch↔other adult staff Вы. At08_beg#956 Andoain's direct renunciation addresses Keph by name on ты (“я разрушу свою веру”), a deliberate break with her authority. In speaking-fledgling dialogue Andoain↔Arborbeast ты throughout (including10_end#1240/#1243).
- Exusiai↔Saint ты (personal ideological confrontation). Saint→Patrizion Вы.
- Aurela↔Nueda ты; Aurela↔Patrizion ты (former mentor and hostile pupil); Patrizion↔Paganini ты; Patrizion↔Fiammetta ты (family); Vannini→Patrizion/Paganini Вы, both→Vannini ты. Patrizion↔Velliv Вы, aligned with B.
- Lemuen↔Aurela mutual Вы in st03 formal crime/contract conversation, Amos↔Aurela ты in marital flashback. Patia↔Andoain ты; Patia↔Fiammetta/Mostima/Nueda ты. Andoain→old Jaime Вы, Jaime→young Andoain ты. Adult unfamiliar nun↔Exusiai asymmetric Вы/ты consistent with adult nun and younger girl.


### MT character voice anchors
- **Mon3tr** (st04#373): Energetic, protective and practical; a person with her own choice, not merely a continuation of Kaltsit. «Психологическая консультация окончена, командир! У меня всё хорошо. Просто придумала, как выбраться из этого проклятого места. Нужна Ваша помощь!»
- **Priestess** (st04#96): Quiet exactness, researcher language and intimate address; threatening certainty without theatrical villainy. ««Совершенство» подразумевает строгий верхний предел. «Изъян» же означает, что у нас ещё есть шанс на прорыв. Такова была позиция {@nickname}.»
- **Matriarch / Saint / Keph** (08_end#356): Solemn measured theological claims; grave warmth survives monstrous form. «Веру формируют опыт бесчисленных поколений, испытания временем и следы несметного множества людей. Первые верующие не должны, не смеют вновь её менять.»
- **Arborbeast / Law dialogue** (10_beg#332): Gentle but relentless questions exposing the Guide’s self-justification; not childish speech. «Скажи, воспитатель. Ты хочешь спасти всех или думаешь только о собственном утешении?»
- **Patia** (08_end#299): Blunt, loyal and exasperated; direct practical concern beneath roughness. «Хоть переоденься, выглядишь ужасно. Или тебе <i>нравится</i> ходить в рясе, залитой кровью?»
- **Aurela** (10_beg#818): Defiant, abrasive, hatred as a chosen bond; sharp emotional attacks, no gratuitous profanity. «Вот моя связь с Laterano! <i>Вот</i> моя вера!»
- **Nueda** (10_beg#641): Patient warmth toward children; songs and prayer are practical care, not empty sermon. «На этот раз нам повезло, правда? Когда Аурела вернётся, как следует её отчитаем!»
- **Idida** (08_beg#133): Childlike earnest conviction and excited sales pitch; stammer retained where meaningful. «Так что я буду подавать пример! Изменю привычки Laterano в еде и восстановлю наши связи силой мороженого без сахара!»
- **Amos** (08_beg#644): Hesitant ordinary man; vulnerable candour, not a heroic speech. «Неужели я был <i>настолько</i> бесполезен?»
- **Patrizion** (10_end#245): Older mentor/family warmth, authority confronting regret. «Это первый урок, который ты должна усвоить... А я буду рядом.»
- **Paganini** (st03#359): Gruff elderly craftsman, curt affection and rough jokes. «Только не загуби мою репутацию...»
- **Vannini** (st03#309): Halting speech with pauses, gradually more confidence; do not flatten into generic stuttering. «Он спросил, согласна ли я, стать объектом... исследования... нарушений речи? И нимбов... Я-я не уверена, что поняла...»
- **Federico** (st03#72): Precise analytical language gaining an explicit appreciation for human fragility. «...драгоценную хрупкость человеческой жизни.»
- **Arturia** (10_end#1564): Musical perception, poised irony; her help arises from expression, not repentance. «Это просто причина моего существования.»
- **Andoain** (10_end#1251): Thoughtful religious cadence, then decisive refusal; owns his sins instead of asking to erase them. «Андоайн Агафангелос никогда не обретёт облегчения.»
- **Exusiai** (10_end#693): Bright plainspoken practical humanity, even in confrontation with theology. «Разве Laterano не должен быть счастливым местом?»
- **Hildegard** (10_end#330): Forthright cheerful competence, eager to represent her monastery. «Стрел у меня достаточно, глаз зоркий. Я помогу их сдержать!»
- **Koshelna** (st04#654): Controlled resolve; collective hope in Ursus without softness. «Лишь кровь, горящая в наших сердцах, поможет Ursus пережить зимний холод.»
- **Hierda** (st04#718): Gentle active hope, prayer as a bond rather than a miracle guarantee. «Но, молясь, мы будем думать друг о друге.»


### Further recurring MT voices and early-scene conventions

| Персонаж | Голос | Сцена и точная реплика |
|---|---|---|
| Веллив | Вежливая, холодная, умеет колоть комплиментом | 02_beg #475: «Так рассудительны, что почти скучно.» |
| Экстра | Недоверчивая, язвительная, защищает ребёнка; имя не переводится словом «Лишняя» | 02_beg #267: «Мама тут ни при чём. Я сама взяла это имя, когда забеременела. Кто ещё кому лишний!» |
| Эрменгарда | Учтивая, чуть игривая угроза; с ребёнком сразу мягче | 05_beg #38: «Если запутаются, можете перерезать нити рогами. Только кто знает, в какое измерение моя нить вас тогда утащит?» |
| Эвигегнаде | Величаво, но лично и с лёгкой снисходительной иронией | 05_beg #213: «Пожалуй, не <i>совсем</i> немедленно.» |
| Михаэль | Осторожная почтительность, сбивается перед императрицей | 05_beg #179: «В-Вы спрашиваете моё мнение?» |
| Эзелл | Смущённая забота, без показного героизма | st01 #279: «Ни сливок, ни сахарной посыпки не нашлось, поэтому сверху сушёные овощи. Постарался выбрать покрасивее...» |
| Сесилия | Детская прямота, благодарность, уважительное Вы к защитнику | st01 #287: «Но сегодня я хочу... задуть свечи вместе с Вами.» |
| Тила | Сдержанная лояльность и твёрдая деловая уверенность | st01 #171: «Не радуйся раньше времени.» |
| Вудро | Немолодой, упрямый, отмахивается от тревоги о себе | st01 #218: «Нельзя отдавать всё огню, когда здесь наконец жизнь налаживается... Всё со мной хорошо, правда...» |
| Агнир | Усталое спокойствие, ироническая трезвость старого священника | st01 #97: «Мы пережитки ушедшей эпохи, Сицилия. Сама знаешь, у стариков бывает чутьё на некоторые вещи.» |

The anonymous confessional voice in MT01_end and MT03_beg is the male Doctor,
revealed in MT06_beg. Earlier agreement and Вы were reviewed after that reveal.
The anonymous woman in MT04_end #400–488 is Patia (same figure_art as MT08_end).
Do not infer Romya/Giselle's sex just from names, or assign a sex to the grieving
Kuranta from a generic sprite. Neutral phrasing is used where EN gives no answer.
Gia, Galena and Sister Gerain are female. Vannini/Vani is explicitly female;
Arborbeast's fledgling is male and its mother female. The speaking fledgling later
voices information from the Law through Andoain's mind, not a resurrected animal.
The Presence, Rhine staff and the frantic youth do not acquire an invented sex.

Additional named relationships:
- Agenir ↔ Sicilia, Blacksteel colleagues, and Jessica/Helena/Woodrow use ты;
  Blacksteel staff address Cliff with Вы. Ezell → Cecelia ты; she → Ezell Вы.
- Patrizion → Lemuen uses formal Вы in MT01_beg, then familiar ты at the family
  gathering (MT02_end #452); Lemuen continues Вы. Patrizion ↔ Amos uses Вы
  in the interview/appointment (MT06_end). Mostima → Patrizion Вы, reverse ты.
- Velliv ↔ Lemuen/Amos/Patrizion uses Вы. Administrative courtesy remains in
  Velliv's conflict with Lemuen (MT05_end #138–171). Federico/Arturia ↔ Hildegard
  uses Вы. Federico ↔ Richele is ты, except the explicitly official withdrawal
  instruction at MTst02 #63; he is back to тобой at #179.
- Paganini ↔ the unknown Gun-Knight uses Вы during official detention (MT05_end);
  the unknown knight is not simply treated as his old friend Patrizion.
- Extra → Matriarch ты, reverse Вы: patient pastoral persuasion, not a coercive
  interrogation. Nurturer ↔ Hildegard keeps doctrinal, official Вы in MT07_beg.
- Ermengarde → Cecelia ты, reverse Вы; Ermengarde → Fremont Вы/учитель,
  reverse ты. Ewigegnade → Michael ты, reverse Вы.

Fiammetta's assigned duty name Shimmering Vigil («Мерцающее бдение») and
Austere Authority/Eternal Grace («Суровая власть»/«Вечная благодать») are
translated titles; Grimmacht/Ewigegnade remain transliterated personal names.
Cliff's nickname Clip is transliterated «Клип», not meaning-translated.
Oracle is Оракл as a codename; machine identifier ORACLE stays literal.

Nueda's repeated hymn uses identical wording across memories and present scenes:
«Там земля не таит в себе бомб♪ / Там поля дарят золотую пшеницу♪ /
Обитель Господа, источник родительской любви♪ / Он слышит молитвы, исполняет
желания♪ / Каждого согреет Его любовь♪ / Даже безногого, даже безрукого♪»
(MTst01 #424–429; the slashes here only mark separate source lines).
Lord in the hymn is Господь; Law in doctrinal/technical speech is Закон.
Understandable Latin greetings, farewells and insults are translated with their
inline tags intact; their communicative meaning, not foreignness, matters here.


### Final editorial and delivery verification for this addition

All 9646 Russian texts were reread separately from EN; an independent reviewer
also read all 24 MT scenes and the first eight HE scenes against the shared
character/relationship map. Concrete grammar, omitted connective text, titles,
inflections and interrupted speech were corrected. An extra review compared
EN sentence-final interruption dashes with RU and surrounding dialogue: actual
interruptions keep —, while narrative introductions may use a colon and breaths
or nonverbal sounds retain natural punctuation. No lint requirement was relaxed.

Documents used: `translations/README.md`, `_RULES.md`, `_STYLE.md`,
`_GLOSSARY.json`, `docs/DATA_AND_CONTENT.md` and `docs/DEVELOPMENT.md`.
`flutter test --no-pub test/ru_test.dart` passed all 15 tests. These tests and
structural comparisons do not constitute a manual reader/VN/offline test;
that device-level check was not performed in this translation task.


Release data: generated index **v19**, 310 overlays in total (267 unchanged plus
43 new). Both index copies and canonical SHA-1 values were verified against all
authoring files and the generated tree. The full gender audit returns 1 with
70 gender candidates and four old place-name candidates: 50 findings predate
this addition; the 24 new findings (7 HE, 17 MT) are the contextual false positives
listed above. No source is missing and stderr is empty. The status is not reported
as an unqualified lint pass. Publishing requires pushing the complete data set,
purging jsDelivr, and verifying the live index plus all 43 new overlay hashes.


## Guide Ahead (act16side) — translation map

The supplied EN archive contains 18 storyTxt scenes and 3140 visible texts.
All displayed IDs, props and attributes were compared with both live sources
used by the application (m31ns and 050644zf/ArknightsStoryJson); they match.
Authoring follows README, `_RULES.md`, this style guide, `_GLOSSARY.json`,
`docs/DATA_AND_CONTENT.md` and `docs/DEVELOPMENT.md`.

### Names, voices and recurring language

Guide is Проводник, as already used for Andoain in MT. Astray and Pathfinders
are group names and remain Latin; do not turn the plural Astray into a personal
nickname. Proper places, institutions and the Caprinae label remain Latin.
Commandments are Заповеди, Revelation is Откровение; the Law is Закон.
Keep patron firearm (личное оружие) distinct from guardian gun (оружие-хранитель),
including the child's use of the latter. Mister Friar is «брат монах» in Cecelia's
respectful, childlike speech. Ordinary clergy are монах/сестра; no invented name.
Shimmering Vigil and the three alternative temporary duty titles are translated
as titles; Fiammetta's personal name remains Фиамметта.

Sciurus and Yucatan are a married couple (st02 #63); Rus is her familiar short
name, Рус. Feoria La Porta is Cecelia's mother. Lemuel / El is Exusiai, distinct
from Lemuen. The Apostolic Knight label covers Giovanni, Talvadore and Paolario,
not one unnamed speaker; the later Friar is not necessarily Andoain.
Cecelia narrates 06_end #7–19; Ezell narrates the approach to the tower at
#139–158 and the internal monologues in 02_beg/02_end/03_end. Andoain narrates
05_end #537–539 and the long descent in 07_end. The unnamed perception at
05_end #215–216 has no explicit speaker and uses neutral agreement. Fiammetta narrates
her memory in 08_beg #204–232; the opening account of Andoain is Lemuen's.

### Relationships and deliberate exceptions

- Cecelia addresses adults with Вы; adults address her with ты. Her mother
  and she use ты. Ezell addresses Fiammetta, Mostima and senior officials with
  Вы; Fiammetta and Mostima address the trainee with ты. Avoid importing the
  adult-operator/Doctor rule into conversations in which the Doctor is absent.
- Fiammetta, Mostima, Lemuen and Andoain use ты with their former squadmates;
  Fiammetta and Patia also use ты. Legati colleagues, Oren/Velliv and
  Mostima/Velliv use ты in their sharp personal banter. The Pope addresses
  individuals with ты, while they address him with Вы. Speeches to groups
  use genuine plural вы.
- Sciurus/Yucatan use ты with each other; they and Ezell use Вы.
  The diplomatic quarrel with the duchess keeps official Вы despite hostility
  (01_beg #67–100): forms of address and a formal demand for an apology are
  the instruments of this dispute. Oren does not turn it into street threats.
- Ezell and Andoain keep mutual Вы in the theological conversations
  (04_beg #209–277, 05_beg #147–163, 06_beg #47–135). Suspicion coexists with
  pastoral hospitality and reasoned disagreement; this is deliberate courtesy,
  including Ezell's firm request to leave with Cecelia. Patia and Rosella
  address their Guide with Вы; he addresses individuals with ты.
- Oren initially uses mock-official Вы to Ezell in 02_end #333–350, then
  shifts to patronizing ты at #356. Ezell initially addresses the purported
  official with Вы; their open confrontation in 06_beg uses ты in both
  directions. Ezell and Patia use ты after her disguise is exposed.
- Federico addresses Oren with procedural Вы throughout the arrest
  (06_beg #398–402, 07_beg #115–131); Oren uses ты back.
  The unknown speaker in 04_beg #298–320 also receives procedural Вы; the
  sprite differs from Oren, so no identity is assigned beyond the EN text.
  This follows Federico's established official voice, as in HE. Their familiar
  ты returns in the post-investigation exchange in st02. Velliv addresses
  Federico/Ezell with ты; they address her with Вы. Velliv and Lemuen keep
  mutual Вы, consistent with their professional relationship in MT.
- Andoain addresses the Pope with Вы even in the confrontation in 07_end:
  #83–84 and #235 deliberately enumerate the official titles in a pointed
  theological challenge. The Pope keeps the fatherly ты. Their duel does not
  reset these voices. This exception follows the scene, not rank alone.


The event has no decisions or stickers: coverage consists of 3008 name/content
texts (including unlabelled narration) and 132 subtitle texts. The only newline
escape is literal `\n` in `01_beg #248`, not an actual newline. Preserve it.
The exact Sarkaz song shared by the 05_end recollections and singers is:
«Ветры высоких холмов...♪ За героем летят далеко...♪ По долгим дорогам...♪
Сквозь терния и шипы...♪»; #531 and #533 divide the same lyrics between voices.
Fiammetta and Richele initially use mutual Вы (02_beg #492 introduces him).
Federico/Richele and Federico/Ezell use familiar ты outside formal detention.
Laterano may refer to the country or the city. Keep the grammatical referent
consistent within an exchange: the closing city imagery uses masculine
«сам Laterano», «он стоит», «его двери», while «вся Laterano» may denote the
country. Do not mechanically change pronouns across these different contexts.

### Guide Ahead voice examples and final review

The examples below are exact lines from the authoring overlays; scene names
are relative to `level_act16side_*.json`.

| Персонаж | Голос | Сцена и точная реплика |
|---|---|---|
| Сциурус | Прямая, нетерпеливая, ироничная; в дипломатическом споре сохраняет форму | 01_beg #17: «Но не до такой же степени, чтобы всё подряд было сладким!» |
| Юкатан | Спокойный, дипломатичный; с женой мягкая ирония | 01_beg #26: «Что до меня, Рус, мне вполне достаточно видеть, как сияешь ты.» |
| Феория | Угасающая, нежная мать; повторы и недоговорённость без взрослой риторики в устах ребёнка | st01 #84: «Как же маме не хочется тебя оставлять.» |
| Элиза | Быстрая, болтливая, постоянно отвлекается; больничные сплетни без злобы | 01_beg #183: «На чём я остановилась? Приём у педиатра? Слушайте, на прошлой неделе...» |
| Шэрон / герцогиня Фрэнсис | Высокомерная дипломатическая учтивость, презрение без уличного сленга | 01_beg #65: «Думаете, посланница ничтожной ледяной страны вправе дерзить мне, герцогине?» |
| Розелла | Заботливая, сдерживает собственную горечь ради ребёнка | 04_end #144: «Сегодня ночью я побуду с тобой в маминой комнате, хорошо? Мы все будем рядом. Ты не останешься одна.» |
| Эзелл | Обычный молодой сотрудник, смущённый и испуганный, но верный обещанию | 06_beg #83: «Стыдно признаться, но всё это время я строил перед ней героя. Говорил, что держу слово, что мне не страшно потерять работу...» |
| Сесилия | Простые прямые вопросы; горе выражено конкретным желанием | 02_end #314: «Я ещё с ней не попрощалась.» |
| Андоайн | Спокойная пастырская речь, конкретные истории вместо готовых ответов | 05_end #519: «Вопросы всегда задают живым.» |
| Фиамметта | Резкая, практичная; заботу прячет за деловитостью и раздражением | st02 #241: «Думаешь, мир вокруг тебя вертится? Нам просто по дороге.» |

All 18 EN scenarios were read in full before translation. Each translator
reread the assigned RU separately; the integrating reviewer independently read
all 3140 RU texts against the scene and relationship map. Repeated quotations,
the song, interruption boundaries, short markers and unusually unequal EN/RU
lengths were checked by ID. There are no missing or extra displayed IDs, no
decision options, and no brace tokens or inline tags in these scenarios.
The sole literal newline escape is preserved. Untranslated whole texts are
the proper names `Kjerag?`, `Stevonus.` and `Astray.`. Generic NPCs without
reliable textual sex evidence use neutral first-person constructions; a
grammatical speaker label is not evidence of a character's biological sex.

The full gender audit returns 1: 77 gender candidates and four older place-name
candidates. Of these, 74 findings predate Guide Ahead. The seven new findings
are contextual false positives, reviewed with the EN and adjacent dialogue:

- `level_act16side_01_beg.json #264`: Ezell's «ты потеряла» addresses Cecelia;
  his own «я не нашёл и привёз» is masculine.
- `level_act16side_01_end.json #337`: Patia's «должен/обязан» belongs to the
  generic «каждый либери», not to the female first-person speaker.
- `level_act16side_02_beg.json #71`: Cecelia's «кое-кто пришёл» describes the
  male executor; her own «я с ней разговаривала» is feminine.
- `level_act16side_03_end.json #290`: Ezell's «ты снова увидела маму» addresses
  Cecelia, not himself.
- `level_act16side_03_end.json #307`: the female citizen's «папа ... говорил»
  describes her father.
- `level_act16side_05_beg.json #203`: Cecelia's «брат монах сказал» refers to
  Andoain, not herself.
- `level_act16side_06_end.json #403`: Lemuen's «он ... хотел» refers to Andoain;
  her own «я бы ... не простила» is feminine.

No EN source was skipped and audit stderr is empty. Audit sex mappings were
extended only for identities established in this event; no heuristic was
weakened or warning suppressed. The audit is not described as an unqualified
lint pass. `flutter test --no-pub test/ru_test.dart` passed all 15 tests.
Manual reader/VN/fallback/offline checks were not performed: the user elected
to finish without the previously requested device-level check.

Guide Ahead release data: index **v20**, 328 overlays (310 unchanged and 18 new).
Both index copies are byte-identical. Every generated overlay equals its
authoring JSON and its canonical SHA-1 matches the index; the generated tree
has no stale paths. Publication comprises the 18 authoring files, 18 generated
files, both indices, glossary, rules, this guide and event-local audit mappings.
Delivery requires publishing this complete set to `main`, purging the index
and all 18 new overlays, and comparing the live CDN objects and hashes.

### Guide Ahead — contextual revision, 2026-11-07

All 18 scenes / 3140 EN–RU text pairs were reviewed again for contextual meaning,
following the explicit semantic-review procedure in `AGENTS.md`. This revision
corrects 27 lines in 13 scenes. It distinguishes funeral soul-guiding from
salvation, physical roughness from verbal rudeness, disagreement from opposing
allegiances, bargaining value from personal power, and code names from ranks.
It also restores degrees of certainty, reactions to danger, and the imagery of
light, while removing literal idiom renderings and awkward collocations.
The unusual salty sunlight and the metaphorical crossing were checked and kept;
only the unsupported foreknowledge in «заведомо» was removed from the latter.

Related formulations must remain consistent: `07_beg #200` refers to remaining
true to one's principles; `st02 #347–349` answers that ethical question, without
the unintended association of «честная женщина» with sexual respectability.
Fiammetta's whispered `03_beg #344` concerns being left to look after a child,
not carrying her: the preceding complaint about tired arms is her outward excuse.

Three deliberate clarifications use the supplied Chinese scenario where EN
obscures or changes the action. They are not ordinary RU-versus-EN mismatches:

- `03_beg #245`: CN `给你报个信` means warning Oren after Federico leaves;
  EN "put in a report for you" led to an inappropriate formal report.
- `08_beg #191`: CN `为抱薪者端上一杯热茶` offers tea to the one carrying
  firewood for others, continuing the torch imagery; EN "functionary" loses it.
- `st02 #349`: CN `为了高尚的人而付出努力` is making an effort for principled
  people. EN instead speaks of respecting people who earned that description.
  RU now preserves the CN action and its connection to Ezell's next question.

Displayed IDs, names maps, markers and markup remain unchanged. The EN overlay
paths and IDs remain the application contract; CN is supplementary evidence for
these documented semantic choices. No source or generated file was renumbered.

Revision validation: index **v21**, 328 overlays; exactly 13 changed and 315
unchanged. Both indices are byte-identical and all generated canonical JSON
objects and SHA-1 hashes match the authoring sources. Full ID/marker/token/tag/
newline checks pass for all 18 Guide Ahead scenes. Repeated lines and interrupted
speech remain consistent; each edited passage was reread with its neighbours.
The full audit still reports the same 77 gender candidates and four older place
candidates, with no missing EN source or stderr. The seven Guide Ahead candidates
remain the contextual false positives documented above. No app code or format
changed; manual reader/VN/offline checks remain unperformed under the user's
earlier decision to finish without that check.


### Main story — contextual review conventions, 2026-11-07

- `core city` is **городское ядро**, the independently moving central part of
  Chernobog, not a capital city. `landship` is **сухопутный корабль**, not an
  amphibious landing vessel. **Azazel** is the clinic's proper name and remains
  Latin, including recollections in episodes 1 and 7.
- Amiya deliberately retains conciliatory **Вы / госпожа** toward FrostNova,
  even before combat (`06-13_end #273`; `06-14_beg #555, #580, #628, #685`).
  English *Miss FrostNova* and Chinese 小姐 support the courtesy. FrostNova
  addresses Amiya with **ты**. This does not change the separate mutual **ты**
  rule for Doctor and FrostNova.
- Mephisto's **Вы** to Ch'en is mocking ceremony (`05-09_end #48, #207`;
  `05-10_beg #7, #13, #303`), including *dear Madam* and the invitation to kill
  him. His loss of composure becomes **ты** in `05-10_end #11`. Do not force
  the courteous taunts into the same register as that outburst.
- The old voice example `03-02_end #132` belongs to Skullshatterer, not Kal'tsit;
  her registry row now quotes her actual speech in `07-02_end #214`.
- Mephisto also performs mock-professional courtesy toward Dobermann
  (`00-08_beg #78, #83`); W's pointed **Вы / госпожа** to Ch'en in
  `03-05_end #45` is a teasing parting gift, while her direct threats use **ты**.
- Amiya initially approaches Misha as **Вы / мисс Миша** (`02-03_end #15–63`),
  then shows her own infection and moves to **ты** at #71. Later conversations
  retain that personal connection. Do not apply the first meeting's distance
  to the whole arc.
- In `03-08_beg #79, #80, #140`, **Skullshatterer is Misha wearing the armour**;
  feminine agreement is required despite the normally male speaker label.
  The medic in the opening rescue is explicitly female in `01-06_beg #190`.
  Generic `Guard` labels still require their own scene evidence.
- Current EN calls Ch'en's unit the **Special Inspection Unit**, consistently
  translated **Отдел специальных расследований**; older **Special Ops Division**
  (including the typo **Divison**) denotes the same unit in these scenes.
  New speaker aliases **Medic Operator** (`04-06_end #65`) and **L.G.D. Officer**
  (`05-09_beg #51, #70`) are mapped alongside the archive's older labels.

Explicit CN clarifications in this review include the moving core in
`07-06_beg #119` (CN says it still operates and moves, where EN incorrectly
says movement is impossible), and Patriot's family in `st_06-02 #240`
(his wife died; he and his son remained together, not a son surviving his
father's death). `st_06-02 #245` orders his unit to maintain public order,
not discipline within its own ranks. `st_06-01 #185` rejects a predetermined
reason for living rather than declaring life meaningless. In `st_06-03 #70`
Ch'en risks opposing Lungmen, not reaching the afterlife; #365 concerns
fulfilled contractual obligations, not due diligence. Detailed before/after
records retain the source wording and context for each correction.


Additional episode 7 register exceptions: Patriot addresses Kal'tsit with
**Вы / Госпожа** as an old associate of Theresa (`07-16_beg #15, #27, #55,
#72`); Kal'tsit uses **ты**. Amiya and the Doctor retain respectful **Вы** to
Patriot while trying to reconcile and recognising his service and death
(`07-16_end #63, #300, #315, #355`). Kal'tsit's **Вы** to the Infected Ursus
refugee (`07-08_beg #121, #123`) is a formal inquiry, not an enemy threat.
The `07-07_end #7` time remains **00:40**: both EN and CN explicitly say
12:40 a.m.; the apparent conflict with an earlier 11:30 is retained as source
ambiguity rather than silently changed to midday.

### Heart of Surging Flame — contextual review exceptions, 2026-11-07

Hellagur's professional assessment of Schwarz uses restrained **Вы** even
in confrontation (`04_beg #52`). Ceylon's unusually polite **Вы** to Ifrit
(`03_end #25, #30`) is explicitly noticed by Ifrit at #33; the child's age
is not grounds to remove this characterisation. Skyfire addresses the newly
met Ceylon with **Вы** (`01_end #62`, `st02 #51`).
Ceylon retains formal **Вы** when presenting the accusation to Cronin
(`06_end #109`, `st04 #11`). Cronin's courtesy to Herman before his dismissal
(`st04 #62, #87–93`) gives way to hostile **ты** in the threats after #98.
The Doctor's hostile replies to the exposed conspirator use **ты**
(`06_end #102`, `07_beg #40`); Cronin's threat to Herman about Ceylon's death
also uses **ты** (`07_end #94`).


### Operational Intelligence — contextual review, 2026-11-07

Mayer is female (ST06 CN 梅尔姐); **Майер** does not take masculine declension.
Executor's **Вы** to Vermeil persists through detention (`st04 #247, #272,
#292, #310`): he addresses the beneficiary of a will in a mechanical official
voice, consistent with Federico's later procedural exchanges. Ifrit and the
Doctor use **ты** in the domestic lesson (`st05 #62–66, #575–580, #608`):
her blunt childlike familiarity is intentional, not a formal briefing.
The medic in ST05 is a woman (#144, #607). The internal monstrous voice
at #649–653 has no established sex; neutral phrasing avoids inventing one.

Important EN/CN discrepancies are documented in the review records. In ST01,
Hellagur is living under an assumed identity (#142), not literally underground;
Patriot points out his continuing ties to the past (#157). The lone warrior
is fighting Sarkaz mercenaries (#311), while hostile civilians refuse to see
Infected as compatriots (#316). Earlier emperors also **could not** escape
fate (#513). These corrections restore the Chinese actions and negations
rather than preserve contradictory English wording. The lower city at #260
is genuinely 下城区 and must not be mechanically replaced by a satellite city.
ST02 #310 addresses Flamebringer with a title; it does not make him the planner
of the conspiracy described in the same sentence.

### Darknights Memoir and Children of Ursus — continuity

In Darknights Memoir the mercenary who first carried the name W is a man;
the woman who takes his equipment and name is the W we later follow. The
mask Theresa discusses in `03_beg #283` is the identity W has adopted, not
an instruction about the disguise Ines uses to pass for a Sarkaz
(`04_beg #233`). Keep these separate even when the English images coincide.

In Children of Ursus the members of the Ursus Student Self-government Group
are schoolchildren. Keep the full official name as listed in the glossary
(`st01 #884`, `st03 #430, #436`); ordinary references such as “our group”
are not titles. Preserve the reveal of Valeria's name in `st03 #146`: the
speaker is identified only as «Затравленная ученица» until she introduces
herself. Vika's plea to Anna, «Подтяни меня, Аня» (`st02 #102, #625`), is
a remembered line and must remain recognisable when it recurs.

The four visibly corrupted speaker labels in `main_05-09_end #118, #120,
#123, #128` change as the soldier loses the ability to speak. The glossary
keeps a separate spelling for each stage. Use «Боец Reunion» and
«Стадо Мефисто» for the ordinary, undistorted labels.

In Il Siracusano preserve the Italian names of the two ministries and the
food safety department listed in the glossary. When a speaker says only
“the ministry”, “my department” or names the minister's job, translate that
description normally (`05_end #40–46`). Blood ties and affiliation need
not coincide: `06_beg #266–270` is a question about resemblance and
parentage; `06_beg #466` concerns Famiglia Texas as an organisation.

In Hortus and The Masses' Travels distinguish **the Lateran**, the governing
institution, from **Laterano**, the country or destination. In HE `01_end
#313` someone notified the authorities; in `02_beg #307` the authorities
set conditions for travel to Laterano. English distinguishes these even
where Chinese uses the same shorter name. The ordinary adjective “Lateran”
before a person, custom or dish does not by itself denote the institution.

Track the children's hymn in The Masses' Travels across scene boundaries,
including the lines presented as subtitles. The shared refrain in ST01
#467–470 returns at 09_beg #335–338. Its stones grow on people's bodies;
they are not objects someone carries. The comparison of the Lord's love
to a mother's is explicit in CN. Preserve the shared words and the music
mark, while letting the interrupted verses break off where the source does.

The [v22 contextual review](../reviews/ru-v22-context.md) records the coverage
of all 328 scenes, the before/after text for each correction, and the context
of the remaining automated warnings. The 18 Guide Ahead scenes retain their
previously reviewed v21 text.
