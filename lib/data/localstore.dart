// Filesystem-backed offline store. Rebuilt from
// BetterPhoneReader/src/data/localstore.ts (Capacitor Filesystem) onto dart:io +
// path_provider.
//
// This is a REBUILD, not a line-port: the concepts carry over but the platform
// APIs differ. Notably there's no `convertFileSrc` — Flutter loads local files
// directly (Image.file / a file path to the audio player), so `localFilePath`
// just returns an absolute path (or null) instead of a rewritten URL.
//
//   offline/
//     index.json                     downloaded chapters (server + txt)
//     urlmap.json                    remote asset url -> local asset filename
//     meta/<name>.json               shared JSON (menu table, sound map)
//     stories/<server>__<txt>.json   one downloaded chapter's story JSON
//     manifests/<server>__<txt>.json exact asset urls saved for a chapter
//     assets/<hash><ext>             asset bytes (png/webp/mp3), deduped by url
//
// The store is a class (not module globals) so it's unit-testable with a temp
// dir + a fake [Fetcher]. The app uses [LocalStore.instance].

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Fetches an asset's bytes, or null on network error / non-2xx.
typedef Fetcher = Future<Uint8List?> Function(String url);

Future<Uint8List?> _httpFetch(String url) async {
  try {
    final res = await http.get(Uri.parse(url));
    if (res.statusCode >= 200 && res.statusCode < 300) return res.bodyBytes;
  } catch (_) {/* network error */}
  return null;
}

typedef _IndexEntry = ({String server, String txt});

class LocalStore {
  /// The `offline/` directory root.
  final Directory root;
  final Fetcher _fetch;

  Map<String, String> _fileByUrl = {}; // remote url -> local filename
  List<_IndexEntry> _storyIndex = [];

  LocalStore(this.root, {Fetcher? fetcher}) : _fetch = fetcher ?? _httpFetch;

  // --- app singleton ---
  static LocalStore? _instance;
  static Future<LocalStore> instance() async {
    if (_instance != null) return _instance!;
    final base = await getApplicationSupportDirectory();
    final store = LocalStore(Directory(p.join(base.path, 'offline')));
    await store.init();
    return _instance = store;
  }

  // --- paths ---
  String get _assetsDir => p.join(root.path, 'assets');
  String get _urlmapPath => p.join(root.path, 'urlmap.json');
  String get _indexPath => p.join(root.path, 'index.json');
  String _storyPath(String server, String txt) =>
      p.join(root.path, 'stories', _safeName(server, txt));
  String _manifestPath(String server, String txt) =>
      p.join(root.path, 'manifests', _safeName(server, txt));
  String _metaPath(String name) => p.join(root.path, 'meta', '$name.json');

  // --- helpers ---
  static String _safeName(String server, String txt) =>
      '${server}__${txt.replaceAll(RegExp(r'[\\/]'), '__')}.json';

  static String _extOf(String url) {
    final last = url.split('/').last;
    final m = RegExp(r'\.([a-z0-9]+)(?:$|\?|#)', caseSensitive: false)
        .firstMatch(last);
    return m != null ? '.${m.group(1)!.toLowerCase()}' : '';
  }

  // Stable djb2-style hash (deterministic across runs, unlike String.hashCode).
  static String _hashUrl(String url) {
    var h = 5381;
    for (final c in url.codeUnits) {
      h = ((h * 33) ^ c) & 0xFFFFFFFF;
    }
    return '${h.toRadixString(16)}_${url.length.toRadixString(16)}';
  }

