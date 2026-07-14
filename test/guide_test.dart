// Guide parity tests: the ARCS/NOTE_RU data comes from the same generated asset
// the app uses, so the only thing to verify is the ported LOGIC (norm-matching,
// resolveGuide, buildGuide annotation, describeGuideLocation). Goldens are the
// real TS output for the same categories input (tool/gen_guide_golden.ts).

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ak_reader/data/guide.dart';
import 'package:ak_reader/data/menu.dart';

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
List<dynamic> _jsonList(String path) =>
    jsonDecode(File(path).readAsStringSync()) as List<dynamic>;

Map<String, dynamic> canonNode(GuideNode n) => {
      'title': n.title,
      'optional': n.optional,
      'is': n.isIS,
      'lead': n.lead,
      'note': n.note,
      'event': n.event == null ? null : {'id': n.event!.id, 'name': n.event!.name},
      'subStories':
          n.subStories?.map((s) => {'name': s.name, 'txt': s.txt}).toList(),
      'isEpisode': n is EpisodeNode ? n.isEpisode : null,
      'episodeIndex': n is EpisodeNode ? n.episodeIndex : null,
      'forceOptional': n is EpisodeNode ? n.forceOptional : null,
    };

Map<String, dynamic> canonStoryline(Storyline s) => {
      'name': s.name,
      'main': s.main,
      'status': s.status,
      'nodes': s.nodes.map(canonNode).toList(),
    };

Map<String, dynamic>? canonLoc(ChapterLocation? l) => l == null
    ? null
    : {
        'storyline': l.storyline,
        'episodeNum': l.episodeNum,
        'episodeName': l.episodeName,
        'chapterNum': l.chapterNum,
        'chapterName': l.chapterName,
      };

void main() {
  // Load the same generated data the app ships, and the real-table categories.
  setUpAll(() {
    setGuideData(parseGuideData(_json('assets/guide_data.json')));
  });

  List<Category> loadCategories() => [
        for (final c in _jsonList('test/fixtures/guide_categories.json'))
          Category.fromJson((c as Map).cast<String, dynamic>()),
      ];

  test('buildGuide matches the TypeScript output on real categories', () {
    final golden = _json('test/fixtures/guide_build.golden.json');
    final built = buildGuide(loadCategories());

    final actualMain = built.mainArcs.map(canonStoryline).toList();
    final actualSide = built.sideStorylines.map(canonStoryline).toList();
    final goldenMain = golden['mainArcs'] as List;
    final goldenSide = golden['sideStorylines'] as List;

    expect(actualMain.length, goldenMain.length, reason: 'mainArcs count');
    for (var i = 0; i < actualMain.length; i++) {
      expect(actualMain[i], equals(goldenMain[i]),
          reason: 'mainArc ${actualMain[i]['name']}');
    }
    expect(actualSide.length, goldenSide.length, reason: 'sideStorylines count');
    for (var i = 0; i < actualSide.length; i++) {
      expect(actualSide[i], equals(goldenSide[i]),
          reason: 'sideStoryline ${actualSide[i]['name']}');
    }
  });

  test('describeGuideLocation matches the TypeScript output', () {
    final guide = buildGuide(loadCategories());
    final golden = _jsonList('test/fixtures/guide_locations.golden.json');
    for (final entry in golden) {
      final txt = entry['txt'] as String;
      final loc = describeGuideLocation(guide, txt, 'Main Story');
      expect(canonLoc(loc), equals(entry['location']),
          reason: 'location for $txt');
    }
    expect(golden, isNotEmpty);
  });

  group('localizeNote', () {
    test('returns the RU translation for ru, English otherwise', () {
      // A known note present in NOTE_RU.
      const en = 'Official end to the Reunion Arc.';
      expect(localizeNote(en, 'ru'), isNot(en)); // translated
      expect(localizeNote(en, 'en'), en);
    });

    test('falls back to English when no translation exists', () {
      const en = 'a note that is definitely not translated 123';
      expect(localizeNote(en, 'ru'), en);
    });

    test('passes null through', () {
      expect(localizeNote(null, 'ru'), isNull);
    });
  });
}
