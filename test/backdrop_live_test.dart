// Diagnostic: does the main menu backdrop blend BETWEEN episode backgrounds while
// the list is being dragged, or only once the scroll settles?
//
// The backgrounds are seeded with fake asset paths via initBackgrounds, so the
// images never actually decode (errorBuilder swallows that) — but the Image
// WIDGETS still carry the resolved path + opacity, which is what we assert on.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ak_reader/data/backgrounds.dart';
import 'package:ak_reader/data/main_menu.dart';
import 'package:ak_reader/data/menu.dart';
import 'package:ak_reader/data/offline.dart';
import 'package:ak_reader/data/resolved.dart';
import 'package:ak_reader/data/ru.dart';
import 'package:ak_reader/data/trailers.dart';
import 'package:ak_reader/stores/kv_store.dart';
import 'package:ak_reader/stores/offline_store.dart';
import 'package:ak_reader/stores/progress_store.dart';
import 'package:ak_reader/stores/settings_store.dart';
import 'package:ak_reader/ui/main_menu_controller.dart';
import 'package:ak_reader/ui/main_menu_screen.dart';

const _bg0 = 'assets/EpisodeBackgrounds/episode0.webp';
const _bg1 = 'assets/EpisodeBackgrounds/episode1.webp';
const _bg2 = 'assets/EpisodeBackgrounds/episode2.webp';

MainMenu _mainMenu() {
  EventGroup ev(String n) => EventGroup(
        id: n,
        name: n,
        startTime: 0,
        stories: [Story(txt: '$n-1', code: '', name: '', tag: '')],
      );
  EpisodeNode node(String t, int idx) => EpisodeNode(
        title: t,
        event: ev(t),
        isEpisode: true,
        episodeIndex: idx,
        forceOptional: false,
      );
  return MainMenu(
    mainArcs: [
      Storyline(
        name: 'Arc 1',
        main: true,
        status: 'complete',
        nodes: [node('One', 0), node('Two', 1), node('Three', 2)],
      ),
    ],
    sideStorylines: const [],
  );
}

Widget _app(MainMenuController gc) => MultiProvider(
      providers: [
        Provider<ResolvedUrls>(
            create: (_) => ResolvedUrls(MemoryKeyValueStore())),
        Provider<Offline?>(create: (_) => null),
        ChangeNotifierProvider<RuStore>(
            create: (_) => RuStore(store: null, fetch: (_) async => null)),
        ChangeNotifierProvider<TrailerStore>(
            create: (_) => TrailerStore(store: null, fetch: (_) async => null)),
        ChangeNotifierProvider<SettingsStore>(
            create: (_) => SettingsStore(MemoryKeyValueStore())),
        ChangeNotifierProvider<ProgressStore>(
            create: (_) => ProgressStore(MemoryKeyValueStore())),
        ChangeNotifierProvider<OfflineStore>(
            create: (_) => OfflineStore(MemoryKeyValueStore())),
        ChangeNotifierProvider<MainMenuController>.value(value: gc),
      ],
      child: const MaterialApp(home: MainMenuScreen()),
    );

/// Opacity the backdrop is currently painting [path] at, or null if that image
/// isn't in the tree at all.
double? _opacityOf(WidgetTester tester, String path) {
  final images = tester.widgetList<Image>(find.byType(Image));
  for (final img in images) {
    final provider = img.image;
    if (provider is AssetImage && provider.assetName == path) {
      return img.opacity?.value ?? 1.0;
    }
  }
  return null;
}

