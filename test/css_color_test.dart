import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';

import 'package:ak_reader/ui/css_color.dart';

void main() {
  group('cssColor', () {
    test('6-digit hex is opaque', () {
      expect(cssColor('#ff0000'), const Color(0xFFFF0000));
      expect(cssColor('#00FF7F'), const Color(0xFF00FF7F));
    });

    test('3-digit hex expands each nibble', () {
      expect(cssColor('#f00'), const Color(0xFFFF0000));
      expect(cssColor('#abc'), const Color(0xFFAABBCC));
    });

    test('8-digit hex moves CSS trailing alpha to the front', () {
      // #rrggbbaa -> 0xAARRGGBB
      expect(cssColor('#11223344'), const Color(0x44112233));
    });

    test('4-digit hex expands then reorders alpha', () {
      expect(cssColor('#f00a'), const Color(0xAAFF0000));
    });

    test('named colours resolve; unknown names fall through to null', () {
      expect(cssColor('red'), const Color(0xFFFF0000));
      expect(cssColor('GOLD'), const Color(0xFFFFD700));
      expect(cssColor('rebeccapurple'), isNull);
    });

    test('junk and empties are null rather than throwing', () {
      expect(cssColor(null), isNull);
      expect(cssColor(''), isNull);
      expect(cssColor('#'), isNull);
      expect(cssColor('#12345'), isNull);
      expect(cssColor('#gggggg'), isNull);
    });

    test('surrounding whitespace and case are tolerated', () {
      expect(cssColor('  #FF0000 '), const Color(0xFFFF0000));
    });
  });
}
