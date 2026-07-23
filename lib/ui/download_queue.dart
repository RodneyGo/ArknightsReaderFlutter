// Serialised offline-download queue. Ported from
// BetterPhoneReader/src/composables/downloads.ts.
//
// Downloading several events at once hammers the network + filesystem and races
// on LocalStore's shared url map, so every job runs ONE AT A TIME through this
// single queue, which both the episode cards and the chapter drill-down drive.
//
// Tightened from the web version: a chapter is marked available offline only
// after its files verify on disk, not merely because the download call returned.
// A chapter whose files come back incomplete is retried once, then surfaced as
// [DownloadState.failed] for a manual repair rather than lying about being ready.

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/offline.dart';
import '../data/ru.dart';
import '../stores/offline_store.dart';

enum DownloadState { none, partial, full, queued, busy, failed }

/// A job downloads either a whole episode ([id] + its [txts]) or, when [id] is
/// null, a single chapter — the verify sheet's repair path.
typedef _Job = ({String server, String? id, List<String> txts});

class DownloadQueue extends ChangeNotifier {
  final Offline _offline;
  final OfflineStore _store;

  /// Saves the RU overlay alongside a chapter when downloading in Russian, so a
  /// downloaded ru chapter still reads Russian offline.
  final RuStore? _ru;

  /// Per-chapter seams, injectable so tests can drive the orchestration (which
  /// otherwise needs the network). Default to the real [Offline].
  final Future<void> Function(String server, String txt)? _downloadOverride;
  final Future<bool> Function(String server, String txt)? _verifyOverride;

  DownloadQueue(
    this._offline,
    this._store, {
    RuStore? ru,
    Future<void> Function(String server, String txt)? download,
    Future<bool> Function(String server, String txt)? verifyComplete,
  })  : _ru = ru,
        _downloadOverride = download,
        _verifyOverride = verifyComplete;

  final _queue = <_Job>[];
  final _percent = <String, double>{}; // active episode id -> 0..1
  final _failed = <String>{}; // chapter txts that failed verification
  final _chapterJobDone = <String, Completer<void>>{}; // repair txt -> resolver
  bool _running = false;

  double percentOf(String id) => _percent[id] ?? 0;

  /// The state to render for an episode. Live queue status wins over the marker
  /// index, and a failed chapter surfaces so it can be repaired.
  DownloadState stateOf(String id, List<String> txts) {
    if (_percent.containsKey(id)) return DownloadState.busy;
    if (_queue.any((j) => j.id == id)) return DownloadState.queued;
    if (txts.any(_failed.contains)) return DownloadState.failed;
    return switch (_store.eventState(txts)) {
      EventDownloadState.none => DownloadState.none,
      EventDownloadState.partial => DownloadState.partial,
      EventDownloadState.full => DownloadState.full,
    };
  }

  /// Queue an episode. No-op while it's actively downloading; a second tap while
  /// it's still queued cancels it (mirrors the web toggle).
  void enqueueEpisode(String server, String id, List<String> txts) {
    if (_percent.containsKey(id)) return; // running — ignore taps
    final qi = _queue.indexWhere((j) => j.id == id);
    if (qi != -1) {
      _queue.removeAt(qi); // tap again while queued = cancel
      notifyListeners();
      return;
    }
    if (_store.eventState(txts) == EventDownloadState.full) return;
    _failed.removeAll(txts); // a fresh attempt clears prior failures
    _queue.add((server: server, id: id, txts: txts));
    notifyListeners();
    _process();
  }

  /// Queue a single chapter (re)download; the future completes when it has run.
  Future<void> repairChapter(String server, String txt) {
    final completer = Completer<void>();
    _chapterJobDone[txt] = completer;
    _failed.remove(txt);
    _queue.add((server: server, id: null, txts: [txt]));
    notifyListeners();
    _process();
    return completer.future;
  }

  Future<void> _process() async {
    if (_running) return;
    _running = true;
    try {
      while (_queue.isNotEmpty) {
        final job = _queue.first;
        if (job.id != null) {
          await _runEpisode(job);
        } else {
          await _runChapter(job.server, job.txts.first);
        }
        // The head can't be cancelled mid-run: enqueue early-returns for a busy
        // id and never touches repair jobs. So the head is still this job.
        _queue.removeAt(0);
        notifyListeners();
      }
    } finally {
      _running = false;
    }
  }

  Future<void> _runEpisode(_Job job) async {
    final id = job.id!;
    _percent[id] = 0;
    notifyListeners();
    var done = 0;
    for (final txt in job.txts) {
      await _downloadAndVerify(job.server, txt);
      done++;
      _percent[id] = done / job.txts.length;
      notifyListeners();
    }
    _percent.remove(id);
    notifyListeners();
  }

  Future<void> _runChapter(String server, String txt) async {
    await _downloadAndVerify(server, txt);
    _chapterJobDone.remove(txt)?.complete();
  }

  /// Download a chapter (unless already held), verify it, and retry once if the
  /// files came back incomplete. Marks it available offline only on success.
  Future<void> _downloadAndVerify(String server, String txt) async {
    if (_store.hasStory(txt)) return; // already have it
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await _download(server, txt);
      } catch (_) {
        continue; // network blip — the retry may catch it
      }
      if (await _isComplete(server, txt)) {
        _failed.remove(txt);
        // Save the RU overlay too, so a ru download reads Russian offline. A
        // failure here is non-fatal: the chapter is still downloaded, and an
        // untranslated chapter is a no-op.
        if (server == 'ru') {
          try {
            await _ru?.ensureDownloaded(txt);
          } catch (_) {/* offline ru just falls back to English */}
        }
        _store.mark(txt);
        return;
      }
      // Incomplete: loop re-downloads once more before giving up.
    }
    _failed.add(txt);
  }

  Future<void> _download(String server, String txt) =>
      (_downloadOverride ?? _offline.downloadStory)(server, txt);

  Future<bool> _isComplete(String server, String txt) async {
    if (_verifyOverride != null) return _verifyOverride(server, txt);
    final r = await _offline.verifyStory(server, txt);
    return r.downloaded && r.hasManifest && r.present >= r.total;
  }
}
