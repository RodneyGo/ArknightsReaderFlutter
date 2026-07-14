// Maps in-game event names to the bundled chapter banner images. Ported from
// BetterPhoneReader/src/data/chapterImages.ts.
//
// The web version used Vite's `import.meta.glob`; here the asset paths come from
// the Flutter AssetManifest (see image_assets.dart) and are passed to
// [initChapterImages]. Matching is by normalized event name, with a few aliases
// for files whose name doesn't follow "<Event>_archive".

import 'name_norm.dart';

// filename (without extension) -> exact event name, for odd filenames.
const _aliases = <String, String>{
  'Evil_Time_Prologue': 'Evil Time Part 1',
  'Evil_Time_Part2_Episode_01': 'Evil Time Part 2',
};

final Map<String, String> _byName = {}; // normalized event name -> asset path
final Map<String, String> _byFile = {}; // basename (no ext) -> asset path

/// Build the lookup from the bundled ChapterImages asset paths.
void initChapterImages(Iterable<String> assetPaths) {
  _byName.clear();
  _byFile.clear();
  for (final path in assetPaths) {
    final base = assetBaseName(path);
    _byFile[base] = path;
    final file = base.replaceFirst(RegExp(r'_archive$'), '');
    _byName[normName(file.replaceAll('_', ' '))] = path;
  }
  _aliases.forEach((file, eventName) {
    final path = _byFile[file];
    if (path != null) _byName[normName(eventName)] = path;
  });
}

/// Resolve the banner asset path for an event name, or null if none provided.
String? chapterImage(String eventName) {
  final key = normName(eventName);
  final hit = _byName[key];
  if (hit != null) return hit;
  for (final e in _byName.entries) {
    if (e.key.contains(key) || key.contains(e.key)) return e.value;
  }
  return null;
}
