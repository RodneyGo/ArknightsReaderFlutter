import 'package:flutter_test/flutter_test.dart';

import 'package:ak_reader/data/i18n.dart';

void main() {
  group('trFor', () {
    test('ru server returns Russian, others English', () {
      expect(trFor('ru', 'settings'), 'Настройки');
      expect(trFor('en_US', 'settings'), 'Settings');
      expect(trFor('ja_JP', 'settings'), 'Settings'); // only en + ru; else en
    });

    test('substitutes named params', () {
      expect(trFor('en_US', 'loadingPct', {'pct': '42'}), 'Loading 42%');
      expect(trFor('ru', 'allFilesPresent', {'n': '7'}), 'Все файлы на месте (7).');
      expect(
        trFor('en_US', 'filesMissing', {'missing': '2 / 5'}),
        '2 / 5 files missing.',
      );
    });

    test('unknown key falls back to the key itself', () {
      expect(trFor('ru', 'does_not_exist'), 'does_not_exist');
    });

    test('every English key has a Russian translation', () {
      // Guards against half-translated menus: a missing ru key would silently
      // fall back to English mid-screen.
      for (final key in enKeys) {
        expect(trFor('ru', key), isNot(equals(trFor('en_US', key))),
            reason: 'ru["$key"] missing or identical to English');
      }
    });
  });
}
