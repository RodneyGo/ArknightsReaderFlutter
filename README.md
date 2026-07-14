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
| `lib/data/parse.dart` | `parse.ts` | `mergeAltStory`, `normalizeStory` — line-for-line; `parseContent` returns structured `TextRun`s (not HTML) for direct `TextSpan` rendering |
| `lib/data/source.dart` | `source.ts` | URL builders (pure) + `getData`/`getJson` via `package:http` |
| `lib/data/servers.dart` | `settings.ts` | `servers` list + `baseServer` (server constants only) |
| `lib/data/audio.dart` | `audio.ts` | `resolveSound` (pure) + `loadSoundMap` via `http` (offline fallback TODO) |
| `lib/data/menu.dart` | `menu.ts` | `buildMenu`/`classify`/`mainOrder`/`neighborsIn` + fetch (persistent cache TODO) |
| `lib/data/guide.dart` | `guide.ts` | matching logic (`norm`/`resolveGuide`/`buildGuide`/`describeGuideLocation`/`localizeNote`); data from `assets/guide_data.json` |
| `assets/guide_data.json` | `guide.ts` `ARCS`+`NOTE_RU` | **generated** from the TS (no hand-transcription) |
| `lib/stores/kv_store.dart` | — | `KeyValueStore` abstraction (localStorage stand-in) + shared_preferences/in-memory impls |
| `lib/stores/settings_store.dart` | `settings.ts` | `SettingsState` (immutable + copyWith) + `ChangeNotifier` store |
| `lib/stores/progress_store.dart` | `progress.ts` | read status / scroll / last-read; `summarize` aggregation |
| `lib/stores/offline_store.dart` | `offline.ts` | downloaded-chapter index (`reconcile` = `rebuildFrom(localStore.getDownloadedTxts())`) |
| `lib/data/localstore.dart` | `localstore.ts` | filesystem offline store, **rebuilt** on `dart:io`+`path_provider` (no `convertFileSrc`) |
| `test/parse_test.dart` | — | Unit harness (speaker model, branching, scene breaks, URL builders) |
| `test/stores_test.dart`, `test/localstore_test.dart` | — | Unit tests for the stores + the filesystem store (temp dir + fake fetcher) |
| `test/menu_test.dart`, `test/audio_test.dart` | — | Unit tests for the menu transform + sound resolution |
| `test/golden_test.dart`, `test/guide_test.dart` | — | **Parity tests** — Dart output vs the real TS on real data (parser: 962 items; guide: all 16 arcs) |

Golden fixtures live in `test/fixtures/` (`*.input.json` = real story data,
`*.golden.json` = canonical output captured from the original TypeScript
`normalizeStory`). Regenerate with `npx tsx tool/gen_golden.ts` (needs the
original TS project; see paths in that script). Verified: `flutter analyze`
clean, all 19 tests pass (Flutter 3.44.6 / Dart 3.12.2).

## UI (started — main menu)

| File | What |
|---|---|
| `lib/main.dart` | App shell: `MultiProvider` wiring the stores + dark theme + `MenuScreen` |
| `lib/ui/ash_fx.dart` | Ambient ember layer — native reimplementation of `AshFX.vue` (the FPS bottleneck): one `Ticker` → `CustomPainter` in a `RepaintBoundary` |
| `lib/ui/guide_screen.dart` | The guide hub / landing: top control bar (settings / notes / background lightbox / story list) + backdrop + embers + arc rail + vertical `PageView` episode scroller + storyline selector + chapter drill-down (`ChaptersPanel`) + notes panel + `InteractiveViewer` lightbox |
| `lib/ui/guide_controller.dart` | `ChangeNotifier`: fetches menu → `buildGuide`; tracks storyline/arc/focused episode (injectable fetch for tests) |
| `lib/ui/settings_screen.dart` | Minimal settings (doctor name / story language→reloads guide / VN mode / font size) over `SettingsStore` |
| `lib/data/chapter_images.dart` | `chapterImages.ts` | banner lookup by normalized event name + aliases |
| `lib/data/backgrounds.dart` | `backgrounds.ts` | episode/story backdrop lookup + banner fallback |
| `lib/data/image_assets.dart` | (glob replacement) | loads bundled asset paths from `AssetManifest` → the two lookups |
| `assets/{ChapterImages,EpisodeBackgrounds,StoryBackgrounds}/` | — | menu art, **converted PNG→WebP** (112 MB → 19 MB) |

State management = **`provider`** over the existing `ChangeNotifier` stores.

**Not yet ported:** `offline.ts`
(`downloadStory`/`preloadStory` — the download orchestrator that drives
`localstore` + the download queue), i18n, and the rest of the **UI** (notes +
downloads on the guide; the Story / VN reader that a chapter tap opens; Settings).

**Deferred TODOs (now unblocked — `localstore` exists, just need wiring):**
`menu.fetchMenu` offline fallback → `localStore.readMeta`; `audio.loadSoundMap`
offline fallback → `localStore.readMeta`; `OfflineStore.reconcile` →
`rebuildFrom(localStore.getDownloadedTxts())`. These wire up when `offline.ts` is
ported (its natural home).

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
