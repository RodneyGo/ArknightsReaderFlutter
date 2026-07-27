import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:ak_reader/data/localstore.dart';
import 'package:ak_reader/data/trailers.dart';

void main() {
  group('TrailerIndex.fromJson', () {
    test('parses the { version, trailers: {id: vid} } shape', () {
      final idx = TrailerIndex.fromJson({
        'version': 3,
        'trailers': {'main_10': 'abc123', 'act10d5': 'xyz789'},
      });
      expect(idx.version, 3);
      expect(idx.idFor('main_10'), 'abc123');
      expect(idx.idFor('act10d5'), 'xyz789');
      expect(idx.idFor('nope'), isNull);
    });

    test('accepts a per-entry {id, title} object', () {
      final idx = TrailerIndex.fromJson({
        'version': 1,
        'trailers': {
          'main_10': {'id': 'abc123', 'title': 'Episode 10 PV'},
        },
      });
      expect(idx.idFor('main_10'), 'abc123');
    });

    test('accepts a bare {id: vid} map with no wrapper', () {
      final idx = TrailerIndex.fromJson({'version': 2, 'main_1': 'v1'});
      expect(idx.version, 2);
      expect(idx.idFor('main_1'), 'v1');
    });

    test('drops empty / non-string ids', () {
      final idx = TrailerIndex.fromJson({
        'version': 1,
        'trailers': {'a': '', 'b': 42, 'c': 'ok'},
      });
      expect(idx.idFor('a'), isNull);
      expect(idx.idFor('b'), isNull);
      expect(idx.idFor('c'), 'ok');
    });
  });

  group('refreshIndex', () {
    test('adopts a newer version and notifies', () async {
      final store = TrailerStore(
        store: null,
        fetch: (_) async => {
          'version': 2,
          'trailers': {'main_10': 'vid'},
        },
      )..setIndexForTest(TrailerIndex.empty);
      var notes = 0;
      store.addListener(() => notes++);

      await store.refreshIndex();
      expect(store.index.version, 2);
      expect(store.videoIdFor('main_10'), 'vid');
      expect(notes, 1);
    });

    test('is a no-op for the same version', () async {
      final store = TrailerStore(
        store: null,
        fetch: (_) async => {
          'version': 1,
          'trailers': {'main_10': 'vid'},
        },
      )..setIndexForTest(const TrailerIndex(1, {'other': 'x'}));
      var notes = 0;
      store.addListener(() => notes++);

      await store.refreshIndex();
      expect(notes, 0);
      expect(store.videoIdFor('main_10'), isNull); // not adopted
    });

    test('is silent when the fetch fails (null)', () async {
      final store = TrailerStore(store: null, fetch: (_) async => null)
        ..setIndexForTest(const TrailerIndex(1, {'a': 'b'}));
      await store.refreshIndex();
      expect(store.videoIdFor('a'), 'b'); // unchanged
    });
  });

  group('persistence', () {
    late Directory tmp;
    late LocalStore store;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('ak_trailers');
      store = LocalStore(Directory('${tmp.path}/offline'));
      await store.init();
    });
    tearDown(() => tmp.delete(recursive: true));

    test('refreshIndex persists, and loadIndex reads it back', () async {
      final a = TrailerStore(
        store: store,
        fetch: (_) async => {
          'version': 4,
          'trailers': {'main_1': 'v1'},
        },
      );
      await a.refreshIndex();

      // A fresh store over the same directory sees the cached index.
      final b = TrailerStore(store: store);
      await b.loadIndex();
      expect(b.index.version, 4);
      expect(b.videoIdFor('main_1'), 'v1');
    });
  });
}
