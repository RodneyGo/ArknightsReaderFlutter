// Sound/music URL resolution. Ported from BetterPhoneReader/src/data/audio.ts.
//
// story_variables.json is the "soundMap": it maps a sound key to a full asset
// path (e.g. "Sound_Beta_2/Music/beta2_180603/m_dia_escape_loop"). The akgcc
// data mirror doesn't ship it, so we pull it from ArknightsAssets. Sound paths
// are server-agnostic, so EN is fine for all.

import 'dart:convert';
import 'package:http/http.dart' as http;

import 'localstore.dart';

const _arkdata = 'https://cdn.jsdelivr.net/gh/akgcc/arkdata@main/assets';
const _soundMapUrl =
    'https://raw.githubusercontent.com/ArknightsAssets/ArknightsGamedata/master/en/gamedata/story/story_variables.json';

Future<Map<String, String>>? _soundMapFuture;

/// Load (and cache) the key -> asset-path sound map. Cached for the process
/// lifetime like the TS module-level promise.
Future<Map<String, String>> loadSoundMap() =>
    _soundMapFuture ??= _fetchSoundMap();

/// Reset the cached map — for tests.
void resetSoundMapCache() => _soundMapFuture = null;

Future<Map<String, String>> _fetchSoundMap() async {
  try {
    final res = await http.get(Uri.parse(_soundMapUrl));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      return j.map((k, v) => MapEntry(k, v.toString()));
    }
  } catch (_) {
    // fall through to the offline fallback
  }
  // Offline: downloadStory() saves the map alongside the chapter, so a
  // downloaded chapter's sounds still resolve with no network.
  try {
    final store = await LocalStore.instance();
    final meta = await store.readMeta('story_variables');
    if (meta != null) return meta.map((k, v) => MapEntry(k, v.toString()));
  } catch (_) {
    // no filesystem (web) or nothing saved yet
  }
  return {};
}

/// Resolve a PlaySound/PlayMusic key to candidate mp3 urls.
List<String> resolveSound(String key, Map<String, String> soundMap) {
  final k = key.replaceFirst(RegExp(r'^\$'), '');
  final mapped = soundMap[k];
  const base = '$_arkdata/torappu/dynamicassets/audio';
  final urls = <String>[];
  if (mapped != null && mapped.isNotEmpty) {
    urls.add('$base/$mapped.mp3'.toLowerCase());
  }
  // Fallbacks for keys missing from the map.
  urls.add('$base/sound_beta_2/avg/$k.mp3'.toLowerCase());
  urls.add('$base/sound_beta_2/music/$k.mp3'.toLowerCase());
  return urls;
}
