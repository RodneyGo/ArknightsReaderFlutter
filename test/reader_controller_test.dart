import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:ak_reader/data/localstore.dart';
import 'package:ak_reader/data/models.dart';
import 'package:ak_reader/data/offline.dart';
import 'package:ak_reader/data/resolved.dart';
import 'package:ak_reader/stores/kv_store.dart';
import 'package:ak_reader/ui/reader_controller.dart';

/// A chapter with one decision and two mutually exclusive branches.
List<StoryItem> _branchingChapter() => [
      NarrationItem(id: 0, runs: const [TextRun('Before the choice.')]),
      DecisionItem(
        id: 1,
        group: 1,
        options: const ['Agree', 'Refuse'],
        values: const ['1', '2'],
      ),
      NarrationItem(
        id: 2,
        runs: const [TextRun('You agreed.')],
        branch: const Branch(1, ['1']),
      ),
      NarrationItem(
        id: 3,
        runs: const [TextRun('You refused.')],
        branch: const Branch(1, ['2']),
      ),
      NarrationItem(id: 4, runs: const [TextRun('After the choice.')]),
    ];

String _textOf(StoryItem it) => switch (it) {
      NarrationItem() => it.runs.map((r) => r.text).join(),
      _ => '',
    };

void main() {
  // Ensures http calls use the test's stub client (fire-and-forget neighbour
  // lookups inside load() never touch the real network).
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReaderController', () {
    test('setItems defaults each decision to its first option', () {
      final c = ReaderController()..setItems(_branchingChapter());
      expect(c.selections, {1: '1'});
      expect(c.loading, isFalse);
    });

    test('displayItems hides the branches whose option is not selected', () {
      final c = ReaderController()..setItems(_branchingChapter());

      expect(c.displayItems.map(_textOf), [
        'Before the choice.',
        '', // the decision row itself
        'You agreed.',
        'After the choice.',
      ]);

      c.selectOption(1, '2');
      expect(c.displayItems.map(_textOf), [
        'Before the choice.',
        '',
        'You refused.',
        'After the choice.',
      ]);
    });

    test('unbranched items always show', () {
      final c = ReaderController()
        ..setItems([
          NarrationItem(id: 0, runs: const [TextRun('Always here.')]),
        ]);
      expect(c.displayItems, hasLength(1));
    });

    test('selectOption notifies only on a real change', () {
      final c = ReaderController()..setItems(_branchingChapter());
      var notes = 0;
      c.addListener(() => notes++);

      c.selectOption(1, '1'); // already selected
      expect(notes, 0);

      c.selectOption(1, '2');
      expect(notes, 1);
    });

    test('title comes from the chapter', () {
      final c = ReaderController()..setItems([], title: 'Chapter 1');
      expect(c.title, 'Chapter 1');
    });
  });

  group('ReaderController.load preload gating', () {
    late Directory tmp;
    late LocalStore store;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('ak_reader_ctrl');
      store = LocalStore(Directory('${tmp.path}/offline'));
      await store.init();
      // A chapter present on disk with an asset-bearing line.
      await store.saveStory('en_US', 'ch1', {
        'eventName': 'Chapter One',
        'storyList': [
          {
            'id': 0,
            'prop': 'charslot',
            'attributes': {'name': 'char_002_amiya#1'}
          },
          {
            'id': 1,
            'prop': 'name',
            'attributes': {'name': 'Amiya', 'content': 'Doctor.'}
          },
        ],
      });
    });

    tearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    Offline _offline(void Function() onProbe) => Offline(
          store: store,
          resolved: ResolvedUrls(MemoryKeyValueStore()),
          probe: (_) async {
            onProbe();
            return true;
          },
        );

    test('a verified-downloaded chapter skips asset preload', () async {
      var probes = 0;
      final c = ReaderController(offline: _offline(() => probes++));
      await c.load(
        path: 'ch1',
        server: 'en_US',
        altServer: 'none',
        doctorName: 'Doctor',
        downloaded: true,
      );
      expect(probes, 0); // preload not run
      expect(c.loadingPct, 100);
      expect(c.error, isNull);
      expect(c.displayItems, isNotEmpty);
    });

    test('an un-verified chapter (files on disk, no marker) still preloads',
        () async {
      var probes = 0;
      final c = ReaderController(offline: _offline(() => probes++));
      await c.load(
        path: 'ch1',
        server: 'en_US',
        altServer: 'none',
        doctorName: 'Doctor',
        downloaded: false, // JSON is on disk, but the verified marker is not set
      );
      // The portrait's avatar + sprite candidates get probed to resolve them.
      expect(probes, greaterThan(0));
      expect(c.error, isNull);
    });
  });
}
