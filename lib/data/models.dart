// Story-line data models.
//
// Ported from BetterPhoneReader/src/data/parse.ts. The TypeScript source uses a
// discriminated union (`StoryItem = ... | ...`); the Dart equivalent is a
// `sealed` base class + one subclass per `kind`, which gives exhaustive
// `switch` handling at the render sites for free.

/// One raw line as it arrives in a story JSON's `storyList`. `id` is the index
/// of the line within the list (assigned on load).
class RawLine {
  final int id;
  final String prop;
  final Map<String, dynamic> attributes;

  /// Marks a line injected from the comparison ("alt") language overlay.
  final bool alt;

  RawLine({
    required this.id,
    required this.prop,
    Map<String, dynamic>? attributes,
    this.alt = false,
  }) : attributes = attributes ?? const {};

  RawLine copyWithAlt(bool value) =>
      RawLine(id: id, prop: prop, attributes: attributes, alt: value);

  /// Build from a decoded JSON map, stamping in the list index as `id`.
  factory RawLine.fromJson(Map<String, dynamic> json, int id) => RawLine(
        id: id,
        prop: (json['prop'] ?? '').toString(),
        attributes: (json['attributes'] as Map?)?.cast<String, dynamic>(),
      );
}

/// A decoded story payload: its display name and the raw command list.
class StoryData {
  final String? eventName;
  final String? eventid;
  final List<RawLine> storyList;

  const StoryData({this.eventName, this.eventid, required this.storyList});

  factory StoryData.fromJson(Map<String, dynamic> json) {
    final raw = (json['storyList'] as List?) ?? const [];
    final list = <RawLine>[];
    for (var i = 0; i < raw.length; i++) {
      final line = raw[i];
      if (line is Map) {
        list.add(RawLine.fromJson(line.cast<String, dynamic>(), i));
      }
    }
    return StoryData(
      eventName: json['eventName'] as String?,
      eventid: json['eventid'] as String?,
      storyList: list,
    );
  }
}

/// Branch membership: an item only shows when the choice for [group] selects one
/// of [refs]. Post-convergence (common) content is tagged with all option values.
class Branch {
  final int group;
  final List<String> refs;

  const Branch(this.group, this.refs);

  @override
  bool operator ==(Object other) =>
      other is Branch &&
      other.group == group &&
      _listEq(other.refs, refs);

  @override
  int get hashCode => Object.hash(group, Object.hashAll(refs));

  @override
  String toString() => 'Branch(group: $group, refs: $refs)';
}

bool _listEq(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// A normalized, render-ready story item.
///
/// [bg]/[bgImage] are mutable because [normalizeStory] backfills the opening
/// title cards with the first real scene background after the fact.
sealed class StoryItem {
  final int id;
  String? bg;
  bool bgImage;
  final bool alt;
  final Branch? branch;

  StoryItem({
    required this.id,
    this.bg,
    this.bgImage = false,
    this.alt = false,
    this.branch,
  });

  /// Discriminator matching the TS `kind` field (handy for debugging/tests).
  String get kind;
}

class DialogItem extends StoryItem {
  final String name;
  final String html;
  final String? portrait;

  DialogItem({
    required super.id,
    required this.name,
    required this.html,
    this.portrait,
    super.bg,
    super.bgImage,
    super.alt,
    super.branch,
  });

  @override
  String get kind => 'dialog';
}

class NarrationItem extends StoryItem {
  final String html;

  NarrationItem({
    required super.id,
    required this.html,
    super.bg,
    super.bgImage,
    super.alt,
    super.branch,
  });

  @override
  String get kind => 'narration';
}

class SubtitleItem extends StoryItem {
  final String text;

  SubtitleItem({
    required super.id,
    required this.text,
    super.bg,
    super.bgImage,
    super.alt,
    super.branch,
  });

  @override
  String get kind => 'subtitle';
}

class DecisionItem extends StoryItem {
  final List<String> options;
  final List<String> values;
  final int group;

  DecisionItem({
    required super.id,
    required this.options,
    required this.values,
    required this.group,
    super.bg,
    super.bgImage,
  });

  @override
  String get kind => 'decision';
}

class SoundItem extends StoryItem {
  final String key;
  final bool music;

  SoundItem({
    required super.id,
    required this.key,
    required this.music,
    super.bg,
    super.bgImage,
    super.branch,
  });

  @override
  String get kind => 'sound';
}

class SceneBreakItem extends StoryItem {
  SceneBreakItem({
    required super.id,
    super.bg,
    super.bgImage,
    super.branch,
  });

  @override
  String get kind => 'scenebreak';
}

/// An avatar candidate URL plus whether it needs head-cropping (full character
/// art) or fills the box as-is (a square operator/mystery icon).
class AvatarCandidate {
  final String url;
  final bool crop;

  const AvatarCandidate(this.url, this.crop);

  @override
  bool operator ==(Object other) =>
      other is AvatarCandidate && other.url == url && other.crop == crop;

  @override
  int get hashCode => Object.hash(url, crop);

  @override
  String toString() => 'AvatarCandidate($url, crop: $crop)';
}
