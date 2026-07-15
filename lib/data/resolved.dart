// Remembers which avatar/sprite candidate URL actually loaded for each portrait,
// so we request the working one first (no fallback 404 round-trips -> no flicker)
// and reuse it across sessions. Ported from BetterPhoneReader/src/data/resolved.ts.
//
// Writes are debounced (the web version used a 500ms setTimeout) because a single
// chapter resolves dozens of portraits and each one would otherwise re-encode the
// whole map.

import 'dart:async';
import 'dart:convert';

import '../stores/kv_store.dart';

const _lsKey = 'bpr.resolved';

class ResolvedUrls {
  final KeyValueStore _kv;
  final Map<String, String> _map;
  final Duration _debounce;
  Timer? _timer;

  ResolvedUrls(this._kv, {Duration debounce = const Duration(milliseconds: 500)})
      : _debounce = debounce,
        _map = _read(_kv);

  static Map<String, String> _read(KeyValueStore kv) {
    final raw = kv.getString(_lsKey);
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as Map)
          .map((k, v) => MapEntry(k.toString(), v.toString()));
    } catch (_) {
      return {};
    }
  }

  String? get(String key) => _map[key];

  void set(String key, String url) {
    if (_map[key] == url) return;
    _map[key] = url;
    _timer?.cancel();
    _timer = Timer(_debounce, flush);
  }

  /// Persist now instead of waiting out the debounce.
  void flush() {
    _timer?.cancel();
    _timer = null;
    _kv.setString(_lsKey, jsonEncode(_map));
  }

  void dispose() {
    if (_timer?.isActive ?? false) flush();
    _timer?.cancel();
  }
}
