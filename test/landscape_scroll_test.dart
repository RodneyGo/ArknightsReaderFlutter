// Landscape episode-scroller geometry: does the card the controller reports as
// focused actually sit under the centre of the viewport, at every index?
//
// Reported symptom: horizontally the scroll "skips a couple of chapters" and
// "the further right you go the more offset the chosen episode is".

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

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

const _titles = [
  'Ep0', 'Ep1', 'Ep2', 'Ep3', 'Ep4', 'Ep5', 'Ep6', 'Ep7',
];

MainMenu _mainMenu() {
  EventGroup ev(String n) => EventGroup(
        id: n,
        name: n,
        startTime: 0,
        stories: [Story(txt: '$n-1', code: '', name: '', tag: '')],
      );
  EpisodeNode node(String t, int i) => EpisodeNode(
        title: t,
        event: ev(t),
        isEpisode: true,
        episodeIndex: i,
        forceOptional: false,
      );
  return MainMenu(
    mainArcs: [
      Storyline(
        name: 'Arc 1',
        main: true,
        status: 'complete',
        nodes: [for (var i = 0; i < _titles.length; i++) node(_titles[i], i)],
      ),
    ],
    sideStorylines: const [],
  );
}

Widget _app(MainMenuController gc) {
  final kv = MemoryKeyValueStore();
  return MultiProvider(
    providers: [
      Provider<ResolvedUrls>(create: (_) => ResolvedUrls(kv)),
      Provider<Offline?>(create: (_) => null),
      ChangeNotifierProvider<RuStore>(
          create: (_) => RuStore(store: null, fetch: (_) async => null)),
      ChangeNotifierProvider<TrailerStore>(
          create: (_) => TrailerStore(store: null, fetch: (_) async => null)),
      ChangeNotifierProvider<SettingsStore>(create: (_) => SettingsStore(kv)),
      ChangeNotifierProvider<ProgressStore>(create: (_) => ProgressStore(kv)),
      ChangeNotifierProvider<OfflineStore>(create: (_) => OfflineStore(kv)),
      ChangeNotifierProvider<MainMenuController>.value(value: gc),
    ],
    child: const MaterialApp(home: MainMenuScreen()),
  );
}

Future<void> _pumpFrames(WidgetTester tester, {int frames = 90}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// A realistic short swipe: several closely-spaced moves so the velocity
/// tracker sees a genuine throw. `tester.fling` over a short distance loses most
/// of it to touch slop and yields too few samples to register a velocity.
///
/// NOTE: `moveBy` defaults to `timeStamp: Duration.zero`, so without explicit
/// increasing timestamps every event lands at t=0 and the tracker reports a
/// velocity of exactly 0 — a drag with no throw, which is not what a finger does.
Future<void> _swipe(
  WidgetTester tester,
  double dx, {
  int steps = 5,
  int msPerStep = 8,
}) async {
  final g = await tester.startGesture(tester.getCenter(_list));
  await tester.pump();
  var t = Duration.zero;
  for (var i = 0; i < steps; i++) {
    t += Duration(milliseconds: msPerStep);
    await g.moveBy(Offset(dx / steps, 0), timeStamp: t);
    await tester.pump(Duration(milliseconds: msPerStep));
  }
  await g.up(timeStamp: t);
}

/// Mount a FRESH main menu screen. Pumping the app twice in a row reuses the State
/// (same widget type), so the scroll offset would carry over and inflate the
/// next measurement — tear the tree down first.
Future<MainMenuController> _freshApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  final gc = MainMenuController()..setMainMenu(_mainMenu());
  await tester.pumpWidget(_app(gc));
  await tester.pump(const Duration(milliseconds: 16));
  return gc;
}

/// The episode scroller: the horizontal Scrollable carrying the snap physics
/// (the storyline selector below it leaves physics null).
Finder get _list => find.byWidgetPredicate((w) =>
    w is Scrollable &&
    w.axisDirection == AxisDirection.right &&
    w.physics != null);

