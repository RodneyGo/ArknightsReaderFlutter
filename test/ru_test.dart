import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:ak_reader/data/localstore.dart';
import 'package:ak_reader/data/models.dart';
import 'package:ak_reader/data/parse.dart';
import 'package:ak_reader/data/ru.dart';

RawLine _line(int id, String prop, Map<String, dynamic> attrs) =>
    RawLine(id: id, prop: prop, attributes: attrs);

Map<String, dynamic> _overlay(String path,
        {Map<String, String> names = const {},
        Map<String, String> lines = const {}}) =>
    {'path': path, 'names': names, 'lines': lines};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); // for rootBundle asset loads

  group('index', () {
    test('the bundled fallback index loads when there is no store', () async {
      final ru = RuStore(store: null);
      await ru.loadIndex();
      // A chapter known to be in the generated index.
      expect(ru.hasRu('activities/act10d5/level_act10d5_st01'), isTrue);
      expect(ru.hasRu('obviously/not/a/chapter'), isFalse);
    });

    test('a cached index (meta) wins over the bundled fallback', () async {
      final tmp = await Directory.systemTemp.createTemp('ak_ru_idx');
      addTearDown(() => tmp.delete(recursive: true));
      final store = LocalStore(Directory('${tmp.path}/offline'));
      await store.init();
      await store.saveMeta('ru_index', {
        'version': 5,
        'entries': {'a/b': 'h1'}
      });

      final ru = RuStore(store: store);
      await ru.loadIndex();
      expect(ru.index.version, 5);
      expect(ru.hasRu('a/b'), isTrue);
      // The bundled paths were NOT consulted — the cache won.
      expect(ru.hasRu('activities/act10d5/level_act10d5_st01'), isFalse);
    });

    test('refreshIndex adopts a newer version and notifies', () async {
      final ru = RuStore(
        store: null,
        fetch: (_) async => {
          'version': 2,
          'entries': {'a/b': 'h'}
        },
      )..setIndexForTest(const RuIndex(1, {}));
      var notes = 0;
      ru.addListener(() => notes++);

      await ru.refreshIndex();
      expect(ru.index.version, 2);
      expect(ru.hasRu('a/b'), isTrue);
      expect(notes, 1);
    });

    test('refreshIndex is a no-op for the same version', () async {
      final ru = RuStore(
        store: null,
        fetch: (_) async => {
          'version': 1,
          'entries': {'a/b': 'h'}
        },
      )..setIndexForTest(const RuIndex(1, {'x/y': 'h'}));
      var notes = 0;
      ru.addListener(() => notes++);

      await ru.refreshIndex();
      expect(notes, 0);
      expect(ru.hasRu('a/b'), isFalse); // not adopted
    });
  });

  group('episodeFullyTranslated', () {
    final ru = RuStore(store: null)
      ..setIndexForTest(const RuIndex(1, {'a/1': 'h', 'a/2': 'h'}));

    test('true only when every chapter is translated', () {
      expect(ru.episodeFullyTranslated(['a/1', 'a/2']), isTrue);
      expect(ru.episodeFullyTranslated(['a/1', 'a/3']), isFalse); // a/3 missing
      expect(ru.episodeFullyTranslated([]), isFalse);
    });
  });

  group('overlayFor', () {
    late Directory tmp;
    late LocalStore store;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('ak_ru_ov');
      store = LocalStore(Directory('${tmp.path}/offline'));
      await store.init();
    });
    tearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    test('null (no fetch) when the chapter is not in the index', () async {
      var fetches = 0;
      final ru = RuStore(store: store, fetch: (_) async {
        fetches++;
        return null;
      })
        ..setIndexForTest(const RuIndex(1, {}));
      expect(await ru.overlayFor('a/none'), isNull);
      expect(fetches, 0);
    });

    test('fetches once, then serves the saved copy without re-fetching',
        () async {
      var fetches = 0;
      final ru = RuStore(store: store, fetch: (_) async {
        fetches++;
        return _overlay('a/ch1', lines: {'1': 'Привет'});
      })
        ..setIndexForTest(const RuIndex(1, {'a/ch1': 'h1'}));

      expect((await ru.overlayFor('a/ch1'))!.lines['1'], 'Привет');
      expect(fetches, 1);

      // A fresh store instance (no in-memory cache) reads the saved overlay.
      final ru2 = RuStore(store: store, fetch: (_) async {
        fetches++;
        return null;
      })
        ..setIndexForTest(const RuIndex(1, {'a/ch1': 'h1'}));
      expect((await ru2.overlayFor('a/ch1'))!.lines['1'], 'Привет');
      expect(fetches, 1); // served from disk, no new fetch
    });

    test('a changed hash invalidates the saved overlay and re-fetches',
        () async {
      final store2 = store;
      // First: save under hash h1.
      final ruA = RuStore(store: store2, fetch: (_) async {
        return _overlay('a/ch1', lines: {'1': 'Старый'});
      })
        ..setIndexForTest(const RuIndex(1, {'a/ch1': 'h1'}));
      await ruA.overlayFor('a/ch1');

      // New store instance whose index has a DIFFERENT hash for the same path.
      var refetched = false;
      final ruB = RuStore(store: store2, fetch: (_) async {
        refetched = true;
        return _overlay('a/ch1', lines: {'1': 'Новый'});
      })
        ..setIndexForTest(const RuIndex(2, {'a/ch1': 'h2'}));

      expect((await ruB.overlayFor('a/ch1'))!.lines['1'], 'Новый');
      expect(refetched, isTrue); // stale cache was bypassed
    });

    test('fetch failure yields null (English fallback)', () async {
      final ru = RuStore(store: store, fetch: (_) async => null)
        ..setIndexForTest(const RuIndex(1, {'a/ch1': 'h1'}));
      expect(await ru.overlayFor('a/ch1'), isNull);
    });
  });

  group('applyRu', () {
    RuStore ruWith(Map<String, dynamic> overlay) => RuStore(
          store: null,
          fetch: (_) async => overlay,
        )..setIndexForTest(const RuIndex(1, {'a/ch1': 'h1'}));

    test('an untranslated chapter returns the list untouched', () async {
      final ru = ruWith(_overlay('a/ch1'));
      final list = [_line(1, 'name', {'name': 'Gummy', 'content': 'Hi'})];
      expect(await ru.applyRu(list, 'no/such'), same(list));
    });

    test('translates a speaker name and the line text', () async {
      final ru = ruWith(_overlay('a/ch1',
          names: {'Gummy': 'Гамми'}, lines: {'1': 'Привет'}));
      final out = await ru.applyRu(
          [_line(1, 'name', {'name': 'Gummy', 'content': 'Hi'})], 'a/ch1');
      expect(out.single.attributes['name'], 'Гамми');
      expect(out.single.attributes['content'], 'Привет');
    });

    test('text lands in whichever field the line uses', () async {
      final ru = ruWith(_overlay('a/ch1',
          lines: {'1': 'A', '2': 'B', '3': 'C'}));
      final out = await ru.applyRu([
        _line(1, 'name', {'content': 'x'}),
        _line(2, 'subtitle', {'text': 'x'}),
        _line(3, 'decision', {'options': 'x'}),
      ], 'a/ch1');
      expect(out[0].attributes['content'], 'A');
      expect(out[1].attributes['text'], 'B');
      expect(out[2].attributes['options'], 'C');
    });

    test('does not mutate the input lines', () async {
      final ru = ruWith(_overlay('a/ch1', lines: {'1': 'Привет'}));
      final list = [_line(1, 'name', {'name': 'Gummy', 'content': 'Hi'})];
      await ru.applyRu(list, 'a/ch1');
      expect(list.single.attributes['content'], 'Hi');
    });

    test('an attribute-less line survives the overlay', () async {
      final ru = ruWith(_overlay('a/ch1', lines: {'1': 'Привет'}));
      final list = [RawLine.fromJson({'id': 1, 'prop': 'name'}, 0)];
      final out = await ru.applyRu(list, 'a/ch1');
      expect(out.single.attributes['content'], 'Привет');
    });

    test('translated text flows through the parser to rendered runs', () async {
      final ru = ruWith(_overlay('a/ch1',
          names: {'Gummy': 'Гамми'}, lines: {'1': 'Привет'}));
      final out = await ru.applyRu(
          [_line(1, 'name', {'name': 'Gummy', 'content': 'Hi'})], 'a/ch1');
      final items = normalizeStory(out, 'Doctor');
      final dialog = items.whereType<DialogItem>().single;
      expect(dialog.name, 'Гамми');
      expect(dialog.runs.map((r) => r.text).join(), 'Привет');
    });
  });
}
