// Episode trailers (YouTube), fetched from GitHub (jsDelivr) instead of bundled.
//
// The story data carries no video field, so trailers live in their own small
// lookup: `trailers.json` in the project repo, served by jsDelivr, keyed by the
// event id (the stable maintheme/activity id, not a chapter). An episode shows a
// "Trailer" button only when its event id is in the index; tapping it opens the
// in-app player (see ui/trailer_screen.dart). Because playback needs the network
// anyway, there is no bundled fallback — the index is just cached to disk so the
// button survives across launches, and refreshed in the background like the RU
// index. [TrailerStore] is a ChangeNotifier so the button appears when a refresh
// lands a newly-added trailer.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'localstore.dart';

/// jsDelivr base for the project repo (same repo as the RU translations). The
/// `trailers.json` lives at the top of the `translations/` tree.
const trailerBase =
    'https://cdn.jsdelivr.net/gh/RodneyGo/ArknightsReaderFlutter@main/translations';

const _indexMetaName = 'trailers_index';

/// Which events have a trailer, mapping event id -> YouTube video id.
class TrailerIndex {
  final int version;
  final Map<String, String> entries; // eventId -> youtube video id

  const TrailerIndex(this.version, this.entries);
  static const empty = TrailerIndex(0, {});

  String? idFor(String eventId) => entries[eventId];

  static TrailerIndex fromJson(Map<String, dynamic> j) {
    // Accept either { "trailers": { id: vid } } or a bare { id: vid } map.
    final raw = j['trailers'] ?? j['entries'];
    final src = raw is Map ? raw : j;
    final entries = <String, String>{};
    for (final e in src.entries) {
      final k = '${e.key}';
      if (k == 'version') continue;
      final v = e.value;
      // Support both "eventId": "videoId" and "eventId": {"id": "videoId"}.
      final id = v is Map ? v['id'] : v;
      if (id is String && id.isNotEmpty) entries[k] = id;
    }
    final ver = j['version'];
    return TrailerIndex(ver is num ? ver.toInt() : 0, entries);
  }
}

/// Fetch a JSON object from a URL, or null on any failure. Injectable for tests.
typedef JsonFetch = Future<Map<String, dynamic>?> Function(String url);

Future<Map<String, dynamic>?> _httpJson(String url) async {
  try {
    final res = await http.get(Uri.parse(url));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final j = jsonDecode(res.body);
      if (j is Map<String, dynamic>) return j;
      if (j is Map) return j.cast<String, dynamic>();
    }
  } catch (_) {
    // network / parse failure — caller falls back
  }
  return null;
}

class TrailerStore extends ChangeNotifier {
  final LocalStore? _store;
  final JsonFetch _fetch;

  TrailerIndex _index = TrailerIndex.empty;

  TrailerStore({LocalStore? store, JsonFetch? fetch})
      : _store = store,
        _fetch = fetch ?? _httpJson;

  /// App wiring: a real store everywhere except web, with the index loaded from
  /// its cached copy (if any). Playback needs the network, so there is no
  /// bundled fallback — an empty index just means no trailer buttons yet.
  static Future<TrailerStore> create() async {
    LocalStore? store;
    if (!kIsWeb) {
      try {
        store = await LocalStore.instance();
      } catch (_) {
        store = null;
      }
    }
    final s = TrailerStore(store: store);
    await s.loadIndex();
    return s;
  }

  TrailerIndex get index => _index;

  /// The trailer video id for an event, or null when it has none.
  String? videoIdFor(String eventId) => _index.idFor(eventId);

  /// Load the cached index from disk (empty until the first refresh lands).
  Future<void> loadIndex() async {
    final cached = await _store?.readMeta(_indexMetaName);
    if (cached != null) _index = TrailerIndex.fromJson(cached);
  }

  /// Revalidate against the network. Adopts a newer version, persists it, and
  /// notifies so the buttons refresh. Silent on failure.
  Future<void> refreshIndex() async {
    final fresh = await _fetch('$trailerBase/trailers.json');
    if (fresh == null) return;
    final idx = TrailerIndex.fromJson(fresh);
    if (idx.version == _index.version) return; // nothing new
    _index = idx;
    await _store?.saveMeta(_indexMetaName, fresh);
    notifyListeners();
  }

  @visibleForTesting
  void setIndexForTest(TrailerIndex index) => _index = index;
}