/// Pump a fixed span of frames. The ember layer animates forever, so
/// pumpAndSettle never returns on this screen.
Future<void> _pumpFrames(WidgetTester tester, {int frames = 60}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  setUp(() {
    initBackgrounds(
      episodePaths: const [_bg0, _bg1, _bg2],
      storyPaths: const [],
    );
  });

  testWidgets('backdrop blends between backgrounds DURING a drag',
      (tester) async {
    // Portrait surface so the scroller runs vertically (wide enough in logical
    // px that the top bar doesn't overflow).
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final gc = MainMenuController()..setMainMenu(_mainMenu());
    await tester.pumpWidget(_app(gc));
    await tester.pump(const Duration(milliseconds: 16));

    // At rest on card 0: episode0 is fully visible, and the NEXT background is
    // already mounted at opacity 0 so its decode is done before it's needed —
    // mounting it late is what made the change appear only at settle.
    expect(_opacityOf(tester, _bg0), 1.0,
        reason: 'first episode background should be fully painted at rest');
    expect(_opacityOf(tester, _bg1), 0.0,
        reason: 'next background must be mounted (decoding) but invisible');

    // Drag part-way toward card 1 and HOLD (no release => no settle).
    // The episode list is the vertically-scrolling one (the storyline selector
    // scrolls horizontally).
    final list = find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down);
    final extent = tester.getSize(list).height;
    final gesture = await tester.startGesture(tester.getCenter(list));
    await tester.pump(); // let the drag win the gesture arena
    // Move in steps, as a real finger does, so each delta is dispatched.
    for (var s = 0; s < 5; s++) {
      await gesture.moveBy(Offset(0, -extent * 0.05));
      await tester.pump(const Duration(milliseconds: 16));
    }

    // The drag must actually move the list, else the rest proves nothing.
    final pixels = tester.state<ScrollableState>(list).position.pixels;
    expect(pixels, greaterThan(0.0), reason: 'the drag must scroll the list');

    // The whole point: WITHOUT releasing, the incoming background is already
    // partly blended in. If this only became visible after settling, the
    // backdrop would be back to its old "changes when it settles" behaviour.
    final mid = _opacityOf(tester, _bg1);
    expect(mid, isNotNull,
        reason: 'MID-DRAG the incoming background must be in the tree');
    expect(mid, greaterThan(0.0),
        reason: 'MID-DRAG the incoming background must be partly visible');

    await gesture.up();
    await _pumpFrames(tester); // AshFx animates forever; never pumpAndSettle
  });

  testWidgets('portrait card title sits directly under the artwork',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final gc = MainMenuController()..setMainMenu(_mainMenu());
    await tester.pumpWidget(_app(gc));
    await tester.pump(const Duration(milliseconds: 16));

    // The artwork is the AspectRatio inside the focused card; the title is the
    // node name below it. Shrinking the portrait artwork once left the title
    // stranded at the bottom of the cell, a ~180px gap away.
    // Scope to one card. Note the artwork placeholder ALSO renders the title
    // (no banner asset in tests), so the real caption is the LAST match.
    final card = find
        .ancestor(of: find.text('One'), matching: find.byType(EpisodeCard))
        .first;
    final art = find.descendant(of: card, matching: find.byType(AspectRatio));
    final title = find.descendant(of: card, matching: find.text('One'));
    final gap =
        tester.getTopLeft(title.last).dy - tester.getBottomLeft(art.first).dy;

    expect(gap, greaterThanOrEqualTo(0.0),
        reason: 'title must sit below the artwork');
    expect(gap, lessThan(40.0),
        reason: 'title must hug the artwork, not float at the cell bottom '
            '(was ~180px when the artwork expanded to fill the cell)');
  });

  testWidgets('portrait episodes sit close together, not a screen apart',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final gc = MainMenuController()..setMainMenu(_mainMenu());
    await tester.pumpWidget(_app(gc));
    await tester.pump(const Duration(milliseconds: 16));

    // Measure ARTWORK to ARTWORK. EpisodeCard fills the whole cell, so adjacent
    // cards are always flush no matter how much dead space is inside them — the
    // empty space the user sees lives within each cell.
    //
    // Cell height was a fixed 0.72 of the viewport while the card only needs
    // its artwork + caption, so shrinking the artwork to 70% width opened a
    // ~315px void between episodes. The cell now hugs the card.
    final cards = find.byType(EpisodeCard);
    expect(tester.widgetList(cards).length, greaterThanOrEqualTo(2));

    Rect artOf(int i) => tester.getRect(
        find.descendant(of: cards.at(i), matching: find.byType(AspectRatio)).first);

    final art0 = artOf(0);
    final pitch = artOf(1).top - art0.top;
    // Everything the card actually draws: artwork + title + bar + padding.
    final content = art0.height + 72;
    final gap = pitch - content;

    expect(gap, greaterThanOrEqualTo(-1.0), reason: 'cards must not overlap');
    expect(gap, lessThan(40.0),
        reason: 'episodes must sit close together; dead space was $gap');
  });

  testWidgets('backdrop is fully swapped once settled on the next card',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final gc = MainMenuController()..setMainMenu(_mainMenu());
    await tester.pumpWidget(_app(gc));
    await tester.pump(const Duration(milliseconds: 16));

    final list = find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down);
    final extent = tester.getSize(list).height;
    await tester.fling(list, Offset(0, -extent * 0.5), 800);
    await _pumpFrames(tester);

    // Landed on card 1: its background is the base layer at full opacity.
    expect(_opacityOf(tester, _bg1), 1.0);
    expect(gc.focusedIndex, 1);
  });
}
