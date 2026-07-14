// Chapter menu: fetch + shape the story_review_table into categorized events.
// Ported from BetterPhoneReader/src/data/menu.ts.
//
// The pure transform (classify / mainOrder / buildMenu / neighbor lookup) is
// ported faithfully. The TS persistence layer (localStorage cache-first +
// offline readMeta fallback + background revalidate) is deferred until the
// state/offline layers are ported — for now `fetchMenu` just fetches and builds.

import 'servers.dart';
import 'source.dart';

// Story entries that are "intermezzi" rather than ordinary side stories
// (ported from the original reader's func.intermezzi list).
const _intermezzi = <String>{
  'act9d0',
  'act18d0',
  'act18d3',
  'act17side',
  'act25side',
  'act33side',
  'act37side',
};

const _categoryLabels = <String, String>{
  'maintheme': 'Main Story',
  'sidestory': 'Side Story',
  'intermezzi': 'Intermezzi',
  'storyset': 'Story Set',
  'records': 'Operator Records',
};

class Story {
  final String txt;
  final String code;
  final String name;
  final String tag;

  const Story({
    required this.txt,
    required this.code,
    required this.name,
    required this.tag,
  });

  factory Story.fromReview(Map<String, dynamic> s) => Story(
        txt: (s['storyTxt'] ?? '').toString(),
        code: (s['storyCode'] ?? '').toString(),
        name: (s['storyName'] ?? '').toString(),
        tag: (s['avgTag'] ?? '').toString(),
      );

  factory Story.fromJson(Map<String, dynamic> j) => Story(
        txt: (j['txt'] ?? '').toString(),
        code: (j['code'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        tag: (j['tag'] ?? '').toString(),
      );
}

class EventGroup {
  final String id;
  final String name;
  final num startTime;
  final List<Story> stories;

  const EventGroup({
    required this.id,
    required this.name,
    required this.startTime,
    required this.stories,
  });

  factory EventGroup.fromJson(Map<String, dynamic> j) => EventGroup(
        id: j['id'] as String,
        name: j['name'] as String,
        startTime: (j['startTime'] as num?) ?? 0,
        stories: [
          for (final s in (j['stories'] as List? ?? const []))
            Story.fromJson((s as Map).cast<String, dynamic>()),
        ],
      );
}

class Category {
  final String key;
  final String label;
  final List<EventGroup> events;

  const Category({required this.key, required this.label, required this.events});

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        key: j['key'] as String,
        label: j['label'] as String,
        events: [
          for (final e in (j['events'] as List? ?? const []))
            EventGroup.fromJson((e as Map).cast<String, dynamic>()),
        ],
      );
}

/// A flattened story carrying its owning event's display name (TS `Story & {event}`).
class FlatStory {
  final String txt;
  final String code;
  final String name;
  final String tag;
  final String event;

  const FlatStory({
    required this.txt,
    required this.code,
    required this.name,
    required this.tag,
    required this.event,
  });
}

class Menu {
  final List<Category> categories;
  final List<FlatStory> flat;

  const Menu({required this.categories, required this.flat});
}

String classify(String eventid, String? entryType) {
  switch (entryType) {
    case 'MAINLINE':
      return 'maintheme';
    case 'ACTIVITY':
      return _intermezzi.contains(eventid) ? 'intermezzi' : 'sidestory';
    case 'MINI_ACTIVITY':
      return 'storyset';
    default:
      return 'records'; // NONE
  }
}

int mainOrder(String id) {
  final m = RegExp(r'(\d+)').firstMatch(id);
  return m != null ? int.parse(m.group(1)!) : 0;
}

/// Transform a decoded story_review_table into the categorized menu.
Menu buildMenu(Map<String, dynamic> table) {
  final buckets = <String, List<EventGroup>>{};
  final flat = <FlatStory>[];

  for (final eventid in table.keys) {
    final ev = table[eventid] as Map<String, dynamic>?;
    final cat = classify(eventid, ev?['entryType'] as String?);
    final rawStories = (ev?['infoUnlockDatas'] as List?) ?? const [];
    final stories = <Story>[];
    for (final s in rawStories) {
      if (s is Map && (s['storyTxt'] ?? '') != '') {
        stories.add(Story.fromReview(s.cast<String, dynamic>()));
      }
    }
    if (stories.isEmpty) continue;

    final name = (ev?['name'] ?? eventid).toString();
    (buckets[cat] ??= []).add(EventGroup(
      id: eventid,
      name: name,
      startTime: (ev?['startTime'] as num?) ?? 0,
      stories: stories,
    ));
    for (final st in stories) {
      flat.add(FlatStory(
          txt: st.txt, code: st.code, name: st.name, tag: st.tag, event: name));
    }
  }

  const order = ['maintheme', 'intermezzi', 'sidestory', 'storyset', 'records'];
  final categories = <Category>[];
  for (final k in order) {
    final events = buckets[k];
    if (events == null || events.isEmpty) continue;
    // Stable sort (JS Array.sort is stable; Dart's List.sort is not) via an
    // original-index tiebreaker, so equal keys keep table order.
    final indexed = [
      for (var i = 0; i < events.length; i++) (i, events[i]),
    ];
    indexed.sort((a, b) {
      final c = k == 'maintheme'
          ? mainOrder(a.$2.id).compareTo(mainOrder(b.$2.id))
          : a.$2.startTime.compareTo(b.$2.startTime);
      return c != 0 ? c : a.$1.compareTo(b.$1);
    });
    categories.add(Category(
      key: k,
      label: _categoryLabels[k] ?? k,
      events: [for (final e in indexed) e.$2],
    ));
  }

  return Menu(categories: categories, flat: flat);
}

/// Previous/next story within the same event for a given storyTxt (pure).
({Story? prev, Story? next}) neighborsIn(Menu menu, String txt) {
  for (final cat in menu.categories) {
    for (final ev in cat.events) {
      final i = ev.stories.indexWhere((s) => s.txt == txt);
      if (i != -1) {
        return (
          prev: i > 0 ? ev.stories[i - 1] : null,
          next: i < ev.stories.length - 1 ? ev.stories[i + 1] : null,
        );
      }
    }
  }
  return (prev: null, next: null);
}

// --- fetch (in-memory cached; persistent cache TODO) ---

final _menuCache = <String, Future<Menu>>{};

/// Cached menu fetch so the reader can resolve chapter neighbours cheaply.
Future<Menu> getMenu(String server) =>
    _menuCache.putIfAbsent(server, () => fetchMenu(server));

Future<Menu> fetchMenu(String server) async {
  final base = baseServer(server);
  // TODO(cache): localStorage cache-first + background revalidate + offline
  // readMeta fallback, once the state/offline layers are ported.
  final table = await getJson<Map<String, dynamic>>(
      base, '/gamedata/excel/story_review_table.json');
  return buildMenu(table);
}

/// Find the previous/next story within the same event for a given storyTxt.
Future<({Story? prev, Story? next})> getNeighbors(
    String server, String txt) async {
  return neighborsIn(await getMenu(server), txt);
}
