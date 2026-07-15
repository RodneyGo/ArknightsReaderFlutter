import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:ak_reader/data/localstore.dart';
import 'package:ak_reader/data/models.dart';
import 'package:ak_reader/data/offline.dart';
import 'package:ak_reader/data/resolved.dart';
import 'package:ak_reader/stores/kv_store.dart';

RawLine _line(String prop, Map<String, dynamic> attrs) =>
    RawLine.fromJson({'id': 0, 'prop': prop, 'attributes': attrs}, 0);

void main() {
  group('collectAssets', () {
    test('pulls portraits from every name* slot of a character line', () {
      final assets = collectAssets([
        _line('character', {'name': 'char_002_amiya#1', 'name2': 'char_003_kalts#2'}),
      ]);
      expect(assets.portraits, {'char_002_amiya#1', 'char_003_kalts#2'});
    });

    test('charslot lines use the single name attribute', () {
      final assets = collectAssets([
        _line('charslot', {'name': 'char_002_amiya#1', 'slot': 'l'}),
      ]);
      expect(assets.portraits, {'char_002_amiya#1'});
    });

    test('backgrounds are collected but bg_black is skipped', () {
      final assets = collectAssets([
        _line('background', {'image': 'bg_rhodes'}),
        _line('background', {'image': 'bg_black'}),
      ]);
      expect(assets.bgs, {'bg_rhodes'});
    });

    test('CG images and sounds are collected separately', () {
      final assets = collectAssets([
        _line('image', {'image': 'cg_1'}),
        _line('playsound', {'key': 's_a'}),
        _line('playmusic', {'key': 'm_a'}),
      ]);
      expect(assets.images, {'cg_1'});
      expect(assets.sounds, {'s_a', 'm_a'});
    });

    test('props are matched case-insensitively', () {
      final assets = collectAssets([
        _line('PlayMusic', {'key': 'm_a'}),
        _line('Background', {'image': 'bg_x'}),
      ]);
      expect(assets.sounds, {'m_a'});
      expect(assets.bgs, {'bg_x'});
    });

    test('duplicates collapse — each asset is fetched once', () {
      final assets = collectAssets([
        _line('charslot', {'name': 'char_002_amiya#1'}),
        _line('charslot', {'name': 'char_002_amiya#1'}),
      ]);
      expect(assets.portraits, hasLength(1));
    });

    test('empty attributes and unrelated props are ignored', () {
      final assets = collectAssets([
        _line('charslot', {'name': ''}),
        _line('delay', {'time': '1'}),
        _line('background', {}),
      ]);
      expect(assets.portraits, isEmpty);
      expect(assets.bgs, isEmpty);
    });
  });

  group('runPool', () {
    test('runs every task and reports progress up to the total', () async {
      var ran = 0;
      final progress = <int>[];
      await runPool(
        [for (var i = 0; i < 10; i++) () async => ran++],
        onProgress: (d, t) {
          expect(t, 10);
          progress.add(d);
        },
        concurrency: 3,
      );
      expect(ran, 10);
      expect(progress.last, 10);
      expect(progress, hasLength(10));
    });

    test('never exceeds the concurrency limit', () async {
      var live = 0;
      var peak = 0;
      await runPool(
        [
          for (var i = 0; i < 12; i++)
            () async {
              live++;
              if (live > peak) peak = live;
              await Future<void>.delayed(const Duration(milliseconds: 5));
              live--;
            }
        ],
        concurrency: 4,
      );
      expect(peak, lessThanOrEqualTo(4));
    });

    test('a failing task does not abort the batch', () async {
      var ran = 0;
      await runPool([
        () async => ran++,
        () async => throw Exception('boom'),
        () async => ran++,
      ]);
      expect(ran, 2);
    });

    test('no tasks is not a division by zero', () async {
      var called = false;
      await runPool([], onProgress: (d, t) {
        called = true;
        expect(t, 0);
      });
      expect(called, isTrue);
    });
  });

  group('Offline', () {
    late Directory tmp;
    late LocalStore store;
    late ResolvedUrls resolved;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('ak_offline_test');
      resolved = ResolvedUrls(MemoryKeyValueStore(),
          debounce: const Duration(milliseconds: 1));
      store = LocalStore(
        Directory('${tmp.path}/offline'),
        fetcher: (url) async => Uint8List.fromList(utf8.encode('bytes:$url')),
      );
      await store.init();
    });

    tearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    test('resolveFirst returns the first url that exists', () async {
      final tried = <String>[];
      final off = Offline(
        store: store,
        resolved: resolved,
        probe: (u) async {
          tried.add(u);
          return u.contains('second');
        },
      );
      final got = await off.resolveFirst(['a/first', 'b/second', 'c/third']);
      expect(got, 'b/second');
      // Stops at the winner rather than probing the rest.
      expect(tried, ['a/first', 'b/second']);
    });

    test('resolveFirst is null when nothing exists', () async {
      final off =
          Offline(store: store, resolved: resolved, probe: (_) async => false);
      expect(await off.resolveFirst(['a', 'b']), isNull);
    });

    test('preload records the working portrait urls for the reader', () async {
      final off = Offline(
        store: store,
        resolved: resolved,
        // Fail the first candidate of every chain, so a fallback has to win.
        probe: (u) async => !u.contains('avg_'),
      );
      await off.preloadStory(
        [_line('charslot', {'name': 'char_002_amiya#1'})],
        const {},
      );
      // Whatever won, it's memoized under the avatar/sprite keys the UI reads.
      expect(resolved.get('av:char_002_amiya#1'), isNotNull);
      expect(resolved.get('sp:char_002_amiya#1'), isNotNull);
    });

    test('preload reports progress that reaches 100%', () async {
      final off =
          Offline(store: store, resolved: resolved, probe: (_) async => true);
      var lastDone = 0, lastTotal = 0;
      await off.preloadStory(
        [
          _line('charslot', {'name': 'char_002_amiya#1'}),
          _line('background', {'image': 'bg_rhodes'}),
          _line('playmusic', {'key': 'm_a'}),
        ],
        const {},
        onProgress: (d, t) {
          lastDone = d;
          lastTotal = t;
        },
      );
      // 2 portrait tasks (avatar + sprite) + 1 bg + 1 sound.
      expect(lastTotal, 4);
      expect(lastDone, 4);
    });

    test('getStoryData prefers the copy on disk over the network', () async {
      final off =
          Offline(store: store, resolved: resolved, probe: (_) async => true);
      await store.saveStory('en_US', 'ch1', {
        'eventName': 'Saved Offline',
        'storyList': [],
      });
      // No network stub here: a fetch would throw, so returning is proof it
      // read from disk.
      final data = await off.getStoryData('en_US', 'ch1');
      expect(data.eventName, 'Saved Offline');
    });

    test('ru reads the en_US copy — it has no server of its own', () async {
      final off =
          Offline(store: store, resolved: resolved, probe: (_) async => true);
      await store.saveStory('en_US', 'ch1', {'eventName': 'Base', 'storyList': []});
      expect(await off.isStoryDownloaded('ru', 'ch1'), isTrue);
      expect((await off.getStoryData('ru', 'ch1')).eventName, 'Base');
    });

    test('isStoryDownloaded is false for a chapter never saved', () async {
      final off =
          Offline(store: store, resolved: resolved, probe: (_) async => true);
      expect(await off.isStoryDownloaded('en_US', 'nope'), isFalse);
    });

    test('verify reports the manifest files present on disk', () async {
      final off =
          Offline(store: store, resolved: resolved, probe: (_) async => true);
      await store.saveStory('en_US', 'ch1', {'storyList': []});
      final a = await store.resolveAndSave(['http://x/a.png']);
      final b = await store.resolveAndSave(['http://x/b.png']);
      await store.saveManifest('en_US', 'ch1', [a!, b!]);

      var res = await off.verifyStory('en_US', 'ch1');
      expect(res.downloaded, isTrue);
      expect(res.hasManifest, isTrue);
      expect((res.total, res.present), (2, 2));

      // Delete one file behind the store's back: verify must notice.
      await File(store.localFilePath(b)!).delete();
      res = await off.verifyStory('en_US', 'ch1');
      expect((res.total, res.present), (2, 1));
    });

    test('verify flags a chapter saved before manifests existed', () async {
      final off =
          Offline(store: store, resolved: resolved, probe: (_) async => true);
      await store.saveStory('en_US', 'ch1', {'storyList': []});
      final res = await off.verifyStory('en_US', 'ch1');
      expect(res.downloaded, isTrue);
      expect(res.hasManifest, isFalse);
    });

    test('verify on an undownloaded chapter reports nothing', () async {
      final off =
          Offline(store: store, resolved: resolved, probe: (_) async => true);
      final res = await off.verifyStory('en_US', 'nope');
      expect(res, (downloaded: false, total: 0, present: 0, hasManifest: false));
    });

    test('removeStory takes the chapter back off disk', () async {
      final off =
          Offline(store: store, resolved: resolved, probe: (_) async => true);
      await store.saveStory('en_US', 'ch1', {'storyList': []});
      expect(await off.isStoryDownloaded('en_US', 'ch1'), isTrue);
      await off.removeStory('en_US', 'ch1');
      expect(await off.isStoryDownloaded('en_US', 'ch1'), isFalse);
    });

    test('downloadedTxts is the on-disk truth OfflineStore reconciles to',
        () async {
      final off =
          Offline(store: store, resolved: resolved, probe: (_) async => true);
      await store.saveStory('en_US', 'ch1', {'storyList': []});
      await store.saveStory('en_US', 'ch2', {'storyList': []});
      expect(off.downloadedTxts()..sort(), ['ch1', 'ch2']);
    });

    test('with no filesystem, downloads are unavailable but nothing throws',
        () async {
      final off =
          Offline(store: null, resolved: resolved, probe: (_) async => true);
      expect(off.isNative, isFalse);
      expect(await off.isStoryDownloaded('en_US', 'ch1'), isFalse);
      expect(off.downloadedTxts(), isEmpty);
      await off.removeStory('en_US', 'ch1'); // no-op, no throw
      final res = await off.verifyStory('en_US', 'ch1');
      expect(res.downloaded, isFalse);
    });
  });
}
