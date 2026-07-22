import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:ak_reader/data/offline.dart';
import 'package:ak_reader/data/resolved.dart';
import 'package:ak_reader/stores/kv_store.dart';
import 'package:ak_reader/stores/offline_store.dart';
import 'package:ak_reader/ui/download_queue.dart';

/// Build a queue whose per-chapter download/verify are faked, so the test drives
/// the orchestration deterministically without touching the network.
DownloadQueue _queue({
  required Future<void> Function(String txt) download,
  required Future<bool> Function(String txt) verify,
  OfflineStore? store,
}) {
  final offline = Offline(
    store: null,
    resolved: ResolvedUrls(MemoryKeyValueStore()),
    probe: (_) async => true,
  );
  return DownloadQueue(
    offline,
    store ?? OfflineStore(MemoryKeyValueStore()),
    download: (_, txt) => download(txt),
    verifyComplete: (_, txt) => verify(txt),
  );
}

/// Spin the event loop until [cond] holds (downloads resolve on later turns).
Future<void> _until(bool Function() cond) async {
  for (var i = 0; i < 2000; i++) {
    if (cond()) return;
    await Future<void>.delayed(Duration.zero);
  }
  fail('condition never held');
}

void main() {
  test('jobs run one at a time; the second waits as queued', () async {
    final gate = Completer<void>();
    var live = 0, peak = 0;
    final q = _queue(
      download: (txt) async {
        live++;
        peak = max(peak, live);
        if (txt == 'a1') await gate.future;
        live--;
      },
      verify: (_) async => true,
    );

    q.enqueueEpisode('en_US', 'A', ['a1']);
    q.enqueueEpisode('en_US', 'B', ['b1']);

    // A is running (stuck on the gate); B waits behind it.
    await _until(() => q.stateOf('A', ['a1']) == DownloadState.busy);
    expect(q.stateOf('B', ['b1']), DownloadState.queued);

    gate.complete();
    await _until(() => q.stateOf('B', ['b1']) == DownloadState.full);
    expect(peak, 1); // never concurrent
  });

  test('already-downloaded chapters are skipped, not re-fetched', () async {
    final store = OfflineStore(MemoryKeyValueStore())..mark('a1');
    final fetched = <String>[];
    final q = _queue(
      store: store,
      download: (txt) async => fetched.add(txt),
      verify: (_) async => true,
    );

    q.enqueueEpisode('en_US', 'A', ['a1', 'a2']);
    await _until(() => q.stateOf('A', ['a1', 'a2']) == DownloadState.full);

    expect(fetched, ['a2']); // a1 was already held
  });

  test('a chapter that fails verification once is retried, then marked',
      () async {
    final store = OfflineStore(MemoryKeyValueStore());
    var attempts = 0;
    final q = _queue(
      store: store,
      download: (_) async => attempts++,
      verify: (_) async => attempts >= 2, // incomplete the first time
    );

    q.enqueueEpisode('en_US', 'A', ['a1']);
    await _until(() => q.stateOf('A', ['a1']) == DownloadState.full);

    expect(attempts, 2); // downloaded, verify failed, downloaded again
    expect(store.hasStory('a1'), isTrue);
  });

  test('a chapter that never verifies is left unmarked and reported failed',
      () async {
    final store = OfflineStore(MemoryKeyValueStore());
    var attempts = 0;
    final q = _queue(
      store: store,
      download: (_) async => attempts++,
      verify: (_) async => false, // always incomplete
    );

    q.enqueueEpisode('en_US', 'A', ['a1']);
    await _until(() => q.stateOf('A', ['a1']) == DownloadState.failed);

    expect(attempts, 2); // tried exactly twice
    expect(store.hasStory('a1'), isFalse); // never marked available offline
  });

  test('a failing chapter does not abort the rest of the batch', () async {
    final store = OfflineStore(MemoryKeyValueStore());
    final q = _queue(
      store: store,
      download: (_) async {},
      verify: (txt) async => txt != 'a1', // a1 fails, others pass
    );

    q.enqueueEpisode('en_US', 'A', ['a1', 'a2', 'a3']);
    await _until(() => q.stateOf('A', ['a1', 'a2', 'a3']) == DownloadState.failed);

    expect(store.hasStory('a2'), isTrue);
    expect(store.hasStory('a3'), isTrue);
    expect(store.hasStory('a1'), isFalse);
  });

  test('tapping a queued episode cancels it', () async {
    final gate = Completer<void>();
    final q = _queue(
      download: (txt) async {
        if (txt == 'a1') await gate.future;
      },
      verify: (_) async => true,
    );

    q.enqueueEpisode('en_US', 'A', ['a1']); // runs, stuck on gate
    q.enqueueEpisode('en_US', 'B', ['b1']); // queued
    await _until(() => q.stateOf('B', ['b1']) == DownloadState.queued);

    q.enqueueEpisode('en_US', 'B', ['b1']); // tap again = cancel
    expect(q.stateOf('B', ['b1']), DownloadState.none);

    gate.complete();
    await _until(() => q.stateOf('A', ['a1']) == DownloadState.full);
    // B was cancelled, so it never downloaded.
    expect((q).stateOf('B', ['b1']), DownloadState.none);
  });

  test('tapping a busy episode is ignored (no duplicate job)', () async {
    final gate = Completer<void>();
    var starts = 0;
    final q = _queue(
      download: (txt) async {
        starts++;
        await gate.future;
      },
      verify: (_) async => true,
    );

    q.enqueueEpisode('en_US', 'A', ['a1']);
    await _until(() => q.stateOf('A', ['a1']) == DownloadState.busy);
    q.enqueueEpisode('en_US', 'A', ['a1']); // ignored while running

    gate.complete();
    await _until(() => q.stateOf('A', ['a1']) == DownloadState.full);
    expect(starts, 1); // ran exactly once
  });

  test('repairChapter completes when its job has run', () async {
    final store = OfflineStore(MemoryKeyValueStore());
    final q = _queue(
      store: store,
      download: (_) async {},
      verify: (_) async => true,
    );

    await q.repairChapter('en_US', 'a1');
    expect(store.hasStory('a1'), isTrue);
  });
}
