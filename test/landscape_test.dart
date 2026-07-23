// Landscape layout tests. Widget tests can set the physical viewport, so the
// orientation swap is testable without a device.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ak_reader/data/guide.dart';
import 'package:ak_reader/data/menu.dart';
import 'package:ak_reader/data/models.dart';
import 'package:ak_reader/data/resolved.dart';
import 'package:ak_reader/stores/kv_store.dart';
import 'package:ak_reader/data/offline.dart';
import 'package:ak_reader/data/ru.dart';
import 'package:ak_reader/stores/offline_store.dart';
import 'package:ak_reader/stores/progress_store.dart';
import 'package:ak_reader/stores/settings_store.dart';
import 'package:ak_reader/ui/guide_controller.dart';
import 'package:ak_reader/ui/guide_screen.dart';
import 'package:ak_reader/ui/reader_audio.dart';
import 'package:ak_reader/ui/reader_screen.dart';
import 'package:ak_reader/ui/vn_reader.dart';

const _portrait = Size(400, 800);
const _landscape = Size(800, 400);

Future<void> _setSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// A Main Story guide with two arcs, so the arc rail renders.
Guide _fakeGuide() {
  EventGroup ev(String n) => EventGroup(
        id: n,
        name: n,
        startTime: 0,
        stories: [Story(txt: '$n-1', code: '', name: '', tag: '')],
      );
  EpisodeNode node(String t) => EpisodeNode(
        title: t,
        event: ev(t),
        isEpisode: true,
        episodeIndex: 0,
        forceOptional: false,
      );
  Storyline arc(String name, List<String> titles) => Storyline(
        name: name,
        main: true,
        status: 'complete',
        nodes: [for (final t in titles) node(t)],
      );
  return Guide(
    mainArcs: [
      arc('Arc 1', ['Evil Time', 'Roaring Flare', 'Under Tides']),
      arc('Arc 2', ['Ideal City']),
    ],
    sideStorylines: const [],
  );
}

Widget _guideApp(GuideController gc) {
  final kv = MemoryKeyValueStore();
  return MultiProvider(
    providers: [
      Provider<ResolvedUrls>(create: (_) => ResolvedUrls(kv)),
      // Download UI hidden (no filesystem), keeping these tests on layout.
      Provider<Offline?>(create: (_) => null),
      ChangeNotifierProvider<RuStore>(
          create: (_) => RuStore(store: null, fetch: (_) async => null)),
      ChangeNotifierProvider<SettingsStore>(create: (_) => SettingsStore(kv)),
      ChangeNotifierProvider<ProgressStore>(create: (_) => ProgressStore(kv)),
      ChangeNotifierProvider<OfflineStore>(create: (_) => OfflineStore(kv)),
      ChangeNotifierProvider<GuideController>.value(value: gc),
    ],
    child: const MaterialApp(home: GuideScreen()),
  );
}

/// The scroll axis the episode list actually laid out on.
Axis _scrollerAxis(WidgetTester tester) {
  final lists = tester.widgetList<ListView>(find.byType(ListView));
  // The episode scroller is the one with a fixed itemExtent; the storyline
  // selector below it has none.
  final scroller =
      lists.firstWhere((l) => l.itemExtent != null, orElse: () => lists.first);
  return scroller.scrollDirection;
}

