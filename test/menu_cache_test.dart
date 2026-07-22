import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:ak_reader/data/localstore.dart';
import 'package:ak_reader/data/menu.dart';

/// A minimal review-table with the given event ids, each carrying one chapter.
Map<String, dynamic> _table(List<String> ids) => {
      for (final id in ids)
        id: {
          'entryType': 'ACTIVITY',
          'name': id.toUpperCase(),
          'startTime': 0,
          'infoUnlockDatas': [
            {'storyTxt': '${id}_st01', 'storyCode': '', 'storyName': '', 'avgTag': ''},
          ],
        },
    };

int _eventCount(Menu m) =>
    m.categories.fold(0, (n, c) => n + c.events.length);

void main() {
  late Directory tmp;
  late LocalStore store;
  const meta = 'en_US__story_review_table';

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('ak_menu_test');
    store = LocalStore(Directory('${tmp.path}/offline'));
    await store.init();
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('a cached table is used without any network call', () async {
    await store.saveMeta(meta, _table(['act1', 'act2']));
    // fetch throws if called — proving the cache served the request.
    final menu = await fetchMenu('en_US', store: store,
        fetch: (_) async => throw StateError('network hit'));
    expect(_eventCount(menu), 2);
  });

  test('with no cache, the network table is fetched and saved', () async {
    final menu = await fetchMenu('en_US', store: store,
        fetch: (_) async => _table(['act1']));
    expect(_eventCount(menu), 1);
    // Saved for next time.
    expect(await store.readMeta(meta), isNotNull);
  });

  test('refreshMenu merges newly-added events and returns the rebuilt menu',
      () async {
    await store.saveMeta(meta, _table(['act1']));
    final menu = await refreshMenu('en_US', store: store,
        fetch: (_) async => _table(['act1', 'act2']));
    expect(menu, isNotNull);
    expect(_eventCount(menu!), 2);
    // Persisted, so a later fetch sees both.
    final reread = await fetchMenu('en_US', store: store,
        fetch: (_) async => throw StateError('network hit'));
    expect(_eventCount(reread), 2);
  });

  test('refreshMenu returns null when nothing new appeared', () async {
    await store.saveMeta(meta, _table(['act1', 'act2']));
    final menu = await refreshMenu('en_US', store: store,
        fetch: (_) async => _table(['act1', 'act2']));
    expect(menu, isNull);
  });

  test('an event dropped upstream survives in the cache', () async {
    await store.saveMeta(meta, _table(['act1', 'act2']));
    // Upstream now only has act1 + a brand new act3.
    final menu = await refreshMenu('en_US', store: store,
        fetch: (_) async => _table(['act1', 'act3']));
    expect(menu, isNotNull);
    // Union: act1, act2 (kept), act3 (added).
    expect(_eventCount(menu!), 3);
  });
}
