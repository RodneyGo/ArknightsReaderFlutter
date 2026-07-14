// Widget smoke test for the guide screen. Uses a seeded GuideController (no
// network); the ember layer animates forever so we pump fixed frames.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ak_reader/data/guide.dart';
import 'package:ak_reader/data/menu.dart';
import 'package:ak_reader/stores/kv_store.dart';
import 'package:ak_reader/stores/progress_store.dart';
import 'package:ak_reader/ui/ash_fx.dart';
import 'package:ak_reader/ui/guide_controller.dart';
import 'package:ak_reader/ui/guide_screen.dart';

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

void main() {
  testWidgets('guide screen renders episode cards + ambient layer',
      (tester) async {
    final gc = GuideController()..setGuide(_fakeGuide());
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ProgressStore>(
              create: (_) => ProgressStore(MemoryKeyValueStore())),
          ChangeNotifierProvider<GuideController>.value(value: gc),
        ],
        child: const MaterialApp(home: GuideScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.byType(AshFx), findsOneWidget);
    expect(find.byType(EpisodeCard), findsWidgets);
    expect(find.text('Evil Time'), findsWidgets);
    expect(find.text('Main Story'), findsOneWidget);
  });
}
