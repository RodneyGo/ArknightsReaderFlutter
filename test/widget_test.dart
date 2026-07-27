// Widget smoke test for the guide screen. Uses a seeded GuideController (no
// network); the ember layer animates forever so we pump fixed frames.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'dart:io';

import 'package:ak_reader/data/guide.dart';
import 'package:ak_reader/data/menu.dart';
import 'package:ak_reader/data/offline.dart';
import 'package:ak_reader/data/ru.dart';
import 'package:ak_reader/data/trailers.dart';
import 'package:ak_reader/data/localstore.dart';
import 'package:ak_reader/data/resolved.dart';
import 'package:ak_reader/stores/kv_store.dart';
import 'package:ak_reader/stores/offline_store.dart';
import 'package:ak_reader/stores/progress_store.dart';
import 'package:ak_reader/stores/settings_store.dart';
import 'package:ak_reader/ui/ash_fx.dart';
import 'package:ak_reader/ui/download_queue.dart';
import 'package:ak_reader/ui/guide_controller.dart';
import 'package:ak_reader/ui/guide_screen.dart';
import 'package:ak_reader/ui/reader_screen.dart';

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
  return Guide(
    mainArcs: [
      Storyline(
        name: 'Arc 1',
        main: true,
        status: 'complete',
        nodes: [node('Evil Time'), node('Roaring Flare')],
      ),
    ],
    sideStorylines: const [],
  );
}

/// The guide screen under the same provider tree main() builds. [offline] is
/// null by default (download UI hidden — as on web), so tests that don't care
/// about downloads stay focused.
Widget _app(GuideController gc,
        {Offline? offline, ProgressStore? progress, TrailerStore? trailers}) =>
    MultiProvider(
      providers: [
        Provider<ResolvedUrls>(
            create: (_) => ResolvedUrls(MemoryKeyValueStore())),
        Provider<Offline?>(create: (_) => offline),
        ChangeNotifierProvider<RuStore>(
            create: (_) => RuStore(store: null, fetch: (_) async => null)),
        ChangeNotifierProvider<TrailerStore>(
            create: (_) =>
                trailers ??
                TrailerStore(store: null, fetch: (_) async => null)),
        ChangeNotifierProvider<SettingsStore>(
            create: (_) => SettingsStore(MemoryKeyValueStore())),
        ChangeNotifierProvider<ProgressStore>(
            create: (_) => progress ?? ProgressStore(MemoryKeyValueStore())),
        ChangeNotifierProvider<OfflineStore>(
            create: (_) => OfflineStore(MemoryKeyValueStore())),
        ChangeNotifierProvider<DownloadQueue>(
          create: (ctx) => DownloadQueue(
            offline ??
                Offline(
                    store: null,
                    resolved: ResolvedUrls(MemoryKeyValueStore())),
            ctx.read<OfflineStore>(),
          ),
        ),
        ChangeNotifierProvider<GuideController>.value(value: gc),
      ],
      child: const MaterialApp(home: GuideScreen()),
    );

/// Guide tree with an explicit language + RU index, for the marker tests.
Widget _ruApp(GuideController gc,
    {required String server, required List<String> translated}) {
  final settings = SettingsStore(MemoryKeyValueStore())
    ..set(const SettingsState().copyWith(server: server));
  final ru = RuStore(store: null, fetch: (_) async => null)
    ..setIndexForTest(RuIndex(1, {for (final t in translated) t: 'h'}));
  return MultiProvider(
    providers: [
      Provider<ResolvedUrls>(create: (_) => ResolvedUrls(MemoryKeyValueStore())),
      Provider<Offline?>(create: (_) => null),
      ChangeNotifierProvider<RuStore>.value(value: ru),
      ChangeNotifierProvider<TrailerStore>(
          create: (_) => TrailerStore(store: null, fetch: (_) async => null)),
      ChangeNotifierProvider<SettingsStore>.value(value: settings),
      ChangeNotifierProvider<ProgressStore>(
          create: (_) => ProgressStore(MemoryKeyValueStore())),
      ChangeNotifierProvider<OfflineStore>(
          create: (_) => OfflineStore(MemoryKeyValueStore())),
      ChangeNotifierProvider<GuideController>.value(value: gc),
    ],
    child: const MaterialApp(home: GuideScreen()),
  );
}

