import 'package:flutter_test/flutter_test.dart';

import 'package:ak_reader/data/models.dart';
import 'package:ak_reader/data/parse.dart';
import 'package:ak_reader/data/ru.dart';

RawLine _line(int id, String prop, Map<String, dynamic> attrs) =>
    RawLine(id: id, prop: prop, attributes: attrs);

void main() {
  group('RuOverlay.tryFromJson', () {
    test('parses an overlay', () {
      final ov = RuOverlay.tryFromJson({
        'path': 'activities/act10d5/level_act10d5_st01',
        'names': {'Gummy': 'Гамми'},
        'lines': {'7': 'Текст'},
      });
      expect(ov!.path, 'activities/act10d5/level_act10d5_st01');
      expect(ov.names['Gummy'], 'Гамми');
      expect(ov.lines['7'], 'Текст');
    });

    test('rejects the non-overlay json sharing the folder (_GLOSSARY)', () {
      // No `path` -> not an overlay. The web guarded this with `if (ov?.path)`.
      expect(RuOverlay.tryFromJson({'_comment': 'glossary...'}), isNull);
      expect(RuOverlay.tryFromJson({'path': ''}), isNull);
    });

    test('missing names/lines are empty, not null', () {
      final ov = RuOverlay.tryFromJson({'path': 'a/b'})!;
      expect(ov.names, isEmpty);
      expect(ov.lines, isEmpty);
    });
  });

  group('applyRu', () {
    setUp(() {
      setRuOverlays([
        const RuOverlay(
          path: 'a/ch1',
          names: {'Gummy': 'Гамми', 'Istina': 'Истина'},
          lines: {'1': 'Привет', '2': 'Дождь', '3': 'Выбор'},
        ),
      ]);
    });

    test('an untranslated chapter is returned untouched (English fallback)', () {
      final list = [_line(1, 'name', {'name': 'Gummy', 'content': 'Hi'})];
      expect(identical(applyRu(list, 'no/such'), list), isTrue);
    });

    test('translates a speaker name on a name line', () {
      final out = applyRu(
        [_line(1, 'name', {'name': 'Gummy', 'content': 'Hi'})],
        'a/ch1',
      );
      expect(out.single.attributes['name'], 'Гамми');
      expect(out.single.attributes['content'], 'Привет');
    });

    test('multiline is a speaker line too', () {
      final out = applyRu(
        [_line(1, 'multiline', {'name': 'Istina', 'content': 'Hi'})],
        'a/ch1',
      );
      expect(out.single.attributes['name'], 'Истина');
    });

    test('a speaker with no translation keeps the English name', () {
      final out = applyRu(
        [_line(1, 'name', {'name': 'Kal\'tsit', 'content': 'Hi'})],
        'a/ch1',
      );
      expect(out.single.attributes['name'], 'Kal\'tsit');
      // ...but the line text is still translated.
      expect(out.single.attributes['content'], 'Привет');
    });

    test('names are not translated on non-speaker props', () {
      final out = applyRu(
        [_line(9, 'charslot', {'name': 'Gummy'})],
        'a/ch1',
      );
      expect(out.single.attributes['name'], 'Gummy');
    });

    test('text lands in whichever field the line uses', () {
      final out = applyRu(
        [
          _line(1, 'name', {'content': 'Hi'}),
          _line(2, 'subtitle', {'text': 'Rain'}),
          _line(3, 'decision', {'options': 'Yes;No'}),
        ],
        'a/ch1',
      );
      expect(out[0].attributes['content'], 'Привет');
      expect(out[1].attributes['text'], 'Дождь');
      expect(out[2].attributes['options'], 'Выбор');
    });

    test('falls back to content when the line has no text field at all', () {
      final out = applyRu([_line(1, 'name', {})], 'a/ch1');
      expect(out.single.attributes['content'], 'Привет');
    });

    test('lines with no translation are left alone', () {
      final out = applyRu(
        [_line(99, 'name', {'name': 'Nobody', 'content': 'Untranslated'})],
        'a/ch1',
      );
      expect(out.single.attributes['content'], 'Untranslated');
    });

    test('does not mutate the input lines', () {
      final list = [_line(1, 'name', {'name': 'Gummy', 'content': 'Hi'})];
      applyRu(list, 'a/ch1');
      expect(list.single.attributes['content'], 'Hi');
      expect(list.single.attributes['name'], 'Gummy');
    });

    test('a line parsed with no attributes survives the overlay', () {
      // RawLine.fromJson gives an attribute-less line a const map; the TS
      // mutated in place, which would throw here.
      final list = [RawLine.fromJson({'id': 1, 'prop': 'name'}, 0)];
      expect(() => applyRu(list, 'a/ch1'), returnsNormally);
      expect(applyRu(list, 'a/ch1').single.attributes['content'], 'Привет');
    });

    test('the alt flag is carried across', () {
      final list = [
        RawLine(
          id: 1,
          prop: 'name',
          attributes: {'content': 'Hi'},
          alt: true,
        )
      ];
      expect(applyRu(list, 'a/ch1').single.alt, isTrue);
    });

    test('hasRu reports what is bundled', () {
      expect(hasRu('a/ch1'), isTrue);
      expect(hasRu('no/such'), isFalse);
    });

    test('translated text flows through the parser to the rendered runs', () {
      final out = applyRu(
        [_line(1, 'name', {'name': 'Gummy', 'content': 'Hi'})],
        'a/ch1',
      );
      final items = normalizeStory(out, 'Doctor');
      final dialog = items.whereType<DialogItem>().single;
      expect(dialog.name, 'Гамми');
      expect(dialog.runs.map((r) => r.text).join(), 'Привет');
    });
  });

  group('bundled assets', () {
    testWidgets('the real overlays load from the app bundle', (tester) async {
      // End-to-end over the actual asset bundle: catches a pubspec that forgot
      // assets/ru/, or an overlay file that fails to parse.
      await loadRuOverlays();
      // A chapter known to be translated (assets/ru/level_act10d5_st01.json).
      expect(hasRu('activities/act10d5/level_act10d5_st01'), isTrue);
      expect(hasRu('obviously/not/a/chapter'), isFalse);
    });
  });
}
