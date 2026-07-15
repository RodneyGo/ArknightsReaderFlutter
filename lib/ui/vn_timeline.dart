// The pure rules behind VN mode's stepping. Ported from the walking half of
// BetterPhoneReader/src/components/VnReader.vue.
//
// VN mode shows one item at a time, so it has to skip the items that aren't
// displayable (sound commands, scene breaks) while still *firing* the sounds it
// passes. Keeping the walk pure — it reports the sounds rather than playing them
// — keeps it testable and leaves the caller to do the audio.

import '../data/models.dart';

/// Items VN mode actually renders. Everything else is stepped over.
bool isVnVisible(StoryItem it) =>
    it is DialogItem ||
    it is NarrationItem ||
    it is SubtitleItem ||
    it is DecisionItem;

/// Result of walking forward from an index: where to stop, and the sound
/// commands passed on the way.
typedef VnWalk = ({int index, List<SoundItem> sounds});

/// Walk from [from] to the next renderable item, collecting the sounds passed.
///
/// [index] == items.length means the chapter ran out — the caller shows the end
/// card.
VnWalk walkToVisible(List<StoryItem> items, int from) {
  final sounds = <SoundItem>[];
  var k = from < 0 ? 0 : from;
  while (k < items.length && !isVnVisible(items[k])) {
    final it = items[k];
    if (it is SoundItem) sounds.add(it);
    k++;
  }
  return (index: k, sounds: sounds);
}

/// Milliseconds per character for each text-speed setting. `instant` = 0, which
/// the caller treats as "no typewriter".
const vnTypeSpeeds = <String, int>{
  'slow': 52,
  'normal': 28,
  'fast': 11,
  'instant': 0,
};

int vnTypeSpeedMs(String setting) => vnTypeSpeeds[setting] ?? 28;

/// The plain text of a renderable item (empty for decisions).
String vnTextOf(StoryItem? it) => switch (it) {
      DialogItem() => it.runs.map((r) => r.text).join(),
      NarrationItem() => it.runs.map((r) => r.text).join(),
      SubtitleItem() => it.runs.map((r) => r.text).join(),
      _ => '',
    };

/// The item's styled runs, truncated to [n] characters.
///
/// The web VN reader stripped its HTML to plain text for the typewriter, losing
/// the `<color>` spans. Runs let us type *and* keep the colour, so this returns
/// the prefix as runs rather than a string.
List<TextRun> truncateRuns(List<TextRun> runs, int n) {
  if (n <= 0) return const [];
  final out = <TextRun>[];
  var left = n;
  for (final r in runs) {
    if (left <= 0) break;
    if (r.text.length <= left) {
      out.add(r);
      left -= r.text.length;
    } else {
      out.add(TextRun(r.text.substring(0, left), r.color));
      left = 0;
    }
  }
  return out;
}

/// One line of the VN backlog.
typedef VnLogEntry = ({int index, String name, String text});

/// The backlog: every renderable line of the chapter, so you can jump forward as
/// well as back. Decisions are omitted — there's no line to show.
List<VnLogEntry> vnLog(List<StoryItem> items) {
  final out = <VnLogEntry>[];
  for (var i = 0; i < items.length; i++) {
    final it = items[i];
    switch (it) {
      case DialogItem():
        out.add((index: i, name: it.name, text: vnTextOf(it)));
      case NarrationItem() || SubtitleItem():
        out.add((index: i, name: '', text: vnTextOf(it)));
      default:
        break;
    }
  }
  return out;
}
