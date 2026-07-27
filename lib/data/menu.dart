// Chapter menu: fetch + shape the story_review_table into categorized events.
// Ported from BetterPhoneReader/src/data/menu.ts.
//
// The pure transform (classify / mainOrder / buildMenu / neighbor lookup) is
// ported faithfully. Persistence is cache-first: the table is read from the
// on-disk meta copy (written by Offline._ensureMeta), so the main menu opens with no
// network; refreshMenu revalidates in the background and merges any new events.

import 'localstore.dart';
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

// --- fetch (cache-first, in-memory memoised) ---

const _tableEndpoint = '/gamedata/excel/story_review_table.json';
String _metaName(String base) => '${base}__story_review_table';

/// Network fetch of the review table, injectable so tests don't hit the network.
typedef TableFetch = Future<Map<String, dynamic>> Function(String base);

Future<Map<String, dynamic>> _networkTable(String base) =>
    getJson<Map<String, dynamic>>(base, _tableEndpoint);

final _menuCache = <String, Future<Menu>>{};

/// Cached menu fetch so the reader can resolve chapter neighbours cheaply.
Future<Menu> getMenu(String server) =>
    _menuCache.putIfAbsent(server, () => fetchMenu(server));

/// Prefer the on-disk table (works offline, no network wait); fall back to the
/// network and save a copy so the next launch is instant.
Future<Menu> fetchMenu(String server, {LocalStore? store, TableFetch? fetch}) async {
  final base = baseServer(server);
  final cached = await _readCachedTable(base, store);
  if (cached != null) return buildMenu(cached);

  final table = await (fetch ?? _networkTable)(base);
  await _saveTable(base, table, store);
  return buildMenu(table);
}

/// Revalidate against the network and merge any newly-added events into the
/// cache. An existing event never gains chapters, so this is a union on event
/// ids: new keys are added, and events that vanish upstream stay readable.
///
/// Returns the rebuilt [Menu] when new events appeared, else null (nothing to
/// redraw). The in-memory [getMenu] cache is refreshed as a side effect.
Future<Menu?> refreshMenu(String server, {LocalStore? store, TableFetch? fetch}) async {
  final base = baseServer(server);
  final fresh = await (fetch ?? _networkTable)(base);
  final cached = await _readCachedTable(base, store) ?? const {};

  final merged = <String, dynamic>{...cached};
  var added = false;
  for (final id in fresh.keys) {
    if (!merged.containsKey(id)) {
      merged[id] = fresh[id];
      added = true;
    }
  }
  if (!added) return null;

  await _saveTable(base, merged, store);
  final menu = buildMenu(merged);
  _menuCache[server] = Future.value(menu);
  return menu;
}

Future<Map<String, dynamic>?> _readCachedTable(
    String base, LocalStore? store) async {
  try {
    final s = store ?? await LocalStore.instance();
    return await s.readMeta(_metaName(base));
  } catch (_) {
    return null; // no filesystem (web) or nothing saved yet
  }
}

Future<void> _saveTable(
    String base, Map<String, dynamic> table, LocalStore? store) async {
  try {
    final s = store ?? await LocalStore.instance();
    await s.saveMeta(_metaName(base), table);
  } catch (_) {
    // no filesystem — the in-memory cache still serves this session
  }
}

/// Find the previous/next story within the same event for a given storyTxt.
Future<({Story? prev, Story? next})> getNeighbors(
    String server, String txt) async {
  return neighborsIn(await getMenu(server), txt);
}
