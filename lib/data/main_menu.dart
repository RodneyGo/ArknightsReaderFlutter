// Main-menu structure (Method 3 — arc/storyline order) from the community
// reading guide. Ported from BetterPhoneReader/src/data/guide.ts.
//
// The large static data (the `ARCS` reading order + the `NOTE_RU` Russian note
// translations) is NOT hand-transcribed — it's generated straight from the TS
// into assets/main_menu_data.json by tool/gen_mainMenu_golden.ts and parsed here, so
// there's zero transcription risk. Only the matching/annotation LOGIC is ported.
//
// Entries are matched to in-game events by normalized name at runtime; unmatched
// non-IS entries are dropped.

import 'dart:convert';

import 'package:diacritic/diacritic.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'menu.dart';

// --- static main menu data (loaded from the generated asset) ---

class MainMenuEntry {
  final String title;
  final bool optional;
  final bool isIS; // Integrated Strategies — informational node only (TS `is`)
  final String? lead; // reading-order recommendation shown above the entry
  final String? note; // main menu note shown under the entry
  final List<String> stories; // named sub-stories worth reading

  const MainMenuEntry({
    required this.title,
    this.optional = false,
    this.isIS = false,
    this.lead,
    this.note,
    this.stories = const [],
  });

  factory MainMenuEntry.fromJson(Map<String, dynamic> j) => MainMenuEntry(
        title: j['title'] as String,
        optional: j['optional'] == true,
        isIS: j['is'] == true,
        lead: j['lead'] as String?,
        note: j['note'] as String?,
        stories: (j['stories'] as List?)?.cast<String>() ?? const [],
      );
}

class MainMenuArc {
  final String name;
  final bool main;
  final String status; // "ongoing" | "complete"
  final List<MainMenuEntry> entries;

  const MainMenuArc({
    required this.name,
    this.main = false,
    required this.status,
    required this.entries,
  });

  factory MainMenuArc.fromJson(Map<String, dynamic> j) => MainMenuArc(
        name: j['name'] as String,
        main: j['main'] == true,
        status: j['status'] as String,
        entries: [
          for (final e in (j['entries'] as List))
            MainMenuEntry.fromJson((e as Map).cast<String, dynamic>()),
        ],
      );
}

/// Loaded main menu data. Populated by [loadMainMenu] (app) or [setMainMenuData] (tests).
List<MainMenuArc> mainMenuArcs = const [];
Map<String, String> mainMenuNoteRu = const {};

/// Parse the generated main_menu_data.json into (arcs, noteRu).
(List<MainMenuArc>, Map<String, String>) parseMainMenuData(Map<String, dynamic> json) {
  final arcs = [
    for (final a in (json['arcs'] as List))
      MainMenuArc.fromJson((a as Map).cast<String, dynamic>()),
  ];
  final ru = (json['noteRu'] as Map).map((k, v) => MapEntry('$k', '$v'));
  return (arcs, ru);
}

void setMainMenuData((List<MainMenuArc>, Map<String, String>) data) {
  mainMenuArcs = data.$1;
  mainMenuNoteRu = data.$2;
}

/// Load the main menu data asset (call once at startup).
Future<void> loadMainMenu() async {
  final s = await rootBundle.loadString('assets/main_menu_data.json');
  setMainMenuData(parseMainMenuData(jsonDecode(s) as Map<String, dynamic>));
}

/// Localize a main menu note for the given UI language.
String? localizeNote(String? note, String lang) {
  if (note == null) return note;
  return lang == 'ru' ? (mainMenuNoteRu[note] ?? note) : note;
}

// --- resolved / v2 main menu models ---

class SubStory {
  final String name;
  final String? txt; // null if it couldn't be matched in the data
  const SubStory(this.name, this.txt);
}

class MainMenuNode {
  final String title;
  final bool optional;
  final bool isIS;
  final String? lead;
  final String? note;
  final EventGroup? event;
  final List<SubStory>? subStories;

  const MainMenuNode({
    required this.title,
    this.optional = false,
    this.isIS = false,
    this.lead,
    this.note,
    this.event,
    this.subStories,
  });
}

class ResolvedArc {
  final String name;
  final bool main;
  final String status;
  final List<MainMenuNode> nodes;
  const ResolvedArc({
    required this.name,
    required this.main,
    required this.status,
    required this.nodes,
  });
}

/// A main menu node enriched for the v2 main menu screen.
class EpisodeNode extends MainMenuNode {
  /// The matched event is a Main Story (maintheme) episode.
  final bool isEpisode;

  /// Global maintheme sort index (Evil Time Part 1 = 0 = prologue); null for
  /// side stories. Used to pick the EpisodeBackgrounds/episode{N} backdrop.
  final int? episodeIndex;

  /// Interleaved side story inside a main arc — always show the Optional tag.
  final bool forceOptional;

  const EpisodeNode({
    required super.title,
    super.optional,
    super.isIS,
    super.lead,
    super.note,
    super.event,
    super.subStories,
    required this.isEpisode,
    required this.episodeIndex,
    required this.forceOptional,
  });
}

class Storyline {
  final String name;
  final bool main;
  final String status;
  final List<EpisodeNode> nodes;
  const Storyline({
    required this.name,
    required this.main,
    required this.status,
    required this.nodes,
  });
}

class MainMenu {
  final List<Storyline> mainArcs;
  final List<Storyline> sideStorylines;
  const MainMenu({required this.mainArcs, required this.sideStorylines});
}

class ChapterLocation {
  final String storyline;
  final int episodeNum;
  final String episodeName;
  final int chapterNum;
  final String chapterName;
  const ChapterLocation({
    required this.storyline,
    required this.episodeNum,
    required this.episodeName,
    required this.chapterNum,
    required this.chapterName,
  });
}

