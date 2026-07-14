// Generate the guide data asset + logic golden fixtures from the REAL TS guide.
//
//   npx tsx tool/gen_guide_golden.ts
//
// Outputs:
//   assets/guide_data.json            = { arcs: ARCS, noteRu: NOTE_RU } (source of truth)
//   test/fixtures/guide_categories.json = categories input (built from the real table)
//   test/fixtures/guide_build.golden.json = buildGuide(categories) canonicalized
//   test/fixtures/guide_locations.golden.json = describeGuideLocation for sample txts
//
// guide.ts imports menu.ts only as `import type`, so it loads standalone here.
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { pathToFileURL } from "node:url";

const GUIDE_TS =
  "C:/Users/Rodney/Desktop/ArknightsReaderAPK/ArknightsStoryTextReader/BetterPhoneReader/src/data/guide.ts";
const REPO = "C:/Users/Rodney/Desktop/AKReaderFlutter";
const TABLE_URL =
  "https://r2.m31ns.top/en_US/gamedata/excel/story_review_table.json";

// --- minimal, inline copy of menu.buildMenu (just to produce realistic
// categories input; the SAME output is saved and fed to both TS and Dart, so its
// exact fidelity doesn't affect the parity check). ---
const INTERMEZZI = new Set([
  "act9d0", "act18d0", "act18d3", "act17side", "act25side", "act33side", "act37side",
]);
const LABELS: Record<string, string> = {
  maintheme: "Main Story", sidestory: "Side Story", intermezzi: "Intermezzi",
  storyset: "Story Set", records: "Operator Records",
};
function classify(id: string, t: string): string {
  if (t === "MAINLINE") return "maintheme";
  if (t === "ACTIVITY") return INTERMEZZI.has(id) ? "intermezzi" : "sidestory";
  if (t === "MINI_ACTIVITY") return "storyset";
  return "records";
}
const mainOrder = (id: string) => Number(/(\d+)/.exec(id)?.[1] ?? 0);
function buildMenu(table: Record<string, any>) {
  const buckets: Record<string, any[]> = {};
  for (const id of Object.keys(table)) {
    const ev = table[id];
    const cat = classify(id, ev?.entryType);
    const stories = (ev?.infoUnlockDatas ?? [])
      .filter((s: any) => s?.storyTxt)
      .map((s: any) => ({ txt: s.storyTxt, code: s.storyCode ?? "", name: s.storyName ?? "", tag: s.avgTag ?? "" }));
    if (!stories.length) continue;
    (buckets[cat] ??= []).push({ id, name: ev?.name ?? id, startTime: ev?.startTime ?? 0, stories });
  }
  const order = ["maintheme", "intermezzi", "sidestory", "storyset", "records"];
  return order.filter((k) => buckets[k]?.length).map((k) => {
    const events = buckets[k];
    if (k === "maintheme") events.sort((a, b) => mainOrder(a.id) - mainOrder(b.id));
    else events.sort((a, b) => a.startTime - b.startTime);
    return { key: k, label: LABELS[k] ?? k, events };
  });
}

function canonNode(n: any) {
  return {
    title: n.title,
    optional: !!n.optional,
    is: !!n.is,
    lead: n.lead ?? null,
    note: n.note ?? null,
    event: n.event ? { id: n.event.id, name: n.event.name } : null,
    subStories: n.subStories
      ? n.subStories.map((s: any) => ({ name: s.name, txt: s.txt ?? null }))
      : null,
    isEpisode: n.isEpisode ?? null,
    episodeIndex: n.episodeIndex ?? null,
    forceOptional: n.forceOptional ?? null,
  };
}
const canonStoryline = (s: any) => ({
  name: s.name, main: s.main, status: s.status, nodes: s.nodes.map(canonNode),
});

(async () => {
  const guide = await import(pathToFileURL(GUIDE_TS).href);
  mkdirSync(`${REPO}/assets`, { recursive: true });
  mkdirSync(`${REPO}/test/fixtures`, { recursive: true });

  // 1. data asset (source of truth for the Dart port)
  writeFileSync(
    `${REPO}/assets/guide_data.json`,
    JSON.stringify({ arcs: guide.ARCS, noteRu: guide.NOTE_RU }),
  );

  // 2. categories input (from real table)
  const table = await (await fetch(TABLE_URL)).json();
  const categories = buildMenu(table);
  writeFileSync(`${REPO}/test/fixtures/guide_categories.json`, JSON.stringify(categories));

  // 3. buildGuide golden
  const built = guide.buildGuide(categories);
  writeFileSync(
    `${REPO}/test/fixtures/guide_build.golden.json`,
    JSON.stringify({
      mainArcs: built.mainArcs.map(canonStoryline),
      sideStorylines: built.sideStorylines.map(canonStoryline),
    }),
  );

  // 4. describeGuideLocation golden for a few sample txts (first story of the
  // first event-bearing node in a couple of storylines).
  const pickTxt = (nodes: any[]) =>
    nodes.find((n) => n.event && n.event.stories.length)?.event.stories[0].txt;
  const txts = [
    pickTxt(built.mainArcs.flatMap((a: any) => a.nodes)),
    ...built.sideStorylines.slice(0, 3).map((s: any) => pickTxt(s.nodes)),
  ].filter(Boolean);
  const locations = txts.map((txt: string) => ({
    txt,
    location: guide.describeGuideLocation(built, txt, "Main Story"),
  }));
  writeFileSync(`${REPO}/test/fixtures/guide_locations.golden.json`, JSON.stringify(locations));

  console.log(
    `guide_data: ${guide.ARCS.length} arcs, ${Object.keys(guide.NOTE_RU).length} notes | ` +
      `categories: ${categories.length} | mainArcs: ${built.mainArcs.length}, ` +
      `side: ${built.sideStorylines.length} | locations: ${locations.length}`,
  );
  console.log("done");
})();