void main() {
  testWidgets('landscape: focused card stays centred at every index',
      (tester) async {
    // 800x400 logical landscape.
    tester.view.physicalSize = const Size(800, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final gc = MainMenuController()..setMainMenu(_mainMenu());
    await tester.pumpWidget(_app(gc));
    await tester.pump(const Duration(milliseconds: 16));

    final viewportCentre = tester.getCenter(_list).dx;
    final report = <String>[];

    // Walk right one card at a time and record where the focused card lands.
    for (var target = 0; target < 5; target++) {
      if (target > 0) {
        await tester.fling(_list, const Offset(-120, 0), 600);
        await _pumpFrames(tester);
      }
      final idx = gc.focusedIndex;
      final cardCentre =
          tester.getCenter(find.text(_titles[idx]).first).dx;
      report.add('after $target flings: focusedIndex=$idx '
          'offset=${(cardCentre - viewportCentre).toStringAsFixed(1)}px');
    }

    debugPrint('=== LANDSCAPE CENTRING ===\n${report.join('\n')}');

    // Re-measure cleanly: the focused card must be centred, at any index.
    final idx = gc.focusedIndex;
    final cardCentre = tester.getCenter(find.text(_titles[idx]).first).dx;
    expect((cardCentre - viewportCentre).abs(), lessThan(2.0),
        reason: 'focused card $idx must sit at the viewport centre');
  });

  testWidgets('landscape: a normal flick does not run off the arc',
      (tester) async {
    tester.view.physicalSize = const Size(800, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Undamped these landed on 2 / 4 / 7 — "it takes me to the fourth". Damped,
    // the reach should track portrait's (1 / 2 / 3) while still FEELING like a
    // throw: harder flick, further travel. Pinning it to exactly one card per
    // swipe killed the kinetic feel, so assert the shape, not a fixed number.
    final landed = <double, int>{};
    for (final velocity in [1200.0, 2000.0, 3000.0]) {
      final gc = await _freshApp(tester);
      await tester.fling(_list, const Offset(-150, 0), velocity);
      await _pumpFrames(tester);
      landed[velocity] = gc.focusedIndex;
    }
    debugPrint('=== LANDSCAPE, isolated runs === $landed');

    expect(landed[1200]!, greaterThan(0), reason: 'a flick must move');
    expect(landed[3000]!, greaterThan(landed[1200]!),
        reason: 'a harder flick must travel further — that is the inertia');
    expect(landed[3000]!, lessThanOrEqualTo(5),
        reason: 'but it must not run off the arc (was 7 of 7)');
  });

  testWidgets('landscape: a SHORT forward swipe still reaches the next episode',
      (tester) async {
    tester.view.physicalSize = const Size(800, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Snapping to the nearest card ignored velocity entirely, so any swipe
    // released before the halfway point (89px of the 178px cell) was pulled
    // back — "I center it but it just jumps back to the first one". A short,
    // deliberate flick must advance one episode.
    // All well under the 89px halfway mark of a 178px cell.
    for (final drag in [50.0, 70.0, 85.0]) {
      final gc = await _freshApp(tester);
      await _swipe(tester, -drag);
      // Releases ~30-51px in, i.e. well short of the 89px halfway mark. These
      // are quick flicks, so momentum may legitimately carry more than one
      // card — what must never happen is being dragged back to where it began.
      await _pumpFrames(tester);
      expect(gc.focusedIndex, greaterThanOrEqualTo(1),
          reason: 'a ${drag}px forward swipe must advance, not snap back');
    }
  });

  testWidgets('landscape: a short BACKWARD swipe returns to the previous',
      (tester) async {
    tester.view.physicalSize = const Size(800, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final gc = await _freshApp(tester);
    await _swipe(tester, -70); // -> card 1
    await _pumpFrames(tester);
    expect(gc.focusedIndex, 1);

    await _swipe(tester, 70); // short swipe back
    await _pumpFrames(tester);
    expect(gc.focusedIndex, 0,
        reason: 'a short backward swipe must return to episode 0');
  });

  testWidgets('landscape: a slow drag under half a card settles back',
      (tester) async {
    tester.view.physicalSize = const Size(800, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Below the swipe threshold there is no "throw", so it should settle on the
    // nearest card — here, the one it started on.
    final gc = await _freshApp(tester);
    final gesture = await tester.startGesture(tester.getCenter(_list));
    await tester.pump();
    for (var s = 0; s < 4; s++) {
      await gesture.moveBy(const Offset(-10, 0));
      await tester.pump(const Duration(milliseconds: 60)); // slow => low speed
    }
    await gesture.up();
    await _pumpFrames(tester);

    expect(gc.focusedIndex, 0,
        reason: 'a slow, short drag must settle back on the current episode');
  });

  testWidgets('ROTATING into landscape uses the landscape snap geometry',
      (tester) async {
    // Every other test mounts already-landscape. A real user ROTATES, and
    // Scrollable decides whether to rebuild its ScrollPosition by comparing
    // physics runtimeType only — identical here — so it can keep the portrait
    // physics (itemExtent ~482) while the list lays out at 178. Snapping then
    // targets multiples of the wrong extent: lands between cards and skips ~3.
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(400, 800); // portrait first
    addTearDown(tester.view.reset);
    final gc = await _freshApp(tester);

    tester.view.physicalSize = const Size(800, 400); // rotate
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    await _swipe(tester, -70);
    await _pumpFrames(tester);

    final pixels = tester.state<ScrollableState>(_list).position.pixels;
    expect(pixels % 178, closeTo(0, 1.0),
        reason: 'must settle on a landscape card boundary, not a portrait '
            'one; landed at $pixels');
    expect(gc.focusedIndex, 1,
        reason: 'one swipe after rotating must still advance one episode');
  });

  testWidgets('landscape: a long drag still travels freely', (tester) async {
    tester.view.physicalSize = const Size(800, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // The one-card cap applies to the coast AFTER release, not to the drag, so
    // dragging across several cards must still get there.
    final gc = await _freshApp(tester);
    final gesture = await tester.startGesture(tester.getCenter(_list));
    await tester.pump();
    for (var s = 0; s < 8; s++) {
      await gesture.moveBy(const Offset(-89, 0)); // half a card each step
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await _pumpFrames(tester);

    expect(gc.focusedIndex, greaterThanOrEqualTo(3),
        reason: 'a long drag must not be capped to one card');
  });

  testWidgets('portrait keeps its full fling inertia (undamped)',
      (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final down = find.byWidgetPredicate((w) =>
        w is Scrollable &&
        w.axisDirection == AxisDirection.down &&
        w.physics != null);

    // The landscape damping must not leak into portrait: a hard flick here
    // should still carry past a single card.
    final landed = <double, int>{};
    for (final velocity in [1200.0, 2000.0, 3000.0]) {
      final gc = await _freshApp(tester);
      await tester.fling(down, const Offset(0, -150), velocity);
      await _pumpFrames(tester);
      landed[velocity] = gc.focusedIndex;
    }
    debugPrint('=== PORTRAIT, isolated runs === $landed');

    expect(landed[3000]!, greaterThanOrEqualTo(2),
        reason: 'portrait inertia must stay uncapped');
  });

  testWidgets('landscape with a display cutout: is the card still centred?',
      (tester) async {
    tester.view.physicalSize = const Size(800, 400);
    tester.view.devicePixelRatio = 1.0;
    // Landscape cutout sits on ONE side, so SafeArea insets asymmetrically.
    tester.view.padding =
        const FakeViewPadding(left: 44, top: 0, right: 0, bottom: 0);
    tester.view.viewPadding =
        const FakeViewPadding(left: 44, top: 0, right: 0, bottom: 0);
    addTearDown(tester.view.reset);

    final gc = MainMenuController()..setMainMenu(_mainMenu());
    await tester.pumpWidget(_app(gc));
    await tester.pump(const Duration(milliseconds: 16));

    // The cutout used to shift the scroller's whole box, parking every card
    // ~22px right of the screen's centre line — the "off center" report. In
    // landscape the scroller now spans the full width, so the focused card sits
    // on the true screen centre at every index.
    final deltas = <double>[];
    for (var step = 0; step < 4; step++) {
      if (step > 0) {
        await tester.fling(_list, const Offset(-120, 0), 600);
        await _pumpFrames(tester);
      }
      final idx = gc.focusedIndex;
      final c = tester.getCenter(find.text(_titles[idx]).first).dx;
      deltas.add(c - 400.0); // 400 = physical screen midpoint
    }

    for (final d in deltas) {
      expect(d.abs(), lessThan(1.0),
          reason: 'focused card must sit on the SCREEN centre despite the '
              'cutout; got $deltas');
    }
  });
}
