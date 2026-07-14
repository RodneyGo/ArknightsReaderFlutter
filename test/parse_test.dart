// Validation harness for the ported data layer.
//
// These assert the behaviours that the TypeScript source guarantees, so any
// drift in the Dart port is caught immediately. Run with `flutter test` (or
// `dart test`) once Flutter/Dart is installed.
//
// As the port grows, the highest-value additions here are *golden* tests: drop a
// real story JSON into test/fixtures/, capture the current TS `normalizeStory`
// output, and assert the Dart output matches item-for-item.

import 'package:flutter_test/flutter_test.dart';
import 'package:ak_reader/data/models.dart';
import 'package:ak_reader/data/parse.dart';
import 'package:ak_reader/data/source.dart';

RawLine line(int id, String prop, [Map<String, dynamic>? attrs]) =>
    RawLine(id: id, prop: prop, attributes: attrs);

void main() {
  group('parseContent (structured runs)', () {
    String plain(List<TextRun> runs) => runs.map((r) => r.text).join();

    test('substitutes the doctor nickname (both cases)', () {
      final runs = parseContent('Hi {@nickname} and {@Nickname}', 'Kal');
      expect(runs, [const TextRun('Hi Kal and Kal')]);
    });

    test('converts every newline form to a line break', () {
      expect(plain(parseContent('a\nb\r\nc\\nd', 'D')), 'a\nb\nc\nd');
    });

    test('drops near-black color tags but keeps visible ones as colored runs', () {
      expect(parseContent('<color=#000000>hi</color>', 'D'),
          [const TextRun('hi')]);
      expect(parseContent('<color=black>hi</color>', 'D'), [const TextRun('hi')]);
      expect(parseContent('<color=#ff0000>hi</color>', 'D'),
          [const TextRun('hi', '#ff0000')]);
    });

    test('splits a colored span out of surrounding plain text', () {
      expect(
        parseContent('a<color=#ff0000>b</color>c', 'D'),
        const [TextRun('a'), TextRun('b', '#ff0000'), TextRun('c')],
      );
    });

    test('{@nbs} becomes a non-breaking space', () {
      expect(parseContent('a{@nbs}b', 'D'), const [TextRun('a b')]);
    });

    test('returns empty runs for null/empty content', () {
      expect(parseContent(null, 'D'), isEmpty);
      expect(parseContent('', 'D'), isEmpty);
    });

    test('htmlToRuns round-trips the controlled subset', () {
      expect(htmlToRuns('x<br>y'), const [TextRun('x\ny')]);
      expect(htmlToRuns('a&nbsp;b'), const [TextRun('a b')]);
      expect(htmlToRuns('<span style="color:red">z</span>'),
          const [TextRun('z', 'red')]);
      // stray '<' / '&' that aren't our tokens stay literal
      expect(htmlToRuns('2<3 & 4'), const [TextRun('2<3 & 4')]);
    });
  });

  group('normalizeStory — speaker model', () {
    test('old "character" format resolves the focused portrait', () {
      final items = normalizeStory([
        line(0, 'Character', {'name': 'char_010_chen_1', 'name2': 'char_002_amiya_1', 'focus': '2'}),
        line(1, 'name', {'name': 'Amiya', 'content': 'Hello.'}),
      ], 'Dr');
      expect(items, hasLength(1));
      final d = items.single as DialogItem;
      expect(d.name, 'Amiya');
      expect(d.portrait, 'char_002_amiya_1');
    });

    test('new "charslot" format tracks l/m/r + focus', () {
      final items = normalizeStory([
        line(0, 'charslot', {'slot': 'left', 'name': 'char_a'}),
        line(1, 'charslot', {'slot': 'right', 'name': 'char_b', 'focus': 'right'}),
        line(2, 'name', {'name': 'B', 'content': 'Line.'}),
      ], 'Dr');
      final d = items.single as DialogItem;
      expect(d.portrait, 'char_b');
    });

    test('falls back to the sole on-stage character when no focus', () {
      final items = normalizeStory([
        line(0, 'charslot', {'slot': 'middle', 'name': 'char_solo'}),
        line(1, 'name', {'name': 'X', 'content': 'Hi.'}),
      ], 'Dr');
      expect((items.single as DialogItem).portrait, 'char_solo');
    });

    test('empty name renders as narration (no portrait)', () {
      final items = normalizeStory([
        line(0, 'name', {'name': '', 'content': 'The wind howls.'}),
      ], 'Dr');
      expect(items.single, isA<NarrationItem>());
    });
  });

  group('normalizeStory — scenes & branching', () {
    test('background change inserts a scene break and backfills the opening bg',
        () {
      final items = normalizeStory([
        line(0, 'name', {'name': 'A', 'content': 'Before any bg.'}),
        line(1, 'background', {'image': 'bg_forest'}),
        line(2, 'name', {'name': 'A', 'content': 'After bg.'}),
      ], 'Dr');
      // dialog, scenebreak, dialog
      expect(items.map((i) => i.kind),
          ['dialog', 'scenebreak', 'dialog']);
      // opening line backfilled with the first real background
      expect(items[0].bg, 'bg_forest');
    });

    test('bg_black is ignored as a background', () {
      final items = normalizeStory([
        line(0, 'background', {'image': 'bg_black'}),
        line(1, 'name', {'name': 'A', 'content': 'x'}),
      ], 'Dr');
      expect(items.single.bg, isNull);
    });

    test('decision opens a group and predicate scopes following lines', () {
      final items = normalizeStory([
        line(0, 'decision', {'options': 'Yes;No', 'values': '1;2'}),
        line(1, 'predicate', {'references': '1'}),
        line(2, 'name', {'name': 'A', 'content': 'Only if Yes.'}),
        line(3, 'predicate', {'references': '1;2'}),
        line(4, 'name', {'name': 'A', 'content': 'Common.'}),
      ], 'Dr');
      final decision = items[0] as DecisionItem;
      expect(decision.options, ['Yes', 'No']);
      expect(decision.values, ['1', '2']);
      expect(decision.group, 1);

      final onlyYes = items[1] as DialogItem;
      expect(onlyYes.branch, const Branch(1, ['1']));

      final common = items[2] as DialogItem;
      expect(common.branch, const Branch(1, ['1', '2']));
    });
  });

  group('source — url builders', () {
    test('avatarCandidates parses #face\$body and swaps char_->avg_', () {
      final c = avatarCandidates('char_010_chen_1#2\$3');
      // first candidate = pre-cropped thumb of the full raw name
      expect(c.first.url, contains('/thumbs/'));
      expect(c.first.crop, isFalse);
      // the avg_ swap variant is present in the art candidates
      expect(c.any((x) => x.url.contains('avg_010_chen')), isTrue);
      // operator-icon fallback drops the skin suffix (_1)
      expect(c.any((x) => x.url.contains('char_010_chen.png')), isTrue);
      // last candidate = mystery avatar
      expect(c.last.url, mysteryAvatar);
    });

    test('spriteCandidates tries the raw char_ prefix before avg_', () {
      final s = spriteCandidates('char_010_chen_1#1\$1');
      final rawIdx = s.indexWhere((u) => u.contains('char_010_chen'));
      final avgIdx = s.indexWhere((u) => u.contains('avg_010_chen'));
      expect(rawIdx, greaterThanOrEqualTo(0));
      expect(avgIdx, greaterThan(rawIdx));
    });

    test('soundSrcs strips a leading \$ and lists avg/ first', () {
      final urls = soundSrcs('\$m_sys_test');
      expect(urls.first, endsWith('/avg/m_sys_test.mp3'));
      expect(urls.every((u) => !u.contains('\$')), isTrue);
    });

    test('empty portrait id yields no candidates', () {
      expect(avatarCandidates(''), isEmpty);
      expect(spriteCandidates('  '), isEmpty);
    });
  });
}
