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
| `lib/data/servers.dart` | `settings.ts` | `servers` list + `baseServer` (server constants only) |
| `lib/data/audio.dart` | `audio.ts` | `resolveSound` (pure) + `loadSoundMap` via `http` (offline fallback TODO) |
| `lib/data/menu.dart` | `menu.ts` | `buildMenu`/`classify`/`mainOrder`/`neighborsIn` + fetch (persistent cache TODO) |
| `lib/data/guide.dart` | `guide.ts` | matching logic (`norm`/`resolveGuide`/`buildGuide`/`describeGuideLocation`/`localizeNote`); data from `assets/guide_data.json` |
| `assets/guide_data.json` | `guide.ts` `ARCS`+`NOTE_RU` | **generated** from the TS (no hand-transcription) |
| `lib/stores/kv_store.dart` | — | `KeyValueStore` abstraction (localStorage stand-in) + shared_preferences/in-memory impls |
| `lib/stores/settings_store.dart` | `settings.ts` | `SettingsState` (immutable + copyWith) + `ChangeNotifier` store |
| `lib/stores/progress_store.dart` | `progress.ts` | read status / scroll / last-read; `summarize` aggregation |
| `lib/stores/offline_store.dart` | `offline.ts` | downloaded-chapter index (`reconcile`'s filesystem source deferred) |
| `test/parse_test.dart` | — | Unit harness (speaker model, branching, scene breaks, URL builders) |
| `test/stores_test.dart` | — | Unit tests for all three stores (behavior + persistence round-trips) |
| `test/menu_test.dart`, `test/audio_test.dart` | — | Unit tests for the menu transform + sound resolution |
| `test/golden_test.dart`, `test/guide_test.dart` | — | **Parity tests** — Dart output vs the real TS on real data (parser: 962 items; guide: all 16 arcs) |

Golden fixtures live in `test/fixtures/` (`*.input.json` = real story data,
`*.golden.json` = canonical output captured from the original TypeScript
`normalizeStory`). Regenerate with `npx tsx tool/gen_golden.ts` (needs the
original TS project; see paths in that script). Verified: `flutter analyze`
clean, all 19 tests pass (Flutter 3.44.6 / Dart 3.12.2).

**Not yet ported:** `chapterImages.ts`, `backgrounds.ts` (both need the Flutter
asset pipeline — `import.meta.glob` has no Dart equivalent; `backgrounds` now only
needs the banner assets, since `EpisodeNode` is ported), `downloads.ts`,
offline/filesystem (`localstore.ts`/`offline.ts` → rebuild on `path_provider` +
`dart:io`), i18n, and **all UI** (Guide / Story / VN reader / Home / Settings).

**Deferred TODOs in ported code:** `menu.fetchMenu` persistent cache +
revalidate + offline fallback; `audio.loadSoundMap` offline fallback;
`OfflineStore.reconcile` (filesystem source). All wait on the localstore port.

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