void main() {
  group('guide', () {
    testWidgets('portrait scrolls episodes vertically', (tester) async {
      await _setSize(tester, _portrait);
      await tester.pumpWidget(_guideApp(GuideController()..setGuide(_fakeGuide())));
      await tester.pump(const Duration(milliseconds: 16));
      expect(_scrollerAxis(tester), Axis.vertical);
    });

    testWidgets('landscape swaps the episode scroller to horizontal',
        (tester) async {
      await _setSize(tester, _landscape);
      await tester.pumpWidget(_guideApp(GuideController()..setGuide(_fakeGuide())));
      await tester.pump(const Duration(milliseconds: 16));
      expect(_scrollerAxis(tester), Axis.horizontal);
    });

    testWidgets('portrait arc buttons are labelled "Arc I"', (tester) async {
      await _setSize(tester, _portrait);
      await tester.pumpWidget(_guideApp(GuideController()..setGuide(_fakeGuide())));
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.text('Arc I'), findsOneWidget);
      expect(find.text('Arc II'), findsOneWidget);
    });

    testWidgets('landscape arc rail drops the word, keeping bare numerals',
        (tester) async {
      await _setSize(tester, _landscape);
      await tester.pumpWidget(_guideApp(GuideController()..setGuide(_fakeGuide())));
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.text('Arc I'), findsNothing);
      expect(find.text('I'), findsOneWidget);
      expect(find.text('II'), findsOneWidget);
    });

    testWidgets('the arc rail still switches arcs in landscape', (tester) async {
      await _setSize(tester, _landscape);
      final gc = GuideController()..setGuide(_fakeGuide());
      await tester.pumpWidget(_guideApp(gc));
      await tester.pump(const Duration(milliseconds: 16));

      expect(gc.arcIndex, 0);
      await tester.tap(find.text('II'));
      await tester.pump(const Duration(milliseconds: 16));
      expect(gc.arcIndex, 1);
    });

    testWidgets('rotating keeps the focused episode rather than jumping',
        (tester) async {
      await _setSize(tester, _portrait);
      final gc = GuideController()..setGuide(_fakeGuide());
      await tester.pumpWidget(_guideApp(gc));
      await tester.pump(const Duration(milliseconds: 16));

      gc.setFocused(2);
      await tester.pump(const Duration(milliseconds: 16));

      // Rotate: the retained pixel offset means nothing on the new axis.
      await _setSize(tester, _landscape);
      await tester.pumpWidget(_guideApp(gc));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16)); // post-frame re-centre

      expect(gc.focusedIndex, 2);
      expect(_scrollerAxis(tester), Axis.horizontal);
    });

    testWidgets('a side storyline has no arc rail in either orientation',
        (tester) async {
      final gc = GuideController()
        ..setGuide(const Guide(
          mainArcs: [],
          sideStorylines: [
            Storyline(
              name: 'Side',
              main: false,
              status: 'complete',
              nodes: [
                EpisodeNode(
                  title: 'A Walk in the Dust',
                  event: EventGroup(
                      id: 'x', name: 'x', startTime: 0, stories: []),
                  isEpisode: true,
                  episodeIndex: 0,
                  forceOptional: false,
                ),
              ],
            ),
          ],
        ));
      await _setSize(tester, _landscape);
      await tester.pumpWidget(_guideApp(gc));
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.text('I'), findsNothing);
    });
  });

  group('barSwipeReveal', () {
    test('a downward fling reveals the bar', () {
      expect(barSwipeReveal(0, 800), isTrue); // fast down, no net travel yet
      expect(barSwipeReveal(120, 0), isTrue); // slow deliberate drag down
    });

    test('an upward fling hides the bar', () {
      expect(barSwipeReveal(0, -800), isFalse);
      expect(barSwipeReveal(-120, 0), isFalse);
    });

    test('a tiny movement does nothing', () {
      expect(barSwipeReveal(10, 30), isNull);
      expect(barSwipeReveal(-10, -30), isNull);
      expect(barSwipeReveal(0, 0), isNull);
    });

    test('down is positive, matching screen-space y', () {
      // A drag whose net travel is downward reveals even against a weak
      // opposite velocity flick at release.
      expect(barSwipeReveal(200, -50), isTrue);
    });
  });

  group('vn reader', () {
    Future<void> pumpVn(WidgetTester tester) async {
      final kv = MemoryKeyValueStore();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<ResolvedUrls>(create: (_) => ResolvedUrls(kv)),
            Provider<Offline?>(create: (_) => null),
            ChangeNotifierProvider<SettingsStore>(
              create: (_) => SettingsStore(kv)
                ..set(const SettingsState().copyWith(textSpeed: 'instant')),
            ),
            ChangeNotifierProvider<ProgressStore>(
                create: (_) => ProgressStore(MemoryKeyValueStore())),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: VnReader(
                items: [
                  DialogItem(
                      id: 0, name: 'Amiya', runs: const [TextRun('Doctor!')]),
                ],
                path: 'ch1',
                prev: null,
                next: null,
                audio: ReaderAudio(),
                resumeIndex: 0,
                onSelect: (_, __) {},
                onNavigate: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    /// Height of the dialogue box container.
    double boxHeight(WidgetTester tester) =>
        tester.getSize(find.ancestor(
          of: find.text('Amiya'),
          matching: find.byType(Container),
        ).first).height;

    testWidgets('the dialogue box shrinks in landscape', (tester) async {
      await _setSize(tester, _portrait);
      await pumpVn(tester);
      final portraitHeight = boxHeight(tester);

      await _setSize(tester, _landscape);
      await pumpVn(tester);
      final landscapeHeight = boxHeight(tester);

      // 130px min -> 56px min: a third of a short viewport is too much.
      expect(landscapeHeight, lessThan(portraitHeight));
    });

    testWidgets('the line still renders in landscape', (tester) async {
      await _setSize(tester, _landscape);
      await pumpVn(tester);
      expect(find.textContaining('Doctor!'), findsOneWidget);
      expect(find.text('Amiya'), findsOneWidget);
    });
  });

  // The reader wraps VN in a vertical-drag detector to swipe the bar. This
  // checks the gesture arena: the drag must not swallow tap-to-advance. Mirrors
  // the wrapper in ReaderScreen._vnArea, since driving VN inside ReaderScreen
  // needs network.
  group('vn bar swipe / tap coexistence', () {
    Future<void> pump(WidgetTester tester) async {
      final kv = MemoryKeyValueStore();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<ResolvedUrls>(create: (_) => ResolvedUrls(kv)),
            Provider<Offline?>(create: (_) => null),
            ChangeNotifierProvider<SettingsStore>(
              create: (_) => SettingsStore(kv)
                ..set(const SettingsState().copyWith(textSpeed: 'instant')),
            ),
            ChangeNotifierProvider<ProgressStore>(
                create: (_) => ProgressStore(MemoryKeyValueStore())),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: GestureDetector(
                onVerticalDragStart: (_) {},
                onVerticalDragUpdate: (_) {},
                onVerticalDragEnd: (_) {},
                child: VnReader(
                  items: [
                    DialogItem(
                        id: 0, name: 'Amiya', runs: const [TextRun('Doctor!')]),
                    NarrationItem(
                        id: 1, runs: const [TextRun('The rain fell.')]),
                  ],
                  path: 'ch1',
                  prev: null,
                  next: null,
                  audio: ReaderAudio(),
                  resumeIndex: 0,
                  onSelect: (_, __) {},
                  onNavigate: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('a tap still advances through the drag wrapper', (tester) async {
      await _setSize(tester, _landscape);
      await pump(tester);
      expect(find.textContaining('Doctor!'), findsOneWidget);

      await tester.tap(find.byType(VnReader));
      await tester.pump();
      expect(find.textContaining('The rain fell.'), findsOneWidget);
    });

    testWidgets('a vertical drag does not advance the story', (tester) async {
      await _setSize(tester, _landscape);
      await pump(tester);

      await tester.drag(find.byType(VnReader), const Offset(0, -160));
      await tester.pump();
      // The drag is the bar gesture, not an advance: still on the first line.
      expect(find.textContaining('Doctor!'), findsOneWidget);
      expect(find.textContaining('The rain fell.'), findsNothing);
    });
  });
}
