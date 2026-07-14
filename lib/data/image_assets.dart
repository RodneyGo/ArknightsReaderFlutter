// Loads the bundled image asset paths from the Flutter AssetManifest and feeds
// them into the chapter-image + background lookups (the Dart stand-in for Vite's
// `import.meta.glob`). Call [loadImageAssets] once at startup.

import 'package:flutter/services.dart' show rootBundle, AssetManifest;

import 'backgrounds.dart' as bg;
import 'chapter_images.dart';

List<String> _allBackgrounds = const [];

/// Every episode + story background asset path (for a random menu backdrop).
List<String> get backgroundPaths => _allBackgrounds;

Future<void> loadImageAssets() async {
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  final all = manifest.listAssets();
  List<String> under(String dir) =>
      all.where((p) => p.startsWith(dir)).toList();

  initChapterImages(under('assets/ChapterImages/'));
  final episodes = under('assets/EpisodeBackgrounds/');
  final stories = under('assets/StoryBackgrounds/');
  bg.initBackgrounds(episodePaths: episodes, storyPaths: stories);
  _allBackgrounds = [...episodes, ...stories];
}
