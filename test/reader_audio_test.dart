import 'package:flutter_test/flutter_test.dart';

import 'package:ak_reader/data/models.dart';
import 'package:ak_reader/ui/reader_audio.dart';
import 'package:ak_reader/ui/row_geometry.dart';

SoundItem _music(int id, String key) => SoundItem(id: id, key: key, music: true);
SoundItem _sfx(int id, String key) => SoundItem(id: id, key: key, music: false);
NarrationItem _line(int id) => NarrationItem(id: id, runs: const [TextRun('x')]);

/// Rows of uniform [extent] starting at [firstTop], for indices [from]..[to].
RowGeometry _geom({
  required int from,
  required int to,
  required double firstTop,
  double extent = 50,
  double viewport = 600,
}) {
  final rows = <RowBox>[];
  var top = firstTop;
  for (var i = from; i <= to; i++) {
    rows.add((index: i, top: top, bottom: top + extent));
    top += extent;
  }
  return RowGeometry(rows, viewport);
}

void main() {
  group('musicRowsOf', () {
    test('collects PlayMusic rows with their position, ignoring SFX', () {
      final items = [
        _line(0),
        _music(1, 'm_a'),
        _sfx(2, 's_a'),
        _line(3),
        _music(4, 'm_b'),
      ];
      expect(musicRowsOf(items), [
        (id: 1, index: 1, key: 'm_a'),
        (id: 4, index: 4, key: 'm_b'),
      ]);
    });

    test('empty when a chapter has no music', () {
      expect(musicRowsOf([_line(0), _sfx(1, 's')]), isEmpty);
    });
  });

  group('activeMusic', () {
    final music = <MusicRow>[
      (id: 1, index: 1, key: 'm_a'),
      (id: 5, index: 5, key: 'm_b'),
    ];

    test('a track starts as its row nears the top of the viewport', () {
      // Row 1 sits 200px down — inside the 240px lookahead, as in the web rule.
      final geom = _geom(from: 0, to: 8, firstTop: 150);
      expect(activeMusic(music, geom)?.id, 1);
    });

    test('a row still below the lookahead has not started', () {
      // Row 1 at 300px: on screen, but past the lookahead.
      final geom = _geom(from: 0, to: 8, firstTop: 250);
      expect(activeMusic(music, geom), isNull);
    });

    test('the later track wins once it is reached', () {
      // Scrolled so rows 0-3 are above the viewport: row 5 is at 100px.
      final geom = _geom(from: 0, to: 8, firstTop: -150);
      expect(activeMusic(music, geom)?.id, 5);
    });

    test('rows scrolled off the top count as reached even when unbuilt', () {
      // Only rows 4+ are still built; row 1 is long gone above.
      final geom = _geom(from: 4, to: 9, firstTop: 400);
      // Row 5 hasn't reached the lookahead yet, but row 1 is behind us.
      expect(activeMusic(music, geom)?.id, 1);
    });

    test('unbuilt rows below the viewport do not start', () {
      final geom = _geom(from: 0, to: 3, firstTop: 300);
      expect(activeMusic(music, geom), isNull);
    });

    test('no music, no track', () {
      expect(activeMusic(const [], _geom(from: 0, to: 5, firstTop: 0)), isNull);
    });
  });

  group('sfxCrossingCentre', () {
    test('fires when a sound row crosses the middle of the viewport', () {
      final items = [_line(0), _sfx(1, 's_a'), _line(2)];
      // viewport 600 -> centre 300. Row 1 spans 250..300, centre 275 (<= 300).
      const geom = RowGeometry([
        (index: 0, top: 200.0, bottom: 250.0),
        (index: 1, top: 250.0, bottom: 300.0),
      ], 600);
      expect(sfxCrossingCentre(items, geom, {}).map((s) => s.id), [1]);
    });

    test('does not fire while the row is still below the centre', () {
      final items = [_line(0), _sfx(1, 's_a')];
      const geom = RowGeometry([
        (index: 1, top: 400.0, bottom: 450.0), // centre 425 > 300
      ], 600);
      expect(sfxCrossingCentre(items, geom, {}), isEmpty);
    });

    test('does not re-fire a sound that already played', () {
      final items = [_sfx(1, 's_a')];
      const geom = RowGeometry([
        (index: 0, top: 250.0, bottom: 300.0),
      ], 600);
      expect(sfxCrossingCentre(items, geom, {1}), isEmpty);
    });

    test('ignores music rows — those switch themselves', () {
      final items = [_music(1, 'm_a')];
      const geom = RowGeometry([
        (index: 0, top: 250.0, bottom: 300.0),
      ], 600);
      expect(sfxCrossingCentre(items, geom, {}), isEmpty);
    });

    test('a row scrolled off the top does not fire', () {
      final items = [_sfx(1, 's_a')];
      const geom = RowGeometry([
        (index: 0, top: -100.0, bottom: -50.0), // centre negative
      ], 600);
      expect(sfxCrossingCentre(items, geom, {}), isEmpty);
    });
  });

  group('RowGeometry', () {
    test('visible rows exclude the cacheExtent rows above and below', () {
      const geom = RowGeometry([
        (index: 0, top: -120.0, bottom: -20.0), // above
        (index: 1, top: -20.0, bottom: 80.0), // straddles the top edge
        (index: 2, top: 80.0, bottom: 180.0), // on screen
        (index: 3, top: 580.0, bottom: 680.0), // straddles the bottom edge
        (index: 4, top: 680.0, bottom: 780.0), // below
      ], 600);
      expect(geom.visibleIndices, [1, 2, 3]);
      expect(geom.firstVisibleIndex, 1);
    });

    test('empty geometry has no visible rows', () {
      expect(RowGeometry.empty.visibleIndices, isEmpty);
      expect(RowGeometry.empty.firstVisibleIndex, isNull);
    });
  });
}
