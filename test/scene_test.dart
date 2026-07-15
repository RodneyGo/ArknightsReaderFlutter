import 'package:flutter_test/flutter_test.dart';

import 'package:ak_reader/data/models.dart';
import 'package:ak_reader/ui/reader_screen.dart';

NarrationItem _row(int id, {String? bg, bool img = false}) => NarrationItem(
      id: id,
      runs: const [TextRun('x')],
      bg: bg,
      bgImage: img,
    );

void main() {
  group('sceneForVisible', () {
    test('takes the scene of the first visible row that has one', () {
      final items = [
        _row(0, bg: 'scene_a'),
        _row(1, bg: 'scene_b'),
      ];
      expect(sceneForVisible(items, [1]), (id: 'scene_b', img: false));
    });

    test('scrolling past a scene change swaps the backdrop', () {
      final items = [
        _row(0, bg: 'scene_a'),
        _row(1, bg: 'scene_a'),
        _row(2, bg: 'scene_b'),
      ];
      // Rows 0-1 on screen -> first scene.
      expect(sceneForVisible(items, [0, 1])?.id, 'scene_a');
      // Scrolled down so row 2 leads -> the new scene. This is the bug that had
      // the backdrop stuck on the chapter's opening image.
      expect(sceneForVisible(items, [2])?.id, 'scene_b');
    });

    test('skips leading rows that carry no scene instead of blanking', () {
      final items = [
        _row(0), // e.g. a gap or a sound chip
        _row(1, bg: 'scene_a'),
      ];
      expect(sceneForVisible(items, [0, 1])?.id, 'scene_a');
    });

    test('a CG overlay is flagged as an image', () {
      final items = [_row(0, bg: 'cg_1', img: true)];
      expect(sceneForVisible(items, [0]), (id: 'cg_1', img: true));
    });

    test('null when nothing visible carries a scene', () {
      expect(sceneForVisible([_row(0)], [0]), isNull);
      expect(sceneForVisible([_row(0, bg: 'a')], const []), isNull);
    });

    test('out-of-range indices are ignored, not fatal', () {
      final items = [_row(0, bg: 'scene_a')];
      // The footer row's index is one past the end.
      expect(sceneForVisible(items, [1, 0])?.id, 'scene_a');
      expect(sceneForVisible(items, [99]), isNull);
    });
  });
}
