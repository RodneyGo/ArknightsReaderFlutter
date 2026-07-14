// Shared name normalization for matching event/story names to image assets.
// Ported from the identical `norm()` in chapterImages.ts and backgrounds.ts
// (NOT the same as guide.ts's norm, which also strips an "Episode N:" prefix).

import 'package:diacritic/diacritic.dart';

final _nonAlnum = RegExp(r'[^a-z0-9]+');
final _stop = RegExp(r'\b(the|a|of|is|are|be|will|that|our|im|in|to|for)\b');
final _spaces = RegExp(r'\s+');

String normName(String s) {
  var out = removeDiacritics(s.toLowerCase());
  out = out.replaceAll('&', 'and');
  out = out.replaceAll(_nonAlnum, ' ');
  out = out.replaceAll(_stop, ' ');
  out = out.replaceAll(_spaces, ' ');
  return out.trim();
}

/// Filename (without directory or extension) for an asset path.
String assetBaseName(String path) {
  final name = path.split('/').last;
  final dot = name.lastIndexOf('.');
  return dot == -1 ? name : name.substring(0, dot);
}
