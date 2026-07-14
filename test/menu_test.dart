import 'package:flutter_test/flutter_test.dart';
import 'package:ak_reader/data/menu.dart';

Map<String, dynamic> ev(
  String entryType, {
  String? name,
  num startTime = 0,
  List<String> txts = const ['a'],
}) =>
    {
      'entryType': entryType,
      if (name != null) 'name': name,
      'startTime': startTime,
      'infoUnlockDatas': [
        for (final t in txts)
          {'storyTxt': t, 'storyCode': t.toUpperCase(), 'storyName': 'N$t', 'avgTag': ''},
      ],
    };

void main() {
  group('classify', () {
    test('maps entryType to category, honoring the intermezzi set', () {
      expect(classify('main_0', 'MAINLINE'), 'maintheme');
      expect(classify('act1', 'ACTIVITY'), 'sidestory');
      expect(classify('act9d0', 'ACTIVITY'), 'intermezzi');
      expect(classify('set1', 'MINI_ACTIVITY'), 'storyset');
      expect(classify('rec1', 'NONE'), 'records');
      expect(classify('x', null), 'records');
    });
  });

  group('mainOrder', () {
    test('extracts the first number, else 0', () {
      expect(mainOrder('main_3'), 3);
      expect(mainOrder('level_main_10-01'), 10);
      expect(mainOrder('noDigits'), 0);
    });
  });

  group('buildMenu', () {
    test('categories come back in fixed order, only non-empty ones', () {
      final menu = buildMenu({
        'rec1': ev('NONE'),
        'main_2': ev('MAINLINE'),
        'act9d0': ev('ACTIVITY'),
        'act1': ev('ACTIVITY'),
      });
      expect(menu.categories.map((c) => c.key),
          ['maintheme', 'intermezzi', 'sidestory', 'records']);
      expect(menu.categories.first.label, 'Main Story');
    });

    test('main story sorts by embedded number; side story by startTime', () {
      final menu = buildMenu({
        'main_10': ev('MAINLINE'),
        'main_2': ev('MAINLINE'),
        'actB': ev('ACTIVITY', startTime: 200),
        'actA': ev('ACTIVITY', startTime: 100),
      });
      final main = menu.categories.firstWhere((c) => c.key == 'maintheme');
      expect(main.events.map((e) => e.id), ['main_2', 'main_10']);
      final side = menu.categories.firstWhere((c) => c.key == 'sidestory');
      expect(side.events.map((e) => e.id), ['actA', 'actB']);
    });

    test('stable order for equal sort keys (table order preserved)', () {
      final menu = buildMenu({
        'actX': ev('ACTIVITY', startTime: 5),
        'actY': ev('ACTIVITY', startTime: 5),
        'actZ': ev('ACTIVITY', startTime: 5),
      });
      final side = menu.categories.single;
      expect(side.events.map((e) => e.id), ['actX', 'actY', 'actZ']);
    });

    test('events with no valid stories are dropped', () {
      final menu = buildMenu({
        'empty': {'entryType': 'MAINLINE', 'infoUnlockDatas': []},
        'noTxt': {
          'entryType': 'MAINLINE',
          'infoUnlockDatas': [
            {'storyCode': 'X'}
          ]
        },
        'ok': ev('MAINLINE'),
      });
      expect(menu.categories.single.events.map((e) => e.id), ['ok']);
    });

    test('flat list carries the owning event name', () {
      final menu = buildMenu({
        'main_1': ev('MAINLINE', name: 'Prologue', txts: ['s1', 's2']),
      });
      expect(menu.flat.map((f) => f.txt), ['s1', 's2']);
      expect(menu.flat.every((f) => f.event == 'Prologue'), isTrue);
    });

    test('falls back to eventid when the event has no name', () {
      final menu = buildMenu({'main_1': ev('MAINLINE')});
      expect(menu.categories.single.events.single.name, 'main_1');
    });
  });

  group('neighborsIn', () {
    final menu = buildMenu({
      'main_1': ev('MAINLINE', txts: ['s1', 's2', 's3']),
    });

    test('returns prev/next within the event', () {
      final n = neighborsIn(menu, 's2');
      expect(n.prev?.txt, 's1');
      expect(n.next?.txt, 's3');
    });

    test('nulls at the ends and for unknown txt', () {
      expect(neighborsIn(menu, 's1').prev, isNull);
      expect(neighborsIn(menu, 's3').next, isNull);
      final miss = neighborsIn(menu, 'nope');
      expect(miss.prev, isNull);
      expect(miss.next, isNull);
    });
  });
}
