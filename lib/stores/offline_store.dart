// Downloaded-chapters store. Ported from BetterPhoneReader/src/stores/offline.ts.
// A fast index of which chapters (storyTxt) have been pre-downloaded; the actual
// files live on the device filesystem (localstore — not yet ported).

import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'kv_store.dart';

enum EventDownloadState { none, partial, full }

const _lsKey = 'bpr.offline';

class OfflineStore extends ChangeNotifier {
  final KeyValueStore _kv;
  final Set<String> _stories;

  OfflineStore(this._kv) : _stories = _load(_kv);

  static Set<String> _load(KeyValueStore kv) {
    final raw = kv.getString(_lsKey);
    if (raw != null) {
      try {
        // Stored as { txt: true } (mirrors the TS Record<string, true>).
        return (jsonDecode(raw) as Map).keys.map((k) => '$k').toSet();
      } catch (_) {/* ignore */}
    }
    return {};
  }

  bool hasStory(String txt) => _stories.contains(txt);

  /// An event is "downloaded" when all its chapters are.
  EventDownloadState eventState(List<String> txts) {
    if (txts.isEmpty) return EventDownloadState.none;
    final have = txts.where(_stories.contains).length;
    if (have == 0) return EventDownloadState.none;
    return have == txts.length
        ? EventDownloadState.full
        : EventDownloadState.partial;
  }

  void _persist() =>
      _kv.setString(_lsKey, jsonEncode({for (final t in _stories) t: true}));

  void mark(String txt) {
    _stories.add(txt);
    _persist();
    notifyListeners();
  }

  void unmark(String txt) {
    _stories.remove(txt);
    _persist();
    notifyListeners();
  }

  /// Forget all downloaded-chapter markers (e.g. after the cache is wiped).
  void clear() {
    _stories.clear();
    _persist();
    notifyListeners();
  }

  /// Replace the marker set with exactly [txts] — the pure core of `reconcile()`.
  /// The filesystem `reconcile()` (which reads the real downloaded files) lands
  /// when localstore is ported; it will call this with the on-disk truth.
  void rebuildFrom(Iterable<String> txts) {
    _stories
      ..clear()
      ..addAll(txts);
    _persist();
    notifyListeners();
  }
}
