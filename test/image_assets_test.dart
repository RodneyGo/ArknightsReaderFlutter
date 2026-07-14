import 'package:flutter_test/flutter_test.dart';
import 'package:ak_reader/data/backgrounds.dart';
import 'package:ak_reader/data/chapter_images.dart';
import 'package:ak_reader/data/guide.dart';
import 'package:ak_reader/data/image_assets.dart';
import 'package:ak_reader/data/menu.dart';

EpisodeNode node({String? title, EventGroup? event, int? episodeIndex}) =>
    EpisodeNode(
      title: title ?? event?.name ?? '',
      event: event,
      isEpisode: episodeIndex != null,
      episodeIndex: episodeIndex,
      forceOptional: false,
    );

EventGroup event(String name) =>
    EventGroup(id: name, name: name, startTime: 0, stories: const []);

void main() {
  group('chapterImage', () {
    setUp(() {
      initChapterImages([
        'assets/ChapterImages/Roaring_Flare_archive.webp',
        'assets/ChapterImages/A_Kazdelian_Rescue_archive.webp',
        'assets/ChapterImages/Evil_Time_Prologue.webp', // odd name -> alias
      ]);
    });

    test('matches by normalized event name', () {
      expect(chapterImage('Roaring Flare'),
          'assets/ChapterImages/Roaring_Flare_archive.webp');
      expect(chapterImage('A Kazdelian Rescue'),
          'assets/ChapterImages/A_Kazdelian_Rescue_archive.webp');
    });

    test('resolves aliased filenames to their event name', () {
      // "Evil_Time_Prologue" file is aliased to event "Evil Time Part 1"
      expect(chapterImage('Evil Time Part 1'),
          'assets/ChapterImages/Evil_Time_Prologue.webp');
    });

    test('falls back to a substring match', () {
      // "Roaring Flare Rerun" contains the normalized "roaring flare"
      expect(chapterImage('Roaring Flare Rerun'),
          'assets/ChapterImages/Roaring_Flare_archive.webp');
    });

    test('returns null when nothing matches', () {
      expect(chapterImage('Completely Unrelated Title 123'), isNull);
    });
  });

  group('episodeBackground', () {
    setUp(() {
      initChapterImages(['assets/ChapterImages/Near_Light_archive.webp']);
      initBackgrounds(
        episodePaths: [
          'assets/EpisodeBackgrounds/episode0_eviltime1.webp',
          'assets/EpisodeBackgrounds/episode5.webp',
        ],
        storyPaths: ['assets/StoryBackgrounds/Under_Tides.webp'],
      );
    });

    test('main-story episode uses its curated episode art by index', () {
      expect(episodeBackground(node(event: event('Whatever'), episodeIndex: 5)),
          'assets/EpisodeBackgrounds/episode5.webp');
      expect(
          episodeBackground(node(event: event('Prologue'), episodeIndex: 0)),
          'assets/EpisodeBackgrounds/episode0_eviltime1.webp');
    });

    test('side story uses dedicated StoryBackgrounds art', () {
      expect(episodeBackground(node(event: event('Under Tides'))),
          'assets/StoryBackgrounds/Under_Tides.webp');
    });

    test('falls back to the chapter banner when no dedicated art exists', () {
      expect(episodeBackground(node(event: event('Near Light'))),
          'assets/ChapterImages/Near_Light_archive.webp');
    });

    test('null when there is no episode art, story art, or banner', () {
      expect(episodeBackground(node(title: 'Nothing Matches Here')), isNull);
    });
  });

  // End-to-end: the assets are actually declared/bundled and the AssetManifest
  // wiring works (no device needed — the test asset bundle serves them).
  testWidgets('loadImageAssets populates from the real bundle', (tester) async {
    await loadImageAssets();
    expect(backgroundPaths, isNotEmpty);
    final banner = chapterImage('Roaring Flare');
    expect(banner, isNotNull);
    expect(banner, startsWith('assets/ChapterImages/'));
    expect(banner, endsWith('.webp'));
  });
}
