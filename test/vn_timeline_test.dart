import 'package:flutter_test/flutter_test.dart';

import 'package:ak_reader/data/models.dart';
import 'package:ak_reader/ui/reader_audio.dart';
import 'package:ak_reader/ui/vn_timeline.dart';

DialogItem _dialog(int id, String name, String text) =>
    DialogItem(id: id, name: name, runs: [TextRun(text)]);
NarrationItem _narr(int id, String text) =>
    NarrationItem(id: id, runs: [TextRun(text)]);
SubtitleItem _sub(int id, String text) =>
    SubtitleItem(id: id, runs: [TextRun(text)]);
SoundItem _music(int id, String key) => SoundItem(id: id, key: key, music: true);
SoundItem _sfx(int id, String key) => SoundItem(id: id, key: key, music: false);
SceneBreakItem _break(int id) => SceneBreakItem(id: id);
DecisionItem _decision(int id) =>
    DecisionItem(id: id, group: 1, options: const ['a'], values: const ['1']);

void main() {
  group('walkToVisible', () {
    test('stops on the item it starts on when that is renderable', () {
      final items = [_dialog(0, 'A', 'hi'), _dialog(1, 'B', 'yo')];
      final w = walkToVisible(items, 0);
      expect(w.index, 0);
      expect(w.sounds, isEmpty);
    });

    test('steps over sounds and scene breaks, reporting the sounds passed', () {
      final items = [
        _music(0, 'm_a'),
        _break(1),
        _sfx(2, 's_a'),
        _dialog(3, 'A', 'hi'),
      ];
      final w = walkToVisible(items, 0);
      expect(w.index, 3);
      expect(w.sounds.map((s) => s.key), ['m_a', 's_a']);
    });

    test('decisions are renderable and stop the walk', () {
      final items = [_sfx(0, 's'), _decision(1)];
      expect(walkToVisible(items, 0).index, 1);
    });

    test('running off the end reports items.length (the end card)', () {
      final items = [_dialog(0, 'A', 'hi'), _music(1, 'm_a')];
      final w = walkToVisible(items, 1);
      expect(w.index, 2);
      // The trailing music still fires on the way out.
      expect(w.sounds.map((s) => s.key), ['m_a']);
    });

    test('an empty chapter ends immediately', () {
      expect(walkToVisible(const [], 0).index, 0);
    });
  });

  group('activeMusicKeyAt', () {
    final items = [
      _music(0, 'm_a'),
      _dialog(1, 'A', 'one'),
      _music(2, 'm_b'),
      _dialog(3, 'A', 'two'),
    ];

    test('finds the most recent track at or before the index', () {
      expect(activeMusicKeyAt(items, 1), 'm_a');
      expect(activeMusicKeyAt(items, 3), 'm_b');
    });

    test('a PlayMusic on the index itself counts', () {
      expect(activeMusicKeyAt(items, 2), 'm_b');
    });

    test('null before any music has played', () {
      expect(activeMusicKeyAt([_dialog(0, 'A', 'x')], 0), isNull);
    });

    test('an index past the end clamps to the last item', () {
      expect(activeMusicKeyAt(items, 99), 'm_b');
    });
  });

  group('truncateRuns', () {
    const runs = [TextRun('Hello '), TextRun('world', '#ff0000')];

    test('nothing shown yet', () {
      expect(truncateRuns(runs, 0), isEmpty);
    });

    test('cuts inside the first run', () {
      final out = truncateRuns(runs, 3);
      expect(out.map((r) => r.text), ['Hel']);
    });

    test('keeps the colour when the cut lands in a styled run', () {
      final out = truncateRuns(runs, 8);
      expect(out.map((r) => r.text), ['Hello ', 'wo']);
      expect(out.last.color, '#ff0000');
    });

    test('the full string returns every run', () {
      expect(truncateRuns(runs, 11), runs);
    });

    test('over-long counts are harmless', () {
      expect(truncateRuns(runs, 999).map((r) => r.text), ['Hello ', 'world']);
    });
  });

  group('vnTypeSpeedMs', () {
    test('known speeds', () {
      expect(vnTypeSpeedMs('slow'), 52);
      expect(vnTypeSpeedMs('normal'), 28);
      expect(vnTypeSpeedMs('fast'), 11);
    });

    test('instant is zero — the caller skips the typewriter', () {
      expect(vnTypeSpeedMs('instant'), 0);
    });

    test('an unknown setting falls back to normal', () {
      expect(vnTypeSpeedMs('nonsense'), 28);
    });
  });

  group('vnLog', () {
    test('lists every renderable line with its index, skipping non-lines', () {
      final items = [
        _dialog(0, 'Amiya', 'Doctor!'),
        _music(1, 'm_a'),
        _narr(2, 'The rain fell.'),
        _decision(3),
        _sub(4, 'Chapter 1'),
      ];
      expect(vnLog(items), [
        (index: 0, name: 'Amiya', text: 'Doctor!'),
        (index: 2, name: '', text: 'The rain fell.'),
        (index: 4, name: '', text: 'Chapter 1'),
      ]);
    });

    test('log indices address the original list, for jumping', () {
      final items = [_music(0, 'm'), _dialog(1, 'A', 'x')];
      expect(vnLog(items).single.index, 1);
    });
  });

  group('isVnVisible', () {
    test('lines and decisions render; sounds and breaks do not', () {
      expect(isVnVisible(_dialog(0, 'A', 'x')), isTrue);
      expect(isVnVisible(_narr(0, 'x')), isTrue);
      expect(isVnVisible(_sub(0, 'x')), isTrue);
      expect(isVnVisible(_decision(0)), isTrue);
      expect(isVnVisible(_music(0, 'm')), isFalse);
      expect(isVnVisible(_break(0)), isFalse);
    });
  });
}
