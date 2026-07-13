# AK Reader — Flutter port (in progress)

A native rewrite of `../BetterPhoneReader` (Vue 3 + Vite + Capacitor/WebView) in
Flutter, to escape the WebView's rendering ceiling and get consistent
high-refresh-rate scrolling/animation across devices.

## Strategy: data layer first

We port the **pure logic to Dart and validate it before building any UI**, so
correctness is locked in while the existing Vue app keeps shipping. Only once the
data layer matches the TS output do we start rebuilding screens.

## Status

**Phase 1 — data layer (started):**

| Ported | From (TS) | Notes |
|---|---|---|
| `lib/data/models.dart` | `parse.ts` types | Discriminated union → Dart 3 `sealed` classes |
| `lib/data/parse.dart` | `parse.ts` | `parseContent`, `mergeAltStory`, `normalizeStory` — line-for-line |
| `lib/data/source.dart` | `source.ts` | URL builders (pure) + `getData`/`getJson` via `package:http` |
| `test/parse_test.dart` | — | Unit harness (speaker model, branching, scene breaks, URL builders) |
| `test/golden_test.dart` | — | **Parity tests** — Dart output vs the real TS parser on 3 real chapters (962 items) |

Golden fixtures live in `test/fixtures/` (`*.input.json` = real story data,
`*.golden.json` = canonical output captured from the original TypeScript
`normalizeStory`). Regenerate with `npx tsx tool/gen_golden.ts` (needs the
original TS project; see paths in that script). Verified: `flutter analyze`
clean, all 19 tests pass (Flutter 3.44.6 / Dart 3.12.2).

**Not yet ported:** `menu.ts`, `guide.ts` (+ data), `audio.ts`, `backgrounds.ts`,
`chapterImages.ts`, stores (`progress`/`settings`/`offline`), `downloads.ts`,
offline/filesystem (`localstore.ts`/`offline.ts`), i18n, and **all UI** (Guide /
Story / VN reader / Home / Settings).

## Toolchain

- Flutter 3.44.6 stable / Dart 3.12.2, installed at
  `C:\Users\Rodney\Documents\FlutterSDK\flutter` (**not on PATH** — prepend
  `...\flutter\bin` to `PATH` per shell, or add it permanently).
- Android SDK at `C:\Users\Rodney\AppData\Local\Android\Sdk`.
- Platform scaffolding (`android/`, `ios/`) already generated via `flutter create .`.

## Build & run

```powershell
flutter pub get
flutter test          # unit + golden parity tests (no device needed)
flutter run           # launch the data-layer smoke screen on a device/emulator
```

`lib/main.dart` is a temporary smoke screen that runs `normalizeStory` on a
sample and lists the parsed items — proof the ported logic works on-device. It
will be replaced by the real UI.

## Next steps

1. Add **golden tests**: capture real `normalizeStory` output from the TS app for
   a few chapters into `test/fixtures/`, assert the Dart output matches item-for-item.
2. Port `menu.ts` + `backgrounds.ts` + `audio.ts` (pure-ish logic).
3. Port the stores to a Dart state solution (e.g. Riverpod/Provider) + local
   persistence (`shared_preferences` / Hive).
4. Rewrite the offline layer on `path_provider` + `dart:io` (much simpler than the
   Capacitor Filesystem + `convertFileSrc` approach).
5. Build screens, reader core first (Story/VN), then Guide, then Home/Settings.