// --- matching main menu titles to in-game events ---

final _prefix =
    RegExp(r'^(prologue|episode\s*\d+)\s*[:\-]\s*', caseSensitive: false);
final _nonAlnum = RegExp(r'[^a-z0-9]+');
final _stopwords = RegExp(r'\b(the|a|of|is|are|be|will|that|our|im)\b');
final _spaces = RegExp(r'\s+');

String _norm(String s) {
  var out = removeDiacritics(s.toLowerCase());
  out = out.replaceAll('&', 'and');
  out = out.replaceFirst(_prefix, '');
  out = out.replaceAll(_nonAlnum, ' ');
  out = out.replaceAll(_stopwords, ' ');
  out = out.replaceAll(_spaces, ' ');
  return out.trim();
}

List<ResolvedArc> resolveMainMenu(List<Category> categories) {
  final index = <String, EventGroup>{};
  for (final cat in categories) {
    for (final ev in cat.events) {
      final key = _norm(ev.name);
      if (key.isNotEmpty && !index.containsKey(key)) index[key] = ev;
    }
  }

  EventGroup? matchEvent(String title) {
    final key = _norm(title);
    var ev = index[key];
    if (ev == null) {
      for (final entry in index.entries) {
        if (entry.key.contains(key) || key.contains(entry.key)) {
          ev = entry.value;
          break;
        }
      }
    }
    return ev;
  }

  final result = <ResolvedArc>[];
  for (final arc in mainMenuArcs) {
    final nodes = <MainMenuNode>[];
    for (final entry in arc.entries) {
      if (entry.isIS) {
        // Integrated Strategies: informational only (not in story data).
        nodes.add(MainMenuNode(
            title: entry.title, isIS: true, lead: entry.lead, note: entry.note));
        continue;
      }
      final event = matchEvent(entry.title);
      if (event == null) continue;
      List<SubStory>? subStories;
      if (entry.stories.isNotEmpty) {
        subStories = [
          for (final name in entry.stories)
            SubStory(name, _matchSubStory(event, name)),
        ];
      }
      nodes.add(MainMenuNode(
        title: entry.title,
        optional: entry.optional,
        lead: entry.lead,
        note: entry.note,
        event: event,
        subStories: subStories,
      ));
    }
    result.add(ResolvedArc(
        name: arc.name, main: arc.main, status: arc.status, nodes: nodes));
  }
  return result.where((a) => a.nodes.isNotEmpty).toList();
}

String? _matchSubStory(EventGroup event, String name) {
  final nk = _norm(name);
  for (final s in event.stories) {
    final sn = _norm(s.name);
    if (sn == nk || sn.contains(nk) || nk.contains(sn)) return s.txt;
  }
  return null;
}

/// Build the v2 main menu: resolve arcs to events, then annotate each node with its
/// episode index (for backgrounds) and whether to force the Optional tag.
MainMenu buildMainMenu(List<Category> categories) {
  final resolved = resolveMainMenu(categories);

  // Maintheme events are pre-sorted by episode order, so array position = index.
  Category? mainCat;
  for (final c in categories) {
    if (c.key == 'maintheme') {
      mainCat = c;
      break;
    }
  }
  final epIndex = <String, int>{};
  if (mainCat != null) {
    for (var i = 0; i < mainCat.events.length; i++) {
      epIndex[mainCat.events[i].id] = i;
    }
  }

  Storyline annotate(ResolvedArc arc, bool isMainArc) => Storyline(
        name: arc.name,
        main: arc.main,
        status: arc.status,
        nodes: [
          for (final n in arc.nodes)
            () {
              final idx = n.event != null ? epIndex[n.event!.id] : null;
              final isEpisode = idx != null;
              return EpisodeNode(
                title: n.title,
                optional: n.optional,
                isIS: n.isIS,
                lead: n.lead,
                note: n.note,
                event: n.event,
                subStories: n.subStories,
                isEpisode: isEpisode,
                episodeIndex: idx,
                forceOptional: isMainArc && !isEpisode,
              );
            }(),
        ],
      );

  return MainMenu(
    mainArcs: [
      for (final a in resolved)
        if (a.main) annotate(a, true),
    ],
    sideStorylines: [
      for (final a in resolved)
        if (!a.main) annotate(a, false),
    ],
  );
}

/// Locate a chapter (storyTxt) within the main menu for the "continue reading"
/// label. Returns null if the chapter isn't part of any main menu storyline.
ChapterLocation? describeMainMenuLocation(MainMenu mainMenu, String txt, String mainLabel) {
  ChapterLocation? search(List<EpisodeNode> nodes, String storyline, bool main) {
    var ordinal = 0;
    for (final node in nodes) {
      if (node.event == null) continue;
      ordinal++;
      final ci = node.event!.stories.indexWhere((s) => s.txt == txt);
      if (ci == -1) continue;
      final st = node.event!.stories[ci];
      final episodeNum =
          main && node.isEpisode && node.episodeIndex != null
              ? node.episodeIndex!
              : ordinal;
      return ChapterLocation(
        storyline: storyline,
        episodeNum: episodeNum,
        episodeName: node.event!.name,
        chapterNum: ci + 1,
        chapterName: st.name.isNotEmpty
            ? st.name
            : (st.code.isNotEmpty ? st.code : st.txt),
      );
    }
    return null;
  }

  final mainNodes = [for (final a in mainMenu.mainArcs) ...a.nodes];
  final inMain = search(mainNodes, mainLabel, true);
  if (inMain != null) return inMain;
  for (final s in mainMenu.sideStorylines) {
    final hit = search(s.nodes, s.name, false);
    if (hit != null) return hit;
  }
  return null;
}
