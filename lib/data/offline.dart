// Pre-download / preload manager. Ported from BetterPhoneReader/src/data/offline.ts.
//
// Two jobs:
//  1. preloadStory() — for ONLINE reads, resolve each asset and record the
//     portrait url that actually works, so the reader requests the right url
//     first (no 404 fallback churn, no flicker) and we get a real progress %.
//  2. downloadStory() — for OFFLINE use, write the chapter JSON + every asset to
//     the device filesystem (localstore.dart).
//
// One deliberate difference from the web: there, preload's fetch() also warmed
// the *browser's* HTTP cache, so an <img> painted instantly afterwards. Flutter's
// ImageCache is only filled by precacheImage (which needs a BuildContext and
// would hold a whole chapter of full-size sprites in RAM), so preload here does
// the resolution job only — images still decode on demand, they just request a
// url that works on the first try.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'audio.dart';
import 'localstore.dart';
import 'models.dart';
import 'resolved.dart';
import 'servers.dart';
import 'source.dart';

/// "Does this url exist?" — injectable so tests don't hit the network.
typedef UrlProbe = Future<bool> Function(String url);

Future<bool> _httpProbe(String url) async {
  try {
    final res = await http.get(Uri.parse(url));
    return res.statusCode >= 200 && res.statusCode < 300;
  } catch (_) {
    return false;
  }
}

/// The distinct assets a chapter references.
typedef StoryAssets = ({
  Set<String> portraits,
  Set<String> bgs,
  Set<String> images, // full-screen `Image` (CG) ids
  Set<String> sounds,
});

/// Collect the distinct portraits / backgrounds / CGs / sounds of a raw story.
///
/// Reads the RAW lines rather than normalized items because normalizing drops
/// the off-stage characters — they still need downloading, since a decision
/// branch can put them on screen.
StoryAssets collectAssets(List<RawLine> list) {
  final portraits = <String>{};
  final bgs = <String>{};
  final images = <String>{};
  final sounds = <String>{};
  for (final line in list) {
    final p = line.prop.toLowerCase();
    final a = line.attributes;
    String str(String k) => a[k] == null ? '' : a[k].toString();
    if (p == 'character') {
      for (final k in a.keys) {
        if (k.startsWith('name') && str(k).isNotEmpty) portraits.add(str(k));
      }
    } else if (p == 'charslot') {
      if (str('name').isNotEmpty) portraits.add(str('name'));
    } else if (p == 'background') {
      final img = str('image');
      if (img.isNotEmpty && img != 'bg_black') bgs.add(img);
    } else if (p == 'image') {
      final img = str('image');
      if (img.isNotEmpty) images.add(img);
    } else if (p == 'playsound' || p == 'playmusic') {
      final key = str('key');
      if (key.isNotEmpty) sounds.add(key);
    }
  }
  return (portraits: portraits, bgs: bgs, images: images, sounds: sounds);
}

/// Run [tasks] with bounded [concurrency], reporting completions.
///
/// Progress counts finished tasks, so it can report out of order — it's a
/// percentage, not a sequence.
Future<void> runPool(
  List<Future<void> Function()> tasks, {
  void Function(int done, int total)? onProgress,
  int concurrency = 6,
}) async {
  final total = tasks.length;
  if (total == 0) {
    onProgress?.call(0, 0);
    return;
  }
  var next = 0;
  var done = 0;
  Future<void> worker() async {
    while (true) {
      final i = next++;
      if (i >= tasks.length) return;
      try {
        await tasks[i]();
      } catch (_) {
        // one bad asset must not abort the batch
      }
      onProgress?.call(++done, total);
    }
  }

  final workers = <Future<void>>[
    for (var w = 0; w < (concurrency < total ? concurrency : total); w++)
      worker(),
  ];
  await Future.wait(workers);
}

/// Chapter-file health, for the downloads UI.
typedef VerifyResult = ({
  bool downloaded, // chapter JSON present on disk
  int total, // asset files this chapter should have
  int present, // of those, how many are actually on disk
  bool hasManifest, // false for chapters saved before manifests existed
});

class Offline {
  /// Null where there's no filesystem (web). Every download path degrades to
  /// preload-only, mirroring the web build's `isNative` guard.
  final LocalStore? store;
  final ResolvedUrls resolved;
  final UrlProbe _probe;

  Offline({
    required this.store,
    required this.resolved,
    UrlProbe? probe,
  }) : _probe = probe ?? _httpProbe;

  bool get isNative => store != null;

  /// App wiring: a real store everywhere except web.
  static Future<Offline> create(ResolvedUrls resolved) async {
    LocalStore? store;
    if (!kIsWeb) {
      try {
        store = await LocalStore.instance();
      } catch (_) {
        store = null; // no filesystem — downloads simply unavailable
      }
    }
    return Offline(store: store, resolved: resolved);
  }

  /// Absolute path to a downloaded copy of [url], or null if it isn't on disk.
  /// Lets the reader load a saved asset offline instead of hitting the network.
  String? localFile(String url) => store?.localFilePath(url);

  /// Probe candidates in order; return the first that exists.
  Future<String?> resolveFirst(List<String> urls) async {
    for (final u in urls) {
      if (await _probe(u)) return u;
    }
    return null;
  }

  List<String> _avatarUrls(String id) => [
        for (final c in avatarCandidates(id))
          if (c.url != mysteryAvatar) c.url,
      ];

