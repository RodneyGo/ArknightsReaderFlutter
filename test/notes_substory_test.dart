// The sub-story chips in the main menu's notes panel are shortcuts into a chapter.
// They rendered as plain Chips with no tap handler — they looked like buttons
// but did nothing.

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
import 'package:ak_reader/ui/reader_screen.dart';

/// One episode carrying a note plus two sub-stories: one that resolves to a
/// real chapter, one that never matched (txt null).
MainMenu _mainMenu() {
  const stories = [
    Story(txt: 'level_main_01', code: '1-1', name: 'Lonetrail', tag: ''),
    Story(txt: 'level_main_02', code: '1-2', name: 'Nightfall', tag: ''),
  ];
  const event = EventGroup(
    id: 'main',
    name: 'Evil Time',
    startTime: 0,
    stories: stories,
  );
  return const MainMenu(
    mainArcs: [
      Storyline(
        name: 'Arc 1',
        main: true,
        status: 'complete',
        nodes: [
          EpisodeNode(
            title: 'Evil Time',
            event: event,
            isEpisode: true,
            episodeIndex: 0,
            forceOptional: false,
            note: 'A note about this episode.',
            subStories: [
              SubStory('Lonetrail', 'level_main_01'),
              SubStory('Unmatched Thing', null),
            ],
          ),
        ],
      ),
    ],
    sideStorylines: [],
  );
}

Widget _app(MainMenuController gc, ProgressStore progress) {
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
      ChangeNotifierProvider<ProgressStore>.value(value: progress),
      ChangeNotifierProvider<OfflineStore>(create: (_) => OfflineStore(kv)),
      ChangeNotifierProvider<MainMenuController>.value(value: gc),
    ],
    child: const MaterialApp(home: MainMenuScreen()),
  );
}

Future<void> _openNotes(WidgetTester tester) async {
  // The notes control is an icon button in the top bar, not a text label.
  await tester.tap(find.byIcon(Icons.sticky_note_2_outlined));
  await tester.pump(const Duration(milliseconds: 16));
}

void main() {
  testWidgets('tapping a sub-story chip opens that chapter', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final gc = MainMenuController()..setMainMenu(_mainMenu());
    await tester.pumpWidget(_app(gc, ProgressStore(MemoryKeyValueStore())));
    await tester.pump(const Duration(milliseconds: 16));

    await _openNotes(tester);
    expect(find.text('Lonetrail'), findsOneWidget);

    await tester.tap(find.text('Lonetrail'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(ReaderScreen), findsOneWidget,
        reason: 'the chip must jump to the chapter, not sit inert');
  });

  testWidgets('an unresolved sub-story chip is inert, not a dead button',
      (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final gc = MainMenuController()..setMainMenu(_mainMenu());
    await tester.pumpWidget(_app(gc, ProgressStore(MemoryKeyValueStore())));
    await tester.pump(const Duration(milliseconds: 16));

    await _openNotes(tester);
    await tester.tap(find.text('Unmatched Thing'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(ReaderScreen), findsNothing,
        reason: 'a chip with no matching chapter must not navigate anywhere');
  });
}
