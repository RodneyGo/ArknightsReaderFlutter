// Russian story overlay, fetched from GitHub (jsDelivr) instead of bundled.
//
// There is no Russian game-data server, so "Русский" loads the EN chapter as the
// base and overlays translations where they exist (keyed by storyTxt).
// Untranslated chapters fall back to English.
//
// Design (see the plan): translations live in the project repo's `translations/`
// folder, served by jsDelivr; an index (version + per-path hash) says what's
// translated and when it changed. The app loads the index cache-first (saved
// copy → bundled fallback), revalidates in the background, and fetches each
// chapter's overlay on demand — local-first for downloaded chapters, so offline
// reading keeps working. [RuStore] is a ChangeNotifier so the main menu's RU marker
// updates when a refresh lands new translations.
//
// Overlay application is unchanged from the bundled version: rebuild only the
// lines that change (a RawLine parsed with no attributes holds a const map, so
// mutating in place would throw).

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import 'localstore.dart';
import 'models.dart';

/// jsDelivr base for the translations folder in the project repo. Publish the
/// `translations/` tree to `main` for this to serve it.
const ruBase =
    'https://cdn.jsdelivr.net/gh/RodneyGo/ArknightsReaderFlutter@main/translations';

const _bundledIndexAsset = 'assets/ru_index.json';
const _indexMetaName = 'ru_index';
String _overlayMetaName(String path) => 'ru/$path';

/// Which chapters are translated, and a per-overlay hash to detect changes.
class RuIndex {
  final int version;
  final Map<String, String> entries; // storyTxt (path) -> overlay hash

  const RuIndex(this.version, this.entries);
  static const empty = RuIndex(0, {});

  bool has(String path) => entries.containsKey(path);
  String? hashOf(String path) => entries[path];

  static RuIndex fromJson(Map<String, dynamic> j) {
    final raw = j['entries'];
    final entries = raw is Map
        ? {for (final e in raw.entries) '${e.key}': '${e.value}'}
        : <String, String>{};
    final v = j['version'];
    return RuIndex(v is num ? v.toInt() : 0, entries);
  }
}

class RuOverlay {
  final String path;
  final Map<String, String> names; // speaker name (EN) -> RU
  final Map<String, String> lines; // line id -> translated text

  const RuOverlay({
    required this.path,
    this.names = const {},
    this.lines = const {},
  });

