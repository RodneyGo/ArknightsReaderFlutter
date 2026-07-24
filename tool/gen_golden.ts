// Generate golden fixtures for the data-layer parity tests by running the REAL
// TypeScript `normalizeStory` (from the original BetterPhoneReader app) over
// cached story JSON, then writing a canonical (fully explicit, null-filled)
// representation the Dart golden test diffs against.
//
// Run from anywhere with tsx (Node): `npx tsx tool/gen_golden.ts`
// Requires the original TS project checked out at TS_PARSE below.
//
// RETIRED: the Vue app this reads from is obsolete — the port is finished and
// Flutter is the only reader. The fixtures in test/fixtures/ are committed, and
// test/golden_test.dart reads ONLY those, so the suite does not need the TS
// checkout and nothing breaks if it is deleted. This script exists to document
// how the goldens were produced; it can only be re-run while that checkout is
// still on disk. Treat the fixtures as frozen regression goldens: if Dart
// behaviour must change, hand-edit them and say why, rather than restoring the
// old app to regenerate.
//
// NOTE: paths are absolute to this machine's layout. The canonical `canon()`
// shape MUST stay in sync with `canon()` in test/golden_test.dart.
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { pathToFileURL } from "node:url";

const TS_PARSE =
  "C:/Users/Rodney/Desktop/ArknightsReaderAPK/ArknightsStoryTextReader/BetterPhoneReader/src/data/parse.ts";
const CACHE =
  "C:/Users/Rodney/Desktop/ArknightsReaderAPK/ArknightsStoryTextReader/BetterPhoneReader/scripts/.src_cache";
const OUT = "C:/Users/Rodney/Desktop/AKReaderFlutter/test/fixtures";

const DOCTOR = "Doctor"; // must match _doctor in test/golden_test.dart
const FIXTURES = [
  "level_main_00-04_beg", // decisions, small
  "level_act4d0_st05", // decisions at scale
  "level_act10d5_st05", // image/CG heavy, biggest
];

function canon(it: any) {
  return {
    kind: it.kind,
    id: it.id,
    bg: it.bg ?? null,
    bgImage: !!it.bgImage,
    alt: !!it.alt,
    branch: it.branch ? { group: it.branch.group, refs: it.branch.refs } : null,
    name: it.name ?? null,
    html: it.html ?? null,
    portrait: it.portrait ?? null,
    text: it.text ?? null,
    options: it.options ?? null,
    values: it.values ?? null,
    group: it.group ?? null,
    key: it.key ?? null,
    music: it.music ?? null,
  };
}

(async () => {
  const { normalizeStory } = await import(pathToFileURL(TS_PARSE).href);
  mkdirSync(OUT, { recursive: true });
  for (const name of FIXTURES) {
    const raw = JSON.parse(readFileSync(`${CACHE}/${name}.json`, "utf8"));
    const storyList = raw.storyList ?? [];
    const out = normalizeStory(storyList, DOCTOR).map(canon);
    writeFileSync(`${OUT}/${name}.input.json`, JSON.stringify(storyList));
    writeFileSync(`${OUT}/${name}.golden.json`, JSON.stringify(out, null, 0));
    console.log(`${name}: ${storyList.length} lines -> ${out.length} items`);
  }
  console.log("done");
})();
