// Widget tests for VN mode. No network: portraits are absent (so the sprite
// resolver stays idle) and audio degrades to no-ops without a platform channel.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ak_reader/data/models.dart';
import 'package:ak_reader/data/resolved.dart';
import 'package:ak_reader/stores/kv_store.dart';
import 'package:ak_reader/stores/progress_store.dart';
import 'package:ak_reader/stores/settings_store.dart';
import 'package:ak_reader/ui/reader_audio.dart';
import 'package:ak_reader/ui/vn_reader.dart';

List<StoryItem> _chapter() => [
      DialogItem(id: 0, name: 'Amiya', runs: const [TextRun('Doctor!')]),
      SoundItem(id: 1, key: 'm_a', music: true),
      NarrationItem(id: 2, runs: const [TextRun('The rain fell.')]),
    ];

/// Mounts VnReader with instant text speed unless told otherwise.
Future<ProgressStore> _pump(
  WidgetTester tester, {
  List<StoryItem>? items,
  String textSpeed = 'instant',
  int resumeIndex = 0,
}) async {
  final kv = MemoryKeyValueStore();
  final settings = SettingsStore(kv)
    ..set(const SettingsState().copyWith(textSpeed: textSpeed));
  final progress = ProgressStore(MemoryKeyValueStore());
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<ResolvedUrls>(create: (_) => ResolvedUrls(kv)),
        ChangeNotifierProvider<SettingsStore>.value(value: settings),
        ChangeNotifierProvider<ProgressStore>.value(value: progress),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: VnReader(
            items: items ?? _chapter(),
            path: 'ch1',
            prev: null,
            next: null,
            audio: ReaderAudio(),
            resumeIndex: resumeIndex,
            onSelect: (_, __) {},
            onNavigate: (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pump(); // let the post-frame init run
  await tester.pump();
  return progress;
}

void main() {
  testWidgets('opens on the first line', (tester) async {
    await _pump(tester);
    expect(find.text('Amiya'), findsOneWidget);
    expect(find.textContaining('Doctor!'), findsOneWidget);
  });

  testWidgets('a tap advances, stepping over the music row', (tester) async {
    await _pump(tester);
    await tester.tap(find.byType(VnReader));
    await tester.pump();
    // The PlayMusic row between the two lines is not a line — it is walked past.
    expect(find.textContaining('The rain fell.'), findsOneWidget);
    expect(find.text('Amiya'), findsNothing);
  });

  testWidgets('running past the last line shows the end card and marks read',
      (tester) async {
    final progress = await _pump(tester);
    await tester.tap(find.byType(VnReader));
    await tester.pump();
    await tester.tap(find.byType(VnReader));
    await tester.pump();

    expect(find.text('The End'), findsOneWidget);
    expect(progress.statusOf('ch1'), ReadStatus.read);
  });

  testWidgets('a tap mid-typewriter completes the line instead of advancing',
      (tester) async {
    await _pump(tester, textSpeed: 'slow'); // 52ms/char
    await tester.pump(const Duration(milliseconds: 110)); // ~2 chars in
    expect(find.textContaining('Doctor!'), findsNothing);

    await tester.tap(find.byType(VnReader));
    await tester.pump();
    // Completed, but still on the same line.
    expect(find.textContaining('Doctor!'), findsOneWidget);
    expect(find.text('Amiya'), findsOneWidget);

    // A second tap now moves on — the next line starts typing from scratch, so
    // let it run out before looking for the whole string.
    await tester.tap(find.byType(VnReader));
    await tester.pump();
    expect(find.text('Amiya'), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('The rain fell.'), findsOneWidget);
  });

  testWidgets('holding peeks at the scene and does not advance', (tester) async {
    await _pump(tester);
    final gesture = await tester.startGesture(tester.getCenter(find.byType(VnReader)));
    await tester.pump(const Duration(milliseconds: 400)); // past the 240ms hold
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 300));

    // Still on the first line: a hold must not count as a tap.
    expect(find.text('Amiya'), findsOneWidget);
  });

  testWidgets('resumeIndex opens on the saved line', (tester) async {
    await _pump(tester, resumeIndex: 2);
    expect(find.textContaining('The rain fell.'), findsOneWidget);
  });

  testWidgets('a decision blocks advancing until an option is chosen',
      (tester) async {
    await _pump(tester, items: [
      DecisionItem(
        id: 0,
        group: 1,
        options: const ['Agree', 'Refuse'],
        values: const ['1', '2'],
      ),
      NarrationItem(id: 1, runs: const [TextRun('After.')]),
    ]);
    expect(find.text('Agree'), findsOneWidget);

    // Tapping the backdrop must not skip the choice.
    await tester.tapAt(const Offset(10, 10));
    await tester.pump();
    expect(find.text('Agree'), findsOneWidget);
  });

  testWidgets('the log lists the chapter and jumps to a tapped line',
      (tester) async {
    final key = GlobalKey<VnReaderState>();
    final kv = MemoryKeyValueStore();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ResolvedUrls>(create: (_) => ResolvedUrls(kv)),
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
              key: key,
              items: _chapter(),
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

    key.currentState!.openLog();
    await tester.pump();
    await tester.pump();
    expect(find.text('Log'), findsOneWidget);

    // Jump forward to the narration line.
    await tester.tap(find.textContaining('The rain fell.').last);
    await tester.pump();
    await tester.pump();

    expect(find.text('Log'), findsNothing);
    expect(find.textContaining('The rain fell.'), findsOneWidget);
  });
}
