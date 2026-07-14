import 'package:flutter_test/flutter_test.dart';
import 'package:ak_reader/data/audio.dart';

void main() {
  group('resolveSound', () {
    test('prepends the mapped path when the key is in the sound map', () {
      final urls = resolveSound('\$m_escape', {'m_escape': 'Sound_Beta_2/Music/x'});
      expect(urls.first, endsWith('/audio/sound_beta_2/music/x.mp3'));
      expect(urls.length, 3); // mapped + 2 fallbacks
      expect(urls.every((u) => u == u.toLowerCase()), isTrue);
    });

    test('strips a leading \$ from the key', () {
      final urls = resolveSound('\$d_gen_test', {});
      expect(urls.every((u) => !u.contains('\$')), isTrue);
      expect(urls.any((u) => u.endsWith('/sound_beta_2/avg/d_gen_test.mp3')), isTrue);
    });

    test('unmapped key yields just the two fallbacks (avg then music)', () {
      final urls = resolveSound('unknown_key', {});
      expect(urls, hasLength(2));
      expect(urls[0], endsWith('/sound_beta_2/avg/unknown_key.mp3'));
      expect(urls[1], endsWith('/sound_beta_2/music/unknown_key.mp3'));
    });

    test('empty mapped value is treated as unmapped', () {
      final urls = resolveSound('k', {'k': ''});
      expect(urls, hasLength(2));
    });
  });
}
