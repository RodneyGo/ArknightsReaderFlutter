// Story content parsing + normalization.
//
// Ported line-for-line from BetterPhoneReader/src/data/parse.ts. The character /
// speaker model mirrors the akgcc reader (js/story.js). Kept deliberately close
// to the TS so behaviour can be diffed against the original.
//
// NOTE: `parseContent` still emits an HTML fragment (the same string the web app
// fed to `v-html`). In Flutter this will be rendered by a small HTML-subset ->
// TextSpan converter rather than a WebView; keeping the intermediate HTML means
// the parsing rules (nickname/color/nbsp/line-break handling) port unchanged and
// stay independently testable.

import 'models.dart';

String _s(dynamic v) => v == null ? '' : v.toString();

/// Expand tokens, normalize line breaks, and sanitize `<color>` tags in a raw
/// content string. Returns an HTML fragment (or '' when empty).
String parseContent(String? content, String doctorName) {
  if (content == null || content.isEmpty) return '';

  final colorRe = RegExp(r'<color=([\w#]+)>(.+?)</color>',
      multiLine: true, dotAll: true);
  final nbspBefore = RegExp(r'(\s+)(</?\w+>)', multiLine: true);
  final nbspAfter = RegExp(r'(</?\w+>)(\s+)', multiLine: true);

  var out = content;
  out = out.replaceAll('{@nickname}', doctorName);
  out = out.replaceAll('{@Nickname}', doctorName);
  out = out.replaceAll('{@nbs}', '&nbsp;');
  out = out.replaceAll(RegExp(r'\r\n|\r|\n|\\n|\\r'), '<br>');
  // Color tags: drop near-black ones (invisible on the dark theme), keep the rest.
  out = out.replaceAllMapped(colorRe, (m) {
    final col = m[1]!;
    final inner = m[2]!;
    final c = col.toLowerCase();
    if (c == '#000000' || c == '#000' || c == 'black') return inner;
    return '<span style="color:$col">$inner</span>';
  });
  out = out.replaceAllMapped(nbspBefore, (m) => '&nbsp;${m[2]}');
  out = out.replaceAllMapped(nbspAfter, (m) => '${m[1]}&nbsp;');
  return out;
}

bool _eq(String a, String b) => a.toLowerCase() == b.toLowerCase();

const _mergeable = ['name', 'subtitle', 'sticker', 'multiline', 'decision'];

/// Interleave a comparison-language story into the main one, keeping only the
/// text-bearing props so the two can render side by side.
List<RawLine> mergeAltStory(List<RawLine> main, List<RawLine> alt) {
  final altMap = <int, RawLine>{};
  for (final r in alt) {
    final p = r.prop.toLowerCase();
    if (_mergeable.any((m) => m == p)) altMap[r.id] = r.copyWithAlt(true);
  }
  final out = <RawLine>[];
  for (final r in main) {
    out.add(r);
    final a = altMap[r.id];
    if (a != null) out.add(a);
  }
  return out;
}