  /// Resolve every asset of a chapter for an ONLINE read, recording each
  /// portrait's working avatar + sprite url so the reader never walks the
  /// fallback chain.
  Future<void> preloadStory(
    List<RawLine> list,
    Map<String, String> soundMap, {
    void Function(int done, int total)? onProgress,
  }) async {
    final assets = collectAssets(list);
    final tasks = <Future<void> Function()>[];
    for (final id in assets.portraits) {
      tasks.add(() async {
        final u = await resolveFirst(_avatarUrls(id));
        if (u != null) resolved.set('av:$id', u);
      });
      tasks.add(() async {
        final u = await resolveFirst(spriteCandidates(id));
        if (u != null) resolved.set('sp:$id', u);
      });
    }
    for (final bg in assets.bgs) {
      tasks.add(() => resolveFirst(backgroundSrcs(bg)));
    }
    for (final img in assets.images) {
      tasks.add(() => resolveFirst(imageSrcs(img)));
    }
    for (final key in assets.sounds) {
      tasks.add(() => resolveFirst(resolveSound(key, soundMap)));
    }
    await runPool(tasks, onProgress: onProgress);
    resolved.flush();
  }

  /// True if this chapter's files are on disk.
  Future<bool> isStoryDownloaded(String server, String path) async =>
      await store?.hasStory(baseServer(server), path) ?? false;

  /// A chapter's story JSON, preferring the offline copy so a downloaded chapter
  /// opens with no network.
  Future<StoryData> getStoryData(String server, String path) async {
    final base = baseServer(server);
    final s = store;
    if (s != null && await s.hasStory(base, path)) {
      final local = await s.readStory(base, path);
      if (local != null) return StoryData.fromJson(local);
    }
    return StoryData.fromJson(
      await getJson<Map<String, dynamic>>(base, '/gamedata/story/$path.json'),
    );
  }

  /// Save the shared JSON (chapter list + sound map) once, so they load offline.
  Future<void> _ensureMeta(String base) async {
    final s = store;
    if (s == null) return;
    final tableName = '${base}__story_review_table';
    if (!await s.hasMeta(tableName)) {
      try {
        final table = await getJson<Map<String, dynamic>>(
            base, '/gamedata/excel/story_review_table.json');
        await s.saveMeta(tableName, table);
      } catch (_) {
        // keep going — chapter assets are the priority
      }
    }
    if (!await s.hasMeta('story_variables')) {
      final sm = await loadSoundMap();
      if (sm.isNotEmpty) await s.saveMeta('story_variables', sm);
    }
  }

  /// Download one chapter (its JSON + every asset) for offline use.
  Future<void> downloadStory(
    String server,
    String path, {
    void Function(int done, int total)? onProgress,
  }) async {
    final base = baseServer(server);
    // Keep the raw json: it's what gets written to disk, so a downloaded chapter
    // parses back to exactly what the network would have given.
    final raw =
        await getJson<Map<String, dynamic>>(base, '/gamedata/story/$path.json');
    final soundMap = await loadSoundMap();
    final list = StoryData.fromJson(raw).storyList;

    final s = store;
    if (s == null) {
      // No filesystem: warm/resolve so the flow still works.
      await preloadStory(list, soundMap, onProgress: onProgress);
      return;
    }

    await _ensureMeta(base);
    await s.saveStory(base, path, raw);

    final assets = collectAssets(list);
    // Record the urls actually saved, so verify() can check exactly these files.
    // resolveAndSave skips assets already on disk (shared across episodes) with
    // no network request, and fetches a new asset exactly once.
    final saved = <String>[];
    final tasks = <Future<void> Function()>[];
    for (final id in assets.portraits) {
      tasks.add(() async {
        final u = await s.resolveAndSave(_avatarUrls(id));
        if (u != null) {
          resolved.set('av:$id', u);
          saved.add(u);
        }
      });
      tasks.add(() async {
        final u = await s.resolveAndSave(spriteCandidates(id));
        if (u != null) {
          resolved.set('sp:$id', u);
          saved.add(u);
        }
      });
    }
    for (final bg in assets.bgs) {
      tasks.add(() async {
        final u = await s.resolveAndSave(backgroundSrcs(bg));
        if (u != null) saved.add(u);
      });
    }
    for (final img in assets.images) {
      tasks.add(() async {
        final u = await s.resolveAndSave(imageSrcs(img));
        if (u != null) saved.add(u);
      });
    }
    for (final key in assets.sounds) {
      tasks.add(() async {
        final u = await s.resolveAndSave(resolveSound(key, soundMap));
        if (u != null) saved.add(u);
      });
    }

    await runPool(tasks, onProgress: onProgress);
    await s.saveManifest(base, path, saved);
    await s.persistUrlMap();
    resolved.flush();
  }

  /// Remove one chapter's offline files.
  Future<void> removeStory(String server, String path) async =>
      store?.removeStoryFiles(baseServer(server), path);

  /// Verify a downloaded chapter: the story JSON plus every asset in its
  /// manifest (each file present and non-empty).
  Future<VerifyResult> verifyStory(String server, String path) async {
    final s = store;
    final base = baseServer(server);
    final downloaded = await isStoryDownloaded(server, path);
    if (s == null || !downloaded) {
      return (downloaded: false, total: 0, present: 0, hasManifest: false);
    }
    final manifest = await s.readManifest(base, path);
    if (manifest == null) {
      return (downloaded: true, total: 0, present: 0, hasManifest: false);
    }
    var present = 0;
    for (final url in manifest) {
      if (await s.verifyAssetOnDisk(url)) present++;
    }
    return (
      downloaded: true,
      total: manifest.length,
      present: present,
      hasManifest: true,
    );
  }

  /// The chapters actually on disk — the source of truth for OfflineStore.
  List<String> downloadedTxts() => store?.getDownloadedTxts() ?? const [];
}
