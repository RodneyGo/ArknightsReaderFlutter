// Resolves + pre-decodes VN character sprites.
//
// A portrait id maps to several candidate urls. Novel mode's Avatar walks that
// chain lazily via errorBuilder, but the VN crossfade has no error recovery — a
// bad url would just leave the character invisible mid-line. So, like the web
// version, we resolve each portrait by *actually loading* candidates in order and
// keeping the first that succeeds. Loading (rather than probing with a HEAD
// request) is what makes this work offline and self-heal a stale memo entry.
//
// Everything resolved is left in Flutter's image cache, so the swap on a line
// change is instant.

import 'package:flutter/widgets.dart';

import '../data/offline.dart';
import '../data/resolved.dart';
import '../data/source.dart';
import 'local_image.dart';

class SpriteResolver extends ChangeNotifier {
  final ResolvedUrls _memo;
  final Offline? _offline;
  final _resolved = <String, String>{};
  final _inFlight = <String>{};
  bool _disposed = false;

  SpriteResolver(this._memo, this._offline);

  /// The working url for a portrait, or null while unresolved / if all
  /// candidates failed.
  String? urlFor(String portrait) => _resolved[portrait];

  String _memoKey(String portrait) => 'sp:$portrait';

  /// Resolve every distinct portrait in the chapter up front, so no line has to
  /// wait on a network round-trip.
  Future<void> warmAll(Iterable<String> portraits, BuildContext context) async {
    for (final p in portraits.toSet()) {
      if (!context.mounted) return;
      await resolve(p, context);
    }
  }

  Future<void> resolve(String portrait, BuildContext context) async {
    if (portrait.isEmpty ||
        _resolved.containsKey(portrait) ||
        _inFlight.contains(portrait)) {
      return;
    }
    _inFlight.add(portrait);
    try {
      // Try the previously-working candidate first.
      final candidates = spriteCandidates(portrait);
      final known = _memo.get(_memoKey(portrait));
      final ordered = <String>[
        if (known != null && candidates.contains(known)) known,
        ...candidates.where((c) => c != known),
      ];
      for (final url in ordered) {
        if (!context.mounted || _disposed) return;
        try {
          // Prefer a downloaded copy so a sprite resolves offline.
          await precacheImage(readerImage(url, _offline), context);
          if (_disposed) return;
          _resolved[portrait] = url;
          _memo.set(_memoKey(portrait), url);
          notifyListeners();
          return;
        } catch (_) {
          // 404 / undecodable — try the next candidate
        }
      }
      // Nothing loaded: the sprite stays hidden rather than showing a broken box.
    } finally {
      _inFlight.remove(portrait);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