void main() {
  group('RU marker', () {
    // 'Evil Time' -> chapter 'Evil Time-1'; 'Roaring Flare' -> 'Roaring Flare-1'.
    testWidgets('shows on a fully-translated episode in Russian',
        (tester) async {
      final gc = GuideController()..setGuide(_fakeGuide());
      await tester.pumpWidget(_ruApp(gc,
          server: 'ru', translated: ['Evil Time-1', 'Roaring Flare-1']));
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.text('RU'), findsWidgets);
    });

    testWidgets('hidden when the language is not Russian', (tester) async {
      final gc = GuideController()..setGuide(_fakeGuide());
      await tester.pumpWidget(_ruApp(gc,
          server: 'en_US', translated: ['Evil Time-1', 'Roaring Flare-1']));
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.text('RU'), findsNothing);
    });

    testWidgets('hidden when the episode is only partially translated',
        (tester) async {
      final gc = GuideController()..setGuide(_fakeGuide());
      // Only 'Evil Time' translated; 'Roaring Flare-1' missing.
      await tester.pumpWidget(
          _ruApp(gc, server: 'ru', translated: ['Evil Time-1']));
      await tester.pump(const Duration(milliseconds: 16));
      // 'Roaring Flare' episode must not show RU; 'Evil Time' (fully) may.
      expect(find.text('RU'), findsOneWidget);
    });
  });

  group('UI localization', () {
    testWidgets('the menu is Russian when the language is ru', (tester) async {
      final gc = GuideController()..setGuide(_fakeGuide());
      await tester.pumpWidget(_ruApp(gc, server: 'ru', translated: const []));
      await tester.pump(const Duration(milliseconds: 16));
      // '☰ Story List' -> '☰ Список историй'
      expect(find.text('☰ Список историй'), findsOneWidget);
      expect(find.text('☰ Story List'), findsNothing);
    });

    testWidgets('the menu is English for other languages', (tester) async {
      final gc = GuideController()..setGuide(_fakeGuide());
      await tester.pumpWidget(_ruApp(gc, server: 'en_US', translated: const []));
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.text('☰ Story List'), findsOneWidget);
    });
  });

  testWidgets('guide screen renders episode cards + ambient layer',
      (tester) async {
    final gc = GuideController()..setGuide(_fakeGuide());
    await tester.pumpWidget(_app(gc));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.byType(AshFx), findsOneWidget);
    expect(find.byType(EpisodeCard), findsWidgets);
    expect(find.text('Evil Time'), findsWidgets);
    expect(find.text('Main Story'), findsOneWidget);
    // top control bar
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    expect(find.byIcon(Icons.sticky_note_2_outlined), findsOneWidget);
    expect(find.text('☰ Story List'), findsOneWidget);
    // per-episode reading bar renders (its fill is a FractionallySizedBox)
    expect(find.byType(FractionallySizedBox), findsWidgets);
  });

  testWidgets('the episode reading bar fill reflects saved progress',
      (tester) async {
    final gc = GuideController()..setGuide(_fakeGuide());
    final progress = ProgressStore(MemoryKeyValueStore());
    // 'Evil Time' has one chapter 'Evil Time-1'; half-read -> a 0.5 fill.
    progress.savePercent('Evil Time-1', 0.5);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ResolvedUrls>(
              create: (_) => ResolvedUrls(MemoryKeyValueStore())),
          Provider<Offline?>(create: (_) => null),
          ChangeNotifierProvider<RuStore>(
              create: (_) => RuStore(store: null, fetch: (_) async => null)),
          ChangeNotifierProvider<TrailerStore>(
              create: (_) =>
                  TrailerStore(store: null, fetch: (_) async => null)),
          ChangeNotifierProvider<SettingsStore>(
              create: (_) => SettingsStore(MemoryKeyValueStore())),
          ChangeNotifierProvider<ProgressStore>.value(value: progress),
          ChangeNotifierProvider<OfflineStore>(
              create: (_) => OfflineStore(MemoryKeyValueStore())),
          ChangeNotifierProvider<GuideController>.value(value: gc),
        ],
        child: const MaterialApp(home: GuideScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 16));

    // One episode's bar fill is half-width; the other is empty.
    final fills = tester
        .widgetList<FractionallySizedBox>(find.byType(FractionallySizedBox));
    expect(
      fills.any((f) => f.widthFactor != null && (f.widthFactor! - 0.5).abs() < 1e-6),
      isTrue,
    );
  });

  testWidgets('tapping a card opens the chapter drill-down; back closes it',
      (tester) async {
    final gc = GuideController()..setGuide(_fakeGuide());
    await tester.pumpWidget(_app(gc));
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.byType(ChaptersPanel), findsNothing);
    await tester.tap(find.byType(EpisodeCard).first);
    await tester.pump(); // start transition
    await tester.pump(const Duration(milliseconds: 300)); // finish it
    expect(find.byType(ChaptersPanel), findsOneWidget);

    // back button closes it
    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ChaptersPanel), findsNothing);
  });

  testWidgets('the trailer button shows only when the event has a trailer',
      (tester) async {
    // A store that knows a trailer for the first episode's event id ('Evil
    // Time') but not the second ('Roaring Flare').
    final trailers = TrailerStore(store: null)
      ..setIndexForTest(const TrailerIndex(1, {'Evil Time': 'dQw4w9WgXcQ'}));
    final gc = GuideController()..setGuide(_fakeGuide());
    await tester.pumpWidget(_app(gc, trailers: trailers));
    await tester.pump(const Duration(milliseconds: 16));

    // Open the first episode's chapter list — its event has a trailer.
    await tester.tap(find.byType(EpisodeCard).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ChaptersPanel), findsOneWidget);
    expect(find.text('Trailer'), findsOneWidget);

    // The trailer is not a chapter: the one story row is still the only tappable
    // chapter (its txt is 'Evil Time-1').
    expect(find.text('Evil Time-1'), findsOneWidget);
  });

  testWidgets('no trailer button when the event has no trailer',
      (tester) async {
    final gc = GuideController()..setGuide(_fakeGuide());
    await tester.pumpWidget(_app(gc)); // default: empty trailer index
    await tester.pump(const Duration(milliseconds: 16));

    await tester.tap(find.byType(EpisodeCard).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ChaptersPanel), findsOneWidget);
    expect(find.text('Trailer'), findsNothing);
  });

  testWidgets('tapping a chapter row opens the reader', (tester) async {
    final gc = GuideController()..setGuide(_fakeGuide());
    await tester.pumpWidget(_app(gc));
    await tester.pump(const Duration(milliseconds: 16));

    await tester.tap(find.byType(EpisodeCard).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Evil Time-1'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(ReaderScreen), findsOneWidget);
    // The chapter fetch can't succeed under flutter_test's offline HttpClient, so
    // this settles into the error state — which is itself the assertion that the
    // load pipeline ran rather than throwing on the way in.
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Failed to load'), findsOneWidget);
  });

  group('episode download UI', () {
    late Directory tmp;
    late Offline offline;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('ak_widget_dl');
      final store = LocalStore(Directory('${tmp.path}/offline'));
      await store.init();
      offline = Offline(
        store: store,
        resolved: ResolvedUrls(MemoryKeyValueStore()),
        probe: (_) async => true,
      );
    });

    tearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    testWidgets('an undownloaded episode shows the download icon',
        (tester) async {
      final gc = GuideController()..setGuide(_fakeGuide());
      await tester.pumpWidget(_app(gc, offline: offline));
      await tester.pump(const Duration(milliseconds: 16));

      expect(find.byIcon(Icons.download_outlined), findsWidgets);
    });

    testWidgets('long-pressing an episode opens the verify sheet',
        (tester) async {
      final gc = GuideController()..setGuide(_fakeGuide());
      await tester.pumpWidget(_app(gc, offline: offline));
      await tester.pump(const Duration(milliseconds: 16));

      await tester.longPress(find.byType(EpisodeCard).first);
      await tester.pump(); // open the sheet
      await tester.pump(const Duration(milliseconds: 300));

      // The sheet is open on its initial verifying state (the verify itself is
      // real file I/O, which doesn't resolve under the test's fake clock — the
      // result path is covered in offline_test/download_queue_test).
      expect(find.text('Verifying…'), findsOneWidget);
      expect(find.text('1 chapter(s)'), findsOneWidget);
    });

    testWidgets('the sheet can mark the episode read', (tester) async {
      final gc = GuideController()..setGuide(_fakeGuide());
      final progress = ProgressStore(MemoryKeyValueStore());
      await tester.pumpWidget(_app(gc, offline: offline, progress: progress));
      await tester.pump(const Duration(milliseconds: 16));

      await tester.longPress(find.byType(EpisodeCard).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Mark as read'));
      await tester.pump();

      expect(progress.statusOf('Evil Time-1'), ReadStatus.read);
      // The button flips now that everything is read.
      expect(find.text('Mark as unread'), findsOneWidget);
    });
  });
}
