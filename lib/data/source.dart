// Data + asset source layer.
//
// Ported from BetterPhoneReader/src/data/source.ts. Asset URL logic mirrors the
// akgcc reader (js/util.js): primary source is the akgcc/arkdata repo via
// jsDelivr, with Aceship as a fallback for art.
//
// The URL builders are pure functions (unit-tested); `getData`/`getJson` use
// package:http instead of the browser `fetch` — and, being native, no longer
// have to fight CORS (the web version's jsDelivr-CORS-on-404 workarounds are
// simply unnecessary here).

import 'dart:convert';
import 'package:http/http.dart' as http;

import 'models.dart';

const _arkdata = 'https://cdn.jsdelivr.net/gh/akgcc/arkdata@main/assets';
const _thumbs = 'https://cdn.jsdelivr.net/gh/akgcc/arkdata@main/thumbs';
const _aceship = 'https://cdn.jsdelivr.net/gh/Aceship/Arknight-Images@main';

class GameDataRepos {
  static const github =
      'https://raw.githubusercontent.com/050644zf/ArknightsStoryJson/main/';
  static const m31ns = 'https://r2.m31ns.top/';
}

/// Fetch a game-data JSON path, trying the fast mirror first then GitHub. Each
/// attempt is bounded by a timeout so a flaky/half-open connection fails (and
/// can fall back to cache) instead of hanging forever.
Future<http.Response> getData(
  String server,
  String path, {
  Duration timeout = const Duration(milliseconds: 8000),
}) async {
  Future<http.Response> tryFetch(String base) async {
    final res =
        await http.get(Uri.parse('$base$server$path')).timeout(timeout);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw http.ClientException('HTTP ${res.statusCode}', Uri.parse('$base$server$path'));
    }
    return res;
  }

  try {
    return await tryFetch(GameDataRepos.m31ns);
  } catch (_) {
    return await tryFetch(GameDataRepos.github);
  }
}

Future<T> getJson<T>(
  String server,
  String path, {
  Duration? timeout,
}) async {
  final res = timeout == null
      ? await getData(server, path)
      : await getData(server, path, timeout: timeout);
  return jsonDecode(res.body) as T;
}

String _enc(String s) => Uri.encodeComponent(s);

/// Background: try arkdata, then Aceship.
List<String> backgroundSrcs(String image) => [
      '$_arkdata/torappu/dynamicassets/avg/backgrounds/$image.png'.toLowerCase(),
      '$_aceship/avg/backgrounds/$image.png',
    ];

/// Full-screen `Image` (CG illustration) command assets. These live under
/// avg/images/ (NOT avg/backgrounds/), e.g. opening splash art / CGs.
List<String> imageSrcs(String image) => [
      '$_arkdata/torappu/dynamicassets/avg/images/$image.png'.toLowerCase(),
      '$_aceship/avg/images/$image.png',
    ];

/// Background OR full-screen image, by kind (see parse.dart `bgImage`).
List<String> sceneSrcs(String id, {bool isImage = false}) =>
    isImage ? imageSrcs(id) : backgroundSrcs(id);

/// Operator avatar icon (square, pre-cropped frame).
String operatorAvatar(String charId) {
  final suffix = charId.contains('_amiya') ? '_2' : '';
  return '$_arkdata/torappu/dynamicassets/arts/charavatars/$charId$suffix.png'
      .toLowerCase();
}

/// Mystery / unknown NPC avatar.
final String mysteryAvatar = operatorAvatar('avg_npc_012');

/// Story SFX/music key -> candidate mp3 urls (most story SFX live under avg/).
List<String> soundSrcs(String key) {
  final k = key.replaceFirst(RegExp(r'^\$'), '');
  const base = '$_arkdata/torappu/dynamicassets/audio/sound_beta_2';
  return [
    '$base/avg/$k.mp3'.toLowerCase(),
    '$base/dialog/$k.mp3'.toLowerCase(),
    '$base/general/$k.mp3'.toLowerCase(),
    '$base/music/$k.mp3'.toLowerCase(),
  ];
}

class _ParsedId {
  final String baseId;
  final String face;
  final String body;
  const _ParsedId(this.baseId, this.face, this.body);
}

