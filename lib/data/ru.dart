// Russian story overlay. Ported from BetterPhoneReader/src/data/ru.ts.
//
// There is no Russian game-data server, so "Русский" loads the EN chapter as the
// base and overlays bundled translations where they exist (keyed by storyTxt).
// Untranslated chapters fall back to English.
//
// The web used `import.meta.glob("./ru/*.json", { eager: true })`; the Dart
// equivalent is reading the bundled assets off the AssetManifest at startup.
//
// Unlike the TS, which mutated each line's attributes in place, this rebuilds the
// lines it changes: a RawLine parsed from json with no attributes holds a const
// map, and writing to that throws.

import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show rootBundle, AssetManifest;

import 'models.dart';

class RuOverlay {
  final String path;
  final Map<String, String> names; // speaker name (EN) -> RU
  final Map<String, String> lines; // line id -> translated text

  const RuOverlay({
    required this.path,
    this.names = const {},
    this.lines = const {},
  });

  /// Null when the json isn't an overlay — `_GLOSSARY.json` and friends live in
  /// the same folder and carry no `path`.
  static RuOverlay? tryFromJson(Map<String, dynamic> json) {
    final path = json['path'];
    if (path is! String || path.isEmpty) return null;
    Map<String, String> strMap(Object? v) => v is Map
        ? {for (final e in v.entries) '${e.key}': '${e.value}'}
        : const {};
    return RuOverlay(
      path: path,
      names: strMap(json['names']),
      lines: strMap(json['lines']),
    );
  }
}

Map<String, RuOverlay> _byPath = const {};

/// Load the bundled overlays. Call once at startup.
Future<void> loadRuOverlays() async {
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  final paths = manifest
      .listAssets()
      .where((p) => p.startsWith('assets/ru/') && p.endsWith('.json'));
  final map = <String, RuOverlay>{};
  for (final asset in paths) {
    try {
      final json = jsonDecode(await rootBundle.loadString(asset));
      if (json is! Map) continue;
      final ov = RuOverlay.tryFromJson(json.cast<String, dynamic>());
      if (ov != null) map[ov.path] = ov;
    } catch (_) {
      // A malformed overlay must not stop the app booting — that chapter just
      // stays English.
    }
  }
  _byPath = map;
}

@visibleForTesting
void setRuOverlays(Iterable<RuOverlay> overlays) =>
    _byPath = {for (final o in overlays) o.path: o};

/// True if a Russian translation is bundled for this chapter.
bool hasRu(String path) => _byPath.containsKey(path);

/// Overlay Russian text onto an EN base story. Returns [list] untouched when the
/// chapter has no translation.
List<RawLine> applyRu(List<RawLine> list, String path) {
  final ov = _byPath[path];
  if (ov == null) return list;
  return [for (final line in list) _applyLine(line, ov)];
}

RawLine _applyLine(RawLine line, RuOverlay ov) {
  final a = line.attributes;
  final prop = line.prop.toLowerCase();
  final isSpeakerLine = prop == 'name' || prop == 'multiline';

  String? newName;
  if (isSpeakerLine) {
    final cur = a['name']?.toString() ?? '';
    if (cur.isNotEmpty) newName = ov.names[cur];
  }
  final text = ov.lines[line.id.toString()];
  if (newName == null && text == null) return line;

  final next = Map<String, dynamic>.from(a);
  if (newName != null) next['name'] = newName;
  if (text != null) {
    // Whichever field this line's text lives in. Falls back to `content`, which
    // is what a dialogue line uses.
    if (a.containsKey('content')) {
      next['content'] = text;
    } else if (a.containsKey('text')) {
      next['text'] = text;
    } else if (a.containsKey('options')) {
      next['options'] = text;
    } else {
      next['content'] = text;
    }
  }
  return RawLine(
    id: line.id,
    prop: line.prop,
    attributes: next,
    alt: line.alt,
  );
}
