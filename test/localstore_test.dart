import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ak_reader/data/localstore.dart';

void main() {
  late Directory tmp;
  late LocalStore store;
  late int fetchCount;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('ls_test');
    fetchCount = 0;
    // Fake fetcher: any url ending in ".404" fails; otherwise returns bytes.
    store = LocalStore(
      Directory('${tmp.path}/offline'),
      fetcher: (url) async {
        fetchCount++;
        if (url.endsWith('.404')) return null;
        return Uint8List.fromList(url.codeUnits);
      },
    );
    await store.init();
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  group('assets', () {
    test('resolveAndSave picks the first working candidate and saves it', () async {
      final url = await store.resolveAndSave(['a/x.404', 'b/y.png']);
      expect(url, 'b/y.png');
      expect(store.isAssetSaved('b/y.png'), isTrue);
      expect(store.isAssetSaved('a/x.404'), isFalse);
      expect(await store.verifyAssetOnDisk('b/y.png'), isTrue);
      expect(store.localFilePath('b/y.png'), isNotNull);
      expect(store.localFilePath('a/x.404'), isNull);
    });

    test('an already-saved candidate skips the network entirely', () async {
      await store.resolveAndSave(['b/y.png']);
      final before = fetchCount;
      final url = await store.resolveAndSave(['b/y.png']);
      expect(url, 'b/y.png');
      expect(fetchCount, before); // no additional fetch
    });

    test('returns null when every candidate fails', () async {
      expect(await store.resolveAndSave(['a.404', 'b.404']), isNull);
    });

    test('urlmap persists and reloads', () async {
      await store.resolveAndSave(['b/y.png']);
      await store.persistUrlMap();
      final reopened = LocalStore(Directory('${tmp.path}/offline'));
      await reopened.init();
      expect(reopened.isAssetSaved('b/y.png'), isTrue);
      expect(reopened.localFilePath('b/y.png'), isNotNull);
    });
  });

  group('stories + index', () {
    test('save/read/has and downloaded-txts index', () async {
      await store.saveStory('en_US', 'ch1', {'storyList': [], 'eventName': 'X'});
      expect(await store.hasStory('en_US', 'ch1'), isTrue);
      expect(await store.hasStory('en_US', 'nope'), isFalse);
      final data = await store.readStory('en_US', 'ch1');
      expect(data?['eventName'], 'X');
      expect(store.getDownloadedTxts(), ['ch1']);
    });

    test('index persists across reopen', () async {
      await store.saveStory('en_US', 'ch1', {});
      await store.saveStory('ja_JP', 'ch2', {});
      final reopened = LocalStore(Directory('${tmp.path}/offline'));
      await reopened.init();
      expect(reopened.getDownloadedTxts().toSet(), {'ch1', 'ch2'});
    });

    test('removeStoryFiles deletes files and updates the index', () async {
      await store.saveStory('en_US', 'ch1', {});
      await store.saveManifest('en_US', 'ch1', ['u1']);
      await store.removeStoryFiles('en_US', 'ch1');
      expect(await store.hasStory('en_US', 'ch1'), isFalse);
      expect(await store.readManifest('en_US', 'ch1'), isNull);
      expect(store.getDownloadedTxts(), isEmpty);
    });

    test('txt with slashes is filed safely', () async {
      await store.saveStory('en_US', 'obt/main/ch', {'ok': true});
      expect(await store.hasStory('en_US', 'obt/main/ch'), isTrue);
      expect((await store.readStory('en_US', 'obt/main/ch'))?['ok'], isTrue);
    });
  });

  group('meta + manifest', () {
    test('meta round-trips', () async {
      await store.saveMeta('story_variables', {'k': 'v'});
      expect(await store.hasMeta('story_variables'), isTrue);
      expect((await store.readMeta('story_variables'))?['k'], 'v');
      expect(await store.readMeta('missing'), isNull);
    });

    test('manifest round-trips', () async {
      await store.saveManifest('en_US', 'ch1', ['u1', 'u2']);
      expect(await store.readManifest('en_US', 'ch1'), ['u1', 'u2']);
    });
  });

  test('clearAll wipes files and resets state', () async {
    await store.resolveAndSave(['b/y.png']);
    await store.saveStory('en_US', 'ch1', {});
    await store.clearAll();
    expect(store.isAssetSaved('b/y.png'), isFalse);
    expect(store.getDownloadedTxts(), isEmpty);
    expect(await store.hasStory('en_US', 'ch1'), isFalse);
    // and a fresh store sees nothing
    final reopened = LocalStore(Directory('${tmp.path}/offline'));
    await reopened.init();
    expect(reopened.getDownloadedTxts(), isEmpty);
  });
}