/// Reduce a raw storyList into render-ready items. Tracks scene state
/// (Background/Image) and on-stage characters (Character/charslot/focus) to pick
/// the speaking portrait per line, and inserts scene-break gaps at
/// fade/background transitions.
List<StoryItem> normalizeStory(List<RawLine> list, String doctorName) {
  final items = <StoryItem>[];

  String? bg; // last real (non-black) background
  String? curImage; // active full-screen `Image` (CG) overlay, if any
  // The scene shown for an item = the CG image if one is active, else the bg.
  String? sceneId() => curImage ?? bg;
  bool sceneImg() => curImage != null;

  // On-stage characters keyed by slot. Old format ("character") uses slots
  // "name"/"name2"; new format ("charslot") uses "l"/"m"/"r". `activeSlot` is
  // the speaking slot.
  var chars = <String, String>{};
  String? activeSlot;
  var pendingBreak = false; // a fade/scene transition is waiting to be drawn

  String normSlot(String s) =>
      const {'left': 'l', 'middle': 'm', 'right': 'r'}[s] ?? s;

  // Decision/branch tracking.
  var group = 0; // 0 = not inside a decision
  var groupValues = <String>[]; // all option values for the current group
  List<String>? curRefs; // active branch refs (from Predicate)
  Branch? branchOf() =>
      group != 0 ? Branch(group, List<String>.from(curRefs ?? groupValues)) : null;

  String? activePortrait() {
    String? id;
    if (activeSlot != null) id = chars[activeSlot];
    if (id == null || id.isEmpty) {
      // Fall back to the only character on stage, if unambiguous.
      final present =
          chars.values.where((c) => c.isNotEmpty && c != 'char_empty').toList();
      if (present.length == 1) id = present[0];
    }
    return (id != null && id.isNotEmpty && id != 'char_empty') ? id : null;
  }

  void flushBreak() {
    if (pendingBreak && items.isNotEmpty) {
      // Carry the current background so a scene-break row at the top of the
      // viewport doesn't blank the backdrop.
      items.add(SceneBreakItem(
        id: -items.length,
        bg: sceneId(),
        bgImage: sceneImg(),
        branch: branchOf(),
      ));
    }
    pendingBreak = false;
  }

  for (final line in list) {
    final p = line.prop;
    final a = line.attributes;

    // --- state-updating props (no visible item) ---
    if (_eq(p, 'background')) {
      final img = _s(a['image']);
      if (img.isNotEmpty && img != 'bg_black') bg = img;
      pendingBreak = true; // background change = new scene
      continue;
    }
    if (_eq(p, 'image')) {
      // Full-screen CG illustration. `image` set = show it; empty = clear back
      // to the background. Lives under avg/images/ (see source.imageSrcs).
      final im = _s(a['image']);
      curImage = im.isNotEmpty ? im : null;
      pendingBreak = true;
      continue;
    }
    if (_eq(p, 'blocker')) {
      pendingBreak = true; // fade in/out = scene transition
      continue;
    }
    if (_eq(p, 'character')) {
      chars = {};
      final parsed = int.tryParse(_s(a['focus']));
      final f = (parsed == null || parsed == 0) ? 1 : parsed;
      var any = false;
      for (final k in a.keys) {
        if (k.startsWith('name')) {
          chars[k] = _s(a[k]);
          any = true;
        }
      }
      activeSlot = any ? (f == 1 ? 'name' : 'name$f') : null;
      continue;
    }
    if (_eq(p, 'charslot')) {
      // New format: each command places/updates one slot; `focus` = speaker.
      final slotRaw = _s(a['slot']);
      final hasName = a['name'] != null && a['name'] != '';
      final hasFocus = a['focus'] != null && a['focus'] != '';
      // An empty charslot (no slot/name/focus) clears the whole stage.
      if (slotRaw.isEmpty && !hasName && !hasFocus) {
        chars = {};
        activeSlot = null;
        continue;
      }
      final slot = normSlot(slotRaw);
      if (hasName) {
        chars[slot] = _s(a['name']);
      } else if (a['name'] == '' && slot.isNotEmpty) {
        chars.remove(slot); // empty name = clear that slot
      }
      if (hasFocus) {
        final fo = normSlot(_s(a['focus']));
        if (fo == 'n' || fo == 'none') {
          activeSlot = null;
        } else if (fo == 'all') {
          activeSlot = slot.isNotEmpty
              ? slot
              : (chars.keys.isNotEmpty ? chars.keys.first : null);
        } else {
          activeSlot = fo;
        }
      }
      continue;
    }
    if (_eq(p, 'predicate')) {
      final refs = _s(a['references'])
          .split(';')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      curRefs = refs.isEmpty ? null : refs;
      continue;
    }

    // --- visible props ---
    if (_eq(p, 'name') || _eq(p, 'multiline')) {
      final name = _s(a['name']).trim();
      final html = parseContent(a['content'] as String?, doctorName);
      if (html.isEmpty) continue;
      flushBreak();
      if (name.isNotEmpty) {
        items.add(DialogItem(
          id: line.id,
          name: name,
          html: html,
          portrait: activePortrait(),
          bg: sceneId(),
          bgImage: sceneImg(),
          alt: line.alt,
          branch: branchOf(),
        ));
      } else {
        items.add(NarrationItem(
          id: line.id,
          html: html,
          bg: sceneId(),
          bgImage: sceneImg(),
          alt: line.alt,
          branch: branchOf(),
        ));
      }
    } else if (_eq(p, 'subtitle') || _eq(p, 'sticker')) {
      final text = parseContent(
          _s(a['text']).isNotEmpty ? _s(a['text']) : _s(a['content']),
          doctorName);
      if (text.isNotEmpty) {
        flushBreak();
        items.add(SubtitleItem(
          id: line.id,
          text: text,
          bg: sceneId(),
          bgImage: sceneImg(),
          alt: line.alt,
          branch: branchOf(),
        ));
      }
    } else if (_eq(p, 'decision')) {
      final options = _s(a['options'])
          .split(';')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      final values = _s(a['values'])
          .split(';')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (options.isNotEmpty) {
        flushBreak();
        // Open a new branch group; the decision itself is always shown.
        group++;
        groupValues = values.isNotEmpty
            ? values
            : [for (var i = 0; i < options.length; i++) '${i + 1}'];
        curRefs = null;
        items.add(DecisionItem(
          id: line.id,
          options: options,
          values: groupValues,
          group: group,
          bg: sceneId(),
          bgImage: sceneImg(),
        ));
      }
    } else if (_eq(p, 'playsound') || _eq(p, 'playmusic')) {
      final key = _s(a['key']);
      if (key.isNotEmpty) {
        flushBreak();
        items.add(SoundItem(
          id: line.id,
          key: key,
          music: _eq(p, 'playmusic'),
          bg: sceneId(),
          bgImage: sceneImg(),
          branch: branchOf(),
        ));
      }
    }
  }

  // Backfill the opening (e.g. black-screen title cards) with the first scene
  // background so the start isn't bare black.
  final firstBgIdx = items.indexWhere((it) => it.bg != null);
  if (firstBgIdx > 0) {
    final firstBg = items[firstBgIdx].bg;
    final firstBgImage = items[firstBgIdx].bgImage;
    for (var i = 0; i < firstBgIdx; i++) {
      items[i].bg = firstBg;
      items[i].bgImage = firstBgImage;
    }
  }

  return items;
}
