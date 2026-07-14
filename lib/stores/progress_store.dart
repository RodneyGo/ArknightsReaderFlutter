// Reading-progress store. Ported from BetterPhoneReader/src/stores/progress.ts.
// Per-chapter read status + scroll position + last-opened chapter, each persisted
// under its own key (mirroring the three localStorage entries).

import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'kv_store.dart';

enum ReadStatus { unread, reading, read }

@immutable
class LastRead {
  final String txt;
  final String server;
  const LastRead(this.txt, this.server);

  Map<String, dynamic> toJson() => {'txt': txt, 'server': server};
  factory LastRead.fromJson(Map<String, dynamic> j) =>
      LastRead(j['txt'] as String, j['server'] as String);
}

const _lsKey = 'bpr.progress';
const _lsScroll = 'bpr.scroll';
const _lsLast = 'bpr.last';

class ProgressStore extends ChangeNotifier {
  final KeyValueStore _kv;

  // Only "reading"/"read" are stored; absent = "unread" (mirrors the TS).
  final Map<String, String> _status;
  final Map<String, int> _scroll;
  LastRead? _last;

  ProgressStore(this._kv)
      : _status = _readStringMap(_kv, _lsKey),
        _scroll = _readIntMap(_kv, _lsScroll),
        _last = _readLast(_kv);

  static Map<String, String> _readStringMap(KeyValueStore kv, String key) {
    final raw = kv.getString(key);
    if (raw != null) {
      try {
        return (jsonDecode(raw) as Map)
            .map((k, v) => MapEntry('$k', '$v'));
      } catch (_) {/* ignore */}
    }
    return {};
  }

  static Map<String, int> _readIntMap(KeyValueStore kv, String key) {
    final raw = kv.getString(key);
    if (raw != null) {
      try {
        return (jsonDecode(raw) as Map)
            .map((k, v) => MapEntry('$k', (v as num).toInt()));
      } catch (_) {/* ignore */}
    }
    return {};
  }

  static LastRead? _readLast(KeyValueStore kv) {
    final raw = kv.getString(_lsLast);
    if (raw != null) {
      try {
        return LastRead.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {/* ignore */}
    }
    return null;
  }

  LastRead? get last => _last;

  ReadStatus statusOf(String txt) {
    switch (_status[txt]) {
      case 'read':
        return ReadStatus.read;
      case 'reading':
        return ReadStatus.reading;
      default:
        return ReadStatus.unread;
    }
  }

  void _persist() =>
      _kv.setString(_lsKey, jsonEncode(_status));

  void saveScroll(String txt, int index) {
    if (index > 0) {
      _scroll[txt] = index;
    } else {
      _scroll.remove(txt);
    }
    _kv.setString(_lsScroll, jsonEncode(_scroll));
    notifyListeners();
  }

  int getScroll(String txt) => _scroll[txt] ?? 0;

  void setLast(String txt, String server) {
    _last = LastRead(txt, server);
    _kv.setString(_lsLast, jsonEncode(_last!.toJson()));
    notifyListeners();
  }

  void markReading(String txt) {
    // Don't downgrade a finished chapter back to "reading".
    if (_status[txt] == 'read') return;
    _status[txt] = 'reading';
    _persist();
    notifyListeners();
  }

  void markRead(String txt) {
    _status[txt] = 'read';
    _persist();
    notifyListeners();
  }

  void markUnread(String txt) {
    _status.remove(txt);
    _persist();
    notifyListeners();
  }

  void toggleRead(String txt) {
    if (_status[txt] == 'read') {
      markUnread(txt);
    } else {
      markRead(txt);
    }
  }

  /// Aggregate status over a set of chapters (for events/arcs).
  ({int read, int total, ReadStatus status}) summarize(List<String> txts) {
    var read = 0;
    var started = false;
    for (final t in txts) {
      final s = _status[t];
      if (s == 'read') read++;
      if (s != null) started = true;
    }
    final total = txts.length;
    final status = total > 0 && read == total
        ? ReadStatus.read
        : started
            ? ReadStatus.reading
            : ReadStatus.unread;
    return (read: read, total: total, status: status);
  }
}
