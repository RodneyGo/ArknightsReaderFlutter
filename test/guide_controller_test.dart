import 'package:flutter_test/flutter_test.dart';
import 'package:ak_reader/data/guide.dart';
import 'package:ak_reader/data/menu.dart';
import 'package:ak_reader/ui/guide_controller.dart';

EpisodeNode _node(String t) => EpisodeNode(
    title: t, event: null, isEpisode: false, episodeIndex: null, forceOptional: false);

Storyline _line(String name, List<String> titles, {bool main = false}) =>
    Storyline(
      name: name,
      main: main,
      status: 'complete',
      nodes: [for (final t in titles) _node(t)],
    );

void main() {
  group('selection logic (seeded guide)', () {
    late GuideController gc;
    setUp(() {
      gc = GuideController()
        ..setGuide(Guide(
          mainArcs: [
            _line('Arc 1', ['A1', 'A2'], main: true),
            _line('Arc 2', ['B1'], main: true),
          ],
          sideStorylines: [_line('Side X', ['S1', 'S2', 'S3'])],
        ));
    });

    test('defaults to Main Story / arc 0', () {
      expect(gc.isMainStory, isTrue);
      expect(gc.currentNodes.map((n) => n.title), ['A1', 'A2']);
      expect(gc.selectorLabels, ['Main Story', 'Side X']);
    });

    test('selecting an arc swaps the node list and resets focus', () {
      gc.setFocused(1);
      gc.selectArc(1);
      expect(gc.arcIndex, 1);
      expect(gc.focusedIndex, 0);
      expect(gc.currentNodes.map((n) => n.title), ['B1']);
    });

    test('selecting a side storyline leaves Main Story', () {
      gc.selectStoryline(1);
      expect(gc.isMainStory, isFalse);
      expect(gc.currentNodes.map((n) => n.title), ['S1', 'S2', 'S3']);
    });

    test('focusedNode tracks the focused index', () {
      gc.selectStoryline(1);
      gc.setFocused(2);
      expect(gc.focusedNode?.title, 'S3');
    });
  });

  group('load()', () {
    test('builds the guide from a fetched menu', () async {
      // Minimal guide data so buildGuide can resolve a title to an event.
      setGuideData((
        [
          const GuideArc(
            name: 'Arc 1',
            main: true,
            status: 'complete',
            entries: [GuideEntry(title: 'Reunion')],
          ),
        ],
        <String, String>{},
      ));
      const menu = Menu(
        categories: [
          Category(key: 'maintheme', label: 'Main Story', events: [
            EventGroup(id: 'main_0', name: 'Reunion', startTime: 0, stories: []),
          ]),
        ],
        flat: [],
      );
      final gc = GuideController(fetchMenu: (_) async => menu);
      await gc.load('en_US');
      expect(gc.error, isNull);
      expect(gc.guide, isNotNull);
      expect(gc.guide!.mainArcs.single.nodes.single.title, 'Reunion');
    });

    test('captures errors instead of throwing', () async {
      final gc = GuideController(fetchMenu: (_) async => throw Exception('offline'));
      await gc.load('en_US');
      expect(gc.error, isNotNull);
      expect(gc.guide, isNull);
    });
  });
}
