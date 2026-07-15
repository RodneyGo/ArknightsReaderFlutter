import 'package:flutter_test/flutter_test.dart';

import 'package:ak_reader/data/models.dart';
import 'package:ak_reader/ui/reader_controller.dart';

/// A chapter with one decision and two mutually exclusive branches.
List<StoryItem> _branchingChapter() => [
      NarrationItem(id: 0, runs: const [TextRun('Before the choice.')]),
      DecisionItem(
        id: 1,
        group: 1,
        options: const ['Agree', 'Refuse'],
        values: const ['1', '2'],
      ),
      NarrationItem(
        id: 2,
        runs: const [TextRun('You agreed.')],
        branch: const Branch(1, ['1']),
      ),
      NarrationItem(
        id: 3,
        runs: const [TextRun('You refused.')],
        branch: const Branch(1, ['2']),
      ),
      NarrationItem(id: 4, runs: const [TextRun('After the choice.')]),
    ];

String _textOf(StoryItem it) => switch (it) {
      NarrationItem() => it.runs.map((r) => r.text).join(),
      _ => '',
    };

void main() {
  group('ReaderController', () {
    test('setItems defaults each decision to its first option', () {
      final c = ReaderController()..setItems(_branchingChapter());
      expect(c.selections, {1: '1'});
      expect(c.loading, isFalse);
    });

    test('displayItems hides the branches whose option is not selected', () {
      final c = ReaderController()..setItems(_branchingChapter());

      expect(c.displayItems.map(_textOf), [
        'Before the choice.',
        '', // the decision row itself
        'You agreed.',
        'After the choice.',
      ]);

      c.selectOption(1, '2');
      expect(c.displayItems.map(_textOf), [
        'Before the choice.',
        '',
        'You refused.',
        'After the choice.',
      ]);
    });

    test('unbranched items always show', () {
      final c = ReaderController()
        ..setItems([
          NarrationItem(id: 0, runs: const [TextRun('Always here.')]),
        ]);
      expect(c.displayItems, hasLength(1));
    });

    test('selectOption notifies only on a real change', () {
      final c = ReaderController()..setItems(_branchingChapter());
      var notes = 0;
      c.addListener(() => notes++);

      c.selectOption(1, '1'); // already selected
      expect(notes, 0);

      c.selectOption(1, '2');
      expect(notes, 1);
    });

    test('title comes from the chapter', () {
      final c = ReaderController()..setItems([], title: 'Chapter 1');
      expect(c.title, 'Chapter 1');
    });
  });
}
