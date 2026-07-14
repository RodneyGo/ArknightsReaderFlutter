// Backdrop images for the guide screen. Ported from
// BetterPhoneReader/src/data/backgrounds.ts.
//
// Main Story episodes use the curated EpisodeBackgrounds/episode{N} art
// (episode 0 = prologue); side-story events use StoryBackgrounds/<name> art when
// provided. Either falls back to the event's chapter banner (shown blurred) when
// no dedicated art exists. Asset paths come from the AssetManifest (see
// image_assets.dart).

import 'chapter_images.dart';
import 'guide.dart' show EpisodeNode;
import 'name_norm.dart';

final Map<int, String> _byEpisode = {}; // episode index -> asset path
final Map<String, String> _byStoryName = {}; // normalized name -> asset path

void initBackgrounds({
  required Iterable<String> episodePaths,
  required Iterable<String> storyPaths,
}) {
  _byEpisode.clear();
  _byStoryName.clear();
  final epNum = RegExp(r'episode(\d+)', caseSensitive: false);
  for (final path in episodePaths) {
    final m = epNum.firstMatch(assetBaseName(path));
    if (m != null) _byEpisode[int.parse(m.group(1)!)] = path;
  }
  for (final path in storyPaths) {
    _byStoryName[normName(assetBaseName(path).replaceAll('_', ' '))] = path;
  }
}

String? _storyBackground(String name) {
  final key = normName(name);
  final hit = _byStoryName[key];
  if (hit != null) return hit;
  for (final e in _byStoryName.entries) {
    if (e.key.isNotEmpty && (e.key.contains(key) || key.contains(e.key))) {
      return e.value;
    }
  }
  return null;
}

/// Resolve the full backdrop asset path for a guide node, or null if nothing
/// matches. The "Open background" lightbox shows this same image uncropped.
String? episodeBackground(EpisodeNode node) {
  final idx = node.episodeIndex;
  if (idx != null && _byEpisode.containsKey(idx)) return _byEpisode[idx];
  final name = node.event?.name ?? node.title;
  return _storyBackground(name) ?? chapterImage(name);
}