  Future<Object?> _readJson(String path) async {
    try {
      final f = File(path);
      if (!await f.exists()) return null;
      return jsonDecode(await f.readAsString());
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeJson(String path, Object? obj) async {
    final f = File(path);
    await f.parent.create(recursive: true);
    await f.writeAsString(jsonEncode(obj));
  }

  // --- init ---
  Future<void> init() async {
    final um = await _readJson(_urlmapPath);
    _fileByUrl = um is Map
        ? um.map((k, v) => MapEntry('$k', '$v'))
        : <String, String>{};
    final idx = await _readJson(_indexPath);
    _storyIndex = idx is List
        ? [
            for (final e in idx)
              if (e is Map) (server: '${e['server']}', txt: '${e['txt']}'),
          ]
        : <_IndexEntry>[];
  }

  // --- assets ---
  /// Absolute local path for a downloaded asset URL, or null if not on disk.
  /// (Replaces the TS `localAsset`/`convertFileSrc`; the UI branches on null:
  /// `path != null ? Image.file(File(path)) : Image.network(url)`.)
  String? localFilePath(String url) {
    final name = _fileByUrl[url];
    return name == null ? null : p.join(_assetsDir, name);
  }

  bool isAssetSaved(String url) => _fileByUrl.containsKey(url);

  /// Resolve a candidate list to the first URL whose bytes are available and make
  /// sure they're on disk, returning that URL (or null if none worked). Already-
  /// saved candidates return immediately with no network request; a new asset is
  /// fetched exactly once and written.
  Future<String?> resolveAndSave(List<String> urls) async {
    for (final url in urls) {
      if (_fileByUrl.containsKey(url)) return url;
      final bytes = await _fetch(url);
      if (bytes == null) continue;
      final name = _hashUrl(url) + _extOf(url);
      try {
        final f = File(p.join(_assetsDir, name));
        await f.parent.create(recursive: true);
        await f.writeAsBytes(bytes);
        _fileByUrl[url] = name;
      } catch (_) {
        // out of space etc. — still return the url so the reader can stream it
      }
      return url;
    }
    return null;
  }

  Future<void> persistUrlMap() => _writeJson(_urlmapPath, _fileByUrl);

  /// Confirm an asset's file is actually on disk (and non-empty).
  Future<bool> verifyAssetOnDisk(String url) async {
    final name = _fileByUrl[url];
    if (name == null) return false;
    final f = File(p.join(_assetsDir, name));
    if (!await f.exists()) return false;
    return await f.length() > 0;
  }

  // --- per-chapter manifest ---
  Future<void> saveManifest(String server, String txt, List<String> urls) =>
      _writeJson(_manifestPath(server, txt), urls);

  Future<List<String>?> readManifest(String server, String txt) async {
    final j = await _readJson(_manifestPath(server, txt));
    return j is List ? j.map((e) => '$e').toList() : null;
  }

  // --- shared meta JSON (menu table, sound map) ---
  Future<void> saveMeta(String name, Object? obj) => _writeJson(_metaPath(name), obj);

  Future<Map<String, dynamic>?> readMeta(String name) async {
    final j = await _readJson(_metaPath(name));
    return j is Map ? j.cast<String, dynamic>() : null;
  }

  Future<bool> hasMeta(String name) => File(_metaPath(name)).exists();

  Future<void> removeMeta(String name) async {
    final f = File(_metaPath(name));
    if (await f.exists()) await f.delete();
  }

  // --- chapter story JSON ---
  Future<void> saveStory(String server, String txt, Object? data) async {
    await _writeJson(_storyPath(server, txt), data);
    if (!_storyIndex.any((s) => s.server == server && s.txt == txt)) {
      _storyIndex.add((server: server, txt: txt));
      await _writeJson(_indexPath, [
        for (final s in _storyIndex) {'server': s.server, 'txt': s.txt},
      ]);
    }
  }

  Future<Map<String, dynamic>?> readStory(String server, String txt) async {
    final j = await _readJson(_storyPath(server, txt));
    return j is Map ? j.cast<String, dynamic>() : null;
  }

  Future<bool> hasStory(String server, String txt) =>
      File(_storyPath(server, txt)).exists();

  Future<void> removeStoryFiles(String server, String txt) async {
    for (final path in [_storyPath(server, txt), _manifestPath(server, txt)]) {
      final f = File(path);
      if (await f.exists()) await f.delete();
    }
    _storyIndex.removeWhere((s) => s.server == server && s.txt == txt);
    await _writeJson(_indexPath, [
      for (final s in _storyIndex) {'server': s.server, 'txt': s.txt},
    ]);
    // Shared asset bytes are left in place (other chapters may reference them);
    // clearAll reclaims that space.
  }

  /// Downloaded chapter txts (server-agnostic), for reconciling the UI markers
  /// (feed into OfflineStore.rebuildFrom).
  List<String> getDownloadedTxts() =>
      {for (final s in _storyIndex) s.txt}.toList();

  /// Wipe every downloaded file + reset the in-memory index.
  Future<void> clearAll() async {
    if (await root.exists()) await root.delete(recursive: true);
    _fileByUrl = {};
    _storyIndex = [];
  }
}