  /// Null when the json isn't an overlay (no `path`).
  static RuOverlay? tryFromJson(Map<String, dynamic> json) {
    final path = json['path'];
    if (path is! String || path.isEmpty) return null;
    Map<String, String> strMap(Object? v) => v is Map
        ? {for (final e in v.entries) '${e.key}': '${e.value}'}
        : const {};
    return RuOverlay(
      path: path,
      names: strMap(json['names']),
      lines: strMap(json['lines']),
    );
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

class RuStore extends ChangeNotifier {
  final LocalStore? _store;
  final JsonFetch _fetch;

  RuIndex _index = RuIndex.empty;
  // Session cache of resolved overlays; cleared when the index changes so a
  // corrected translation isn't served stale within a session.
  final Map<String, RuOverlay> _cache = {};

  RuStore({LocalStore? store, JsonFetch? fetch})
      : _store = store,
        _fetch = fetch ?? _httpJson;

  /// App wiring: a real store everywhere except web, with the index loaded.
  static Future<RuStore> create() async {
    LocalStore? store;
    if (!kIsWeb) {
      try {
        store = await LocalStore.instance();
      } catch (_) {
        store = null;
      }
    }
    final s = RuStore(store: store);
    await s.loadIndex();
    return s;
  }

  RuIndex get index => _index;
  bool hasRu(String path) => _index.has(path);

  /// The RU marker rule: every chapter of the episode is translated.
  bool episodeFullyTranslated(List<String> txts) =>
      txts.isNotEmpty && txts.every(_index.has);

  /// Load the index cache-first: the saved copy, else the bundled fallback.
  Future<void> loadIndex() async {
    final cached = await _store?.readMeta(_indexMetaName);
    if (cached != null) {
      _index = RuIndex.fromJson(cached);
      return;
    }
    try {
      final json = jsonDecode(await rootBundle.loadString(_bundledIndexAsset));
      if (json is Map) _index = RuIndex.fromJson(json.cast<String, dynamic>());
    } catch (_) {
      // no bundled index — stays empty; ru simply reads English until fetched
    }
  }

  /// Revalidate the index against the network. Adopts a newer version, persists
  /// it, and notifies so the markers refresh. Silent on failure.
  Future<void> refreshIndex() async {
    final fresh = await _fetch('$ruBase/ru_index.json');
    if (fresh == null) return;
    final idx = RuIndex.fromJson(fresh);
    if (idx.version == _index.version) return; // nothing new
    _index = idx;
    _cache.clear(); // hashes may have changed
    await _store?.saveMeta(_indexMetaName, fresh);
    notifyListeners();
  }

  /// The overlay for a chapter, or null if untranslated / unavailable. Prefers a
  /// saved copy whose hash still matches the index; otherwise fetches and caches
  /// it (both in memory and, when a store is present, on disk for offline).
  Future<RuOverlay?> overlayFor(String path) async {
    final hash = _index.hashOf(path);
    if (hash == null) return null; // not translated
    final cached = _cache[path];
    if (cached != null) return cached;

    final local = await _store?.readMeta(_overlayMetaName(path));
    if (local != null && local['hash'] == hash && local['data'] is Map) {
      final ov = RuOverlay.tryFromJson((local['data'] as Map).cast());
      if (ov != null) {
        _cache[path] = ov;
        return ov;
      }
    }

    final fetched = await _fetch('$ruBase/ru/$path.json');
    if (fetched == null) return null;
    final ov = RuOverlay.tryFromJson(fetched);
    if (ov == null) return null;
    _cache[path] = ov;
    await _store?.saveMeta(_overlayMetaName(path), {'hash': hash, 'data': fetched});
    return ov;
  }

  /// Ensure a translated chapter's overlay is saved locally (offline download).
  Future<void> ensureDownloaded(String path) => overlayFor(path);

  /// Drop a chapter's saved overlay (chapter removed from offline storage).
  Future<void> removeOverlay(String path) async {
    _cache.remove(path);
    await _store?.removeMeta(_overlayMetaName(path));
  }

  /// Overlay Russian text onto an EN base story. Returns [list] untouched when
  /// the chapter has no (available) translation.
  Future<List<RawLine>> applyRu(List<RawLine> list, String path) async {
    final ov = await overlayFor(path);
    if (ov == null) return list;
    return [for (final line in list) _applyLine(line, ov)];
  }

  @visibleForTesting
  void setIndexForTest(RuIndex index) {
    _index = index;
    _cache.clear();
  }
}

RawLine _applyLine(RawLine line, RuOverlay ov) {
  final a = line.attributes;
  final prop = line.prop.toLowerCase();
  final isSpeakerLine = prop == 'name' || prop == 'multiline';

  String? newName;
  if (isSpeakerLine) {
    final cur = a['name']?.toString() ?? '';
    if (cur.isNotEmpty) newName = ov.names[cur];
  }
  final text = ov.lines[line.id.toString()];
  if (newName == null && text == null) return line;

  final next = Map<String, dynamic>.from(a);
  if (newName != null) next['name'] = newName;
  if (text != null) {
    // Whichever field this line's text lives in. Falls back to `content`, which
    // is what a dialogue line uses.
    if (a.containsKey('content')) {
      next['content'] = text;
    } else if (a.containsKey('text')) {
      next['text'] = text;
    } else if (a.containsKey('options')) {
      next['options'] = text;
    } else {
      next['content'] = text;
    }
  }
  return RawLine(
    id: line.id,
    prop: line.prop,
    attributes: next,
    alt: line.alt,
  );
}