// Parse "<id>#<face>$<body>" (face/body optional), stripping leading zeros off
// face/body and defaulting each to "1".
_ParsedId _parseId(String id) {
  final m = RegExp(r'^(.*?)(?:#(\d+))?(?:\$(\d+))?$').firstMatch(id);
  final baseId =
      (m?.group(1) ?? id).replaceAll(RegExp(r'[#$].*$'), '');
  var face = (m?.group(2) ?? '1').replaceFirst(RegExp(r'^0+'), '');
  if (face.isEmpty) face = '1';
  var body = (m?.group(3) ?? '1').replaceFirst(RegExp(r'^0+'), '');
  if (body.isEmpty) body = '1';
  return _ParsedId(baseId, face, body);
}

/// The character identity of a portrait id, dropping the `#face$body` suffix.
/// Two portraits share a base id iff they are the same character (a change of
/// expression), which lets the VN sprite swap in place instead of cross-fading.
String portraitBaseId(String rawId) => _parseId(rawId.trim()).baseId;

/// Build the avatar fallback chain for a story portrait id. Returns ordered
/// candidates; each tagged whether it needs head-cropping (full character art)
/// or fills the box as-is (square operator/mystery icon).
List<AvatarCandidate> avatarCandidates(String rawId) {
  final id = rawId.trim();
  if (id.isEmpty) return [];

  final parsed = _parseId(id);
  final baseId = parsed.baseId;
  final face = parsed.face;
  final body = parsed.body;

  final fullNameRaw = '$baseId#$face\$$body';
  // Full character art keeps the RAW id prefix for operators (char_…); the avg_
  // swap is only correct for NPCs that already start with avg_. Try both.
  final avgId = baseId.replaceFirst(RegExp(r'^char_'), 'avg_');
  // Operator avatar icons drop the skin suffix (char_130_doberm_1 -> char_130_doberm).
  final opBase = baseId.replaceFirst(RegExp(r'_\d+$'), '');

  AvatarCandidate thumb(String n) =>
      AvatarCandidate('$_thumbs/${_enc(n)}.webp'.toLowerCase(), false);
  AvatarCandidate art(String n) =>
      AvatarCandidate('$_arkdata/avg/characters/${_enc(n)}.png'.toLowerCase(), true);
  AvatarCandidate icon(String n) => AvatarCandidate(operatorAvatar(n), false);

  return [
    // 1. Pre-cropped frames where they exist (operators + important NPCs).
    thumb(fullNameRaw),
    thumb('$baseId#$face'),
    thumb(baseId),
    // 2. Otherwise crop the full character art ourselves (raw prefix first).
    art('$baseId#$face\$$body'),
    art('$baseId#$face'),
    art(baseId),
    art('$avgId#$face\$$body'),
    art('$avgId#$face'),
    art(avgId),
    AvatarCandidate('$_aceship/avg/characters/${_enc(baseId)}.png', true),
    // 3. Operator icon, then mystery NPC.
    icon(opBase),
    icon(baseId),
    AvatarCandidate(mysteryAvatar, false),
  ];
}

/// Full, uncropped character art for VN mode (no thumbnails, no icons, no
/// mystery fallback). Ordered candidate urls; empty if no portrait.
List<String> spriteCandidates(String rawId) {
  final id = rawId.trim();
  if (id.isEmpty) return [];

  final parsed = _parseId(id);
  final baseId = parsed.baseId;
  final face = parsed.face;
  final body = parsed.body;

  // arkdata's full character art keeps the RAW id prefix — operator sprites are
  // filed under char_… (e.g. char_010_chen_1#1$1.png), NOT avg_…. Try the raw
  // id first, then the avg_ variant as a fallback.
  final avgId = baseId.replaceFirst(RegExp(r'^char_'), 'avg_');
  String art(String n) =>
      '$_arkdata/avg/characters/${_enc(n)}.png'.toLowerCase();
  String ace(String n) =>
      '$_aceship/avg/characters/${_enc(n)}.png'.toLowerCase();
  List<String> forms(String b) => ['$b#$face\$$body', '$b#$face', b];

  final ids = [
    ...forms(baseId),
    if (avgId != baseId) ...forms(avgId),
  ];
  return [...ids.map(art), ...ids.map(ace)];
}
