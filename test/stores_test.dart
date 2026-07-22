import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ak_reader/stores/kv_store.dart';
import 'package:ak_reader/stores/settings_store.dart';
import 'package:ak_reader/stores/progress_store.dart';
import 'package:ak_reader/stores/offline_store.dart';

void main() {
  group('SettingsStore', () {
    test('starts from defaults with an empty store', () {
      final s = SettingsStore(MemoryKeyValueStore());
      expect(s.state.server, 'en_US');
      expect(s.state.doctorName, 'Doctor');
      expect(s.state.fontSize, 16);
      expect(s.state.musicVolume, 0.45);
      expect(s.state.readerMode, 'novel');
    });

    test('load merges stored values over defaults', () {
      final kv = MemoryKeyValueStore(
          {'bpr.settings': jsonEncode({'server': 'ja_JP', 'fontSize': 20})});
      final s = SettingsStore(kv);
      expect(s.state.server, 'ja_JP');
      expect(s.state.fontSize, 20);
      expect(s.state.doctorName, 'Doctor'); // untouched default
    });

    test('set persists and notifies', () {
      final kv = MemoryKeyValueStore();
      final s = SettingsStore(kv);
      var notified = 0;
      s.addListener(() => notified++);

      s.set(s.state.copyWith(doctorName: 'Amiya', debugPerf: true));
      expect(s.state.doctorName, 'Amiya');
      expect(notified, 1);

      // Persisted → a fresh store reads it back.
      final s2 = SettingsStore(kv);
      expect(s2.state.doctorName, 'Amiya');
      expect(s2.state.debugPerf, isTrue);
    });

    test('malformed json falls back to defaults', () {
      final s = SettingsStore(MemoryKeyValueStore({'bpr.settings': 'not json'}));
      expect(s.state.server, 'en_US');
    });
  });

  group('ProgressStore', () {
    test('statusOf defaults to unread', () {
      final p = ProgressStore(MemoryKeyValueStore());
      expect(p.statusOf('x'), ReadStatus.unread);
    });

    test('markReading does not downgrade a read chapter', () {
      final p = ProgressStore(MemoryKeyValueStore());
      p.markRead('a');
      p.markReading('a');
      expect(p.statusOf('a'), ReadStatus.read);
    });

    test('mark/unmark/toggle transitions', () {
      final p = ProgressStore(MemoryKeyValueStore());
      p.markReading('a');
      expect(p.statusOf('a'), ReadStatus.reading);
      p.toggleRead('a');
      expect(p.statusOf('a'), ReadStatus.read);
      p.toggleRead('a');
      expect(p.statusOf('a'), ReadStatus.unread);
    });

    test('saveScroll stores >0 and clears at 0; persists', () {
      final kv = MemoryKeyValueStore();
      final p = ProgressStore(kv);
      p.saveScroll('a', 42);
      expect(p.getScroll('a'), 42);
      expect(ProgressStore(kv).getScroll('a'), 42); // persisted
      p.saveScroll('a', 0);
      expect(p.getScroll('a'), 0);
      expect(ProgressStore(kv).getScroll('a'), 0);
    });

    test('setLast persists', () {
      final kv = MemoryKeyValueStore();
      ProgressStore(kv).setLast('ch1', 'en_US');
      final reloaded = ProgressStore(kv);
      expect(reloaded.last?.txt, 'ch1');
      expect(reloaded.last?.server, 'en_US');
    });

    test('summarize aggregates read/reading/unread', () {
      final p = ProgressStore(MemoryKeyValueStore());
      p.markRead('a');
      p.markReading('b');
      final s = p.summarize(['a', 'b', 'c']);
      expect(s.read, 1);
      expect(s.total, 3);
      expect(s.status, ReadStatus.reading);

      p.markRead('b');
      p.markRead('c');
      expect(p.summarize(['a', 'b', 'c']).status, ReadStatus.read);
      expect(p.summarize([]).status, ReadStatus.unread);
      expect(p.summarize(['z']).status, ReadStatus.unread);
    });

    test('status survives reload', () {
      final kv = MemoryKeyValueStore();
      ProgressStore(kv)
        ..markRead('a')
        ..markReading('b');
      final p2 = ProgressStore(kv);
      expect(p2.statusOf('a'), ReadStatus.read);
      expect(p2.statusOf('b'), ReadStatus.reading);
    });

    test('savePercent records scroll depth; a read chapter is always 100%', () {
      final p = ProgressStore(MemoryKeyValueStore());
      p.savePercent('a', 0.4);
      expect(p.percentOf('a'), closeTo(0.4, 1e-9));

      p.markRead('b');
      p.savePercent('b', 0.3); // ignored — b is finished
      expect(p.percentOf('b'), 1.0);

      expect(p.percentOf('never-opened'), 0.0);
    });

    test('savePercent ignores sub-threshold changes but persists real ones', () {
      final kv = MemoryKeyValueStore();
      final p = ProgressStore(kv);
      p.savePercent('a', 0.50);
      p.savePercent('a', 0.51); // < 0.02 delta — not written
      expect(p.percentOf('a'), closeTo(0.50, 1e-9));
      p.savePercent('a', 0.70); // real change
      expect(ProgressStore(kv).percentOf('a'), closeTo(0.70, 1e-9)); // persisted
    });

    test('savePercent clamps and clears at zero', () {
      final p = ProgressStore(MemoryKeyValueStore());
      p.savePercent('a', 1.5);
      expect(p.percentOf('a'), 1.0);
      p.savePercent('a', -0.2);
      expect(p.percentOf('a'), 0.0);
    });

    test('readingFraction averages read (full) and in-progress chapters', () {
      final p = ProgressStore(MemoryKeyValueStore());
      p.markRead('a'); // 1.0
      p.savePercent('b', 0.5); // 0.5
      // c untouched -> 0.0
      expect(p.readingFraction(['a', 'b', 'c']), closeTo(0.5, 1e-9));
      expect(p.readingFraction([]), 0.0);
    });
  });

  group('OfflineStore', () {
    test('mark/unmark/hasStory', () {
      final o = OfflineStore(MemoryKeyValueStore());
      expect(o.hasStory('a'), isFalse);
      o.mark('a');
      expect(o.hasStory('a'), isTrue);
      o.unmark('a');
      expect(o.hasStory('a'), isFalse);
    });

    test('eventState none/partial/full', () {
      final o = OfflineStore(MemoryKeyValueStore());
      expect(o.eventState([]), EventDownloadState.none);
      expect(o.eventState(['a', 'b']), EventDownloadState.none);
      o.mark('a');
      expect(o.eventState(['a', 'b']), EventDownloadState.partial);
      o.mark('b');
      expect(o.eventState(['a', 'b']), EventDownloadState.full);
    });

    test('clear and rebuildFrom; persistence round-trips', () {
      final kv = MemoryKeyValueStore();
      final o = OfflineStore(kv);
      o.mark('a');
      o.mark('b');
      expect(OfflineStore(kv).hasStory('a'), isTrue); // persisted

      o.clear();
      expect(o.hasStory('a'), isFalse);
      expect(OfflineStore(kv).hasStory('a'), isFalse);

      o.rebuildFrom(['x', 'y']);
      expect(o.hasStory('x'), isTrue);
      expect(o.hasStory('a'), isFalse);
      final reloaded = OfflineStore(kv);
      expect(reloaded.hasStory('y'), isTrue);
    });
  });
}
