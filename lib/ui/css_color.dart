// Parses the colour values that survive parse.dart's `<color=X>` sanitizing into
// Flutter Colors. The web build handed these straight to CSS; Dart needs to do it
// itself. The game data uses hex almost exclusively, plus the odd bare keyword.
//
// Returns null for anything unrecognized, which the renderer treats as "inherit"
// — same as a browser ignoring an invalid colour.

import 'dart:ui' show Color;

// Only the keywords the game data actually reaches for. Unknown names fall
// through to the inherited colour rather than guessing.
const _named = <String, int>{
  'red': 0xFFFF0000,
  'green': 0xFF008000,
  'blue': 0xFF0000FF,
  'yellow': 0xFFFFFF00,
  'orange': 0xFFFFA500,
  'purple': 0xFF800080,
  'pink': 0xFFFFC0CB,
  'cyan': 0xFF00FFFF,
  'aqua': 0xFF00FFFF,
  'magenta': 0xFFFF00FF,
  'fuchsia': 0xFFFF00FF,
  'lime': 0xFF00FF00,
  'white': 0xFFFFFFFF,
  'gray': 0xFF808080,
  'grey': 0xFF808080,
  'silver': 0xFFC0C0C0,
  'brown': 0xFFA52A2A,
  'gold': 0xFFFFD700,
};

Color? cssColor(String? raw) {
  if (raw == null) return null;
  final v = raw.trim().toLowerCase();
  if (v.isEmpty) return null;

  if (!v.startsWith('#')) {
    final named = _named[v];
    return named == null ? null : Color(named);
  }

  final hex = v.substring(1);
  // #rgb / #rgba -> expand each nibble to a byte (#f00 == #ff0000).
  if (hex.length == 3 || hex.length == 4) {
    final expanded = hex.split('').map((c) => '$c$c').join();
    return _fromHex(hex.length == 3 ? 'ff$expanded' : _rgbaToArgb(expanded));
  }
  // #rrggbb / #rrggbbaa
  if (hex.length == 6) return _fromHex('ff$hex');
  if (hex.length == 8) return _fromHex(_rgbaToArgb(hex));
  return null;
}

/// CSS puts alpha last (#rrggbbaa); Dart's Color wants it first (0xAARRGGBB).
String _rgbaToArgb(String hex8) => hex8.substring(6) + hex8.substring(0, 6);

Color? _fromHex(String argb) {
  final v = int.tryParse(argb, radix: 16);
  return v == null ? null : Color(v);
}
