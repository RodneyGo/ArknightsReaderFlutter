// Story audio: one-shot SFX + a single looping background track that switches as
// the story scrolls. Ported from the audio half of BetterPhoneReader/src/views/
// StoryView.vue.
//
// resolveSound() returns *candidate* urls (the mapped path, then two guesses for
// keys missing from the sound map), so loading walks the chain until one works —
// which is why this uses just_audio: setUrl() throws on a bad url.
//
// The two scroll rules ([activeMusic], [sfxCrossingCentre]) are pure functions
// over RowGeometry so they can be tested without a platform audio channel.

import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../data/audio.dart' as audio_data;
import '../data/models.dart';
import 'row_geometry.dart';

/// A PlayMusic row: [id] is the story item id, [index] its position in the
/// displayed list.
typedef MusicRow = ({int id, int index, String key});

/// Collect the PlayMusic rows of a displayed item list, in order.
List<MusicRow> musicRowsOf(List<StoryItem> items) {
  final out = <MusicRow>[];
  for (var i = 0; i < items.length; i++) {
    final it = items[i];
    if (it is SoundItem && it.music) out.add((id: it.id, index: i, key: it.key));
  }
  return out;
}

/// The track that should be playing: the last PlayMusic row the reader has
/// reached. Mirrors the web rule "start offset <= scrollTop + [lookahead]",
/// which starts a track just before its row reaches the top of the viewport.
///
/// A row with no geometry has been built and discarded, or never built: if it
/// sits before the first visible row it's been scrolled past (reached), and
/// otherwise it's still below the viewport (not reached).
MusicRow? activeMusic(
  List<MusicRow> music,
  RowGeometry geom, {
  double lookahead = 240,
}) {
  final firstVisible = geom.firstVisibleIndex;
  MusicRow? active;
  for (final m in music) {
    final box = geom.boxOf(m.index);
    final reached = box != null
        ? box.top <= lookahead
        : firstVisible != null && m.index < firstVisible;
    if (!reached) break; // rows are ordered; nothing later can be reached
    active = m;
  }
  return active;
}

/// The track playing at [idx]: the most recent PlayMusic at or before it.
///
/// VN mode needs this because its forward walk only fires music commands it steps
/// *through* — resuming, or jumping from the log, lands past them.
String? activeMusicKeyAt(List<StoryItem> items, int idx) {
  for (var k = idx.clamp(0, items.length - 1); k >= 0; k--) {
    final it = items[k];
    if (it is SoundItem && it.music) return it.key;
  }
  return null;
}

/// SFX rows whose centre has just crossed the viewport centre — the trigger for
/// autoplay. Excludes music rows (those play automatically) and anything in
/// [alreadyPlayed].
List<SoundItem> sfxCrossingCentre(
  List<StoryItem> items,
  RowGeometry geom,
  Set<int> alreadyPlayed,
) {
  final mid = geom.viewportHeight / 2;
  final out = <SoundItem>[];
  for (final box in geom.rows) {
    if (box.index < 0 || box.index >= items.length) continue;
    final it = items[box.index];
    if (it is! SoundItem || it.music) continue;
    if (alreadyPlayed.contains(it.id)) continue;
    final centre = (box.top + box.bottom) / 2;
    if (centre <= mid && centre > 0) out.add(it);
  }
  return out;
}

/// Owns the two players. Players are created lazily and defensively: without a
/// platform audio channel (widget tests) construction fails and every call
/// degrades to a no-op rather than throwing.
class ReaderAudio extends ChangeNotifier {
  Map<String, String> _soundMap = const {};
  AudioPlayer? _sfxPlayer;
  AudioPlayer? _musicPlayer;
  bool _disposed = false;

  /// Story-item id of the SFX currently playing, for the chip highlight.
  int? playingSfxId;

  /// Story-item id of the active music row. Novel mode dedupes on this: two
  /// PlayMusic rows sharing a key restart the track, as the web did.
  int? currentMusicId;

  /// Key of the active track. VN mode dedupes on this instead, so stepping onto
  /// a second PlayMusic row with the same key doesn't restart it.
  String? currentMusicKey;

  final _autoPlayed = <int>{};

  Future<void> loadSoundMap() async {
    final map = await audio_data.loadSoundMap();
    if (_disposed) return;
    _soundMap = map;
  }

  /// Forget which SFX have auto-played (on chapter change).
  void resetAutoplay() => _autoPlayed.clear();

  AudioPlayer? _player(bool music) {
    final existing = music ? _musicPlayer : _sfxPlayer;
    if (existing != null) return existing;
    try {
      final p = AudioPlayer();
      if (music) {
        _musicPlayer = p;
      } else {
        _sfxPlayer = p;
        p.playerStateStream.listen((s) {
          if (s.processingState == ProcessingState.completed &&
              playingSfxId != null) {
            playingSfxId = null;
            if (!_disposed) notifyListeners();
          }
        });
      }
      return p;
    } catch (_) {
      return null; // no audio channel — stay silent
    }
  }

  /// Walk the candidate chain until one url loads.
  Future<bool> _load(AudioPlayer p, List<String> urls) async {
    for (final url in urls) {
      try {
        await p.setUrl(url);
        return true;
      } catch (_) {
        // 404 / unplayable — try the next candidate
      }
    }
    return false;
  }

  Future<void> playSfx(SoundItem item, double volume) async {
    _autoPlayed.add(item.id);
    playingSfxId = item.id;
    notifyListeners();
    final ok = await _playSfxKey(item.key, volume, ownerId: item.id);
    // Clear the chip if it failed and nothing newer has taken over.
    if (!ok && playingSfxId == item.id) {
      playingSfxId = null;
      if (!_disposed) notifyListeners();
    }
  }

  /// Fire a sound by key — VN mode walks the timeline and has no chip to light.
  Future<void> playSfxKey(String key, double volume) =>
      _playSfxKey(key, volume);

  Future<bool> _playSfxKey(String key, double volume, {int? ownerId}) async {
    final p = _player(false);
    if (p == null) return false;
    try {
      await p.stop();
      final ok = await _load(p, audio_data.resolveSound(key, _soundMap));
      // Bail if disposed, or superseded by a newer sound while we were loading.
      if (!ok || _disposed) return false;
      if (ownerId != null && playingSfxId != ownerId) return true;
      await p.setVolume(volume);
      unawaited(p.play());
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Auto-play any SFX rows that just crossed the viewport centre.
  Future<void> autoPlay(
    List<StoryItem> items,
    RowGeometry geom,
    double volume,
  ) async {
    for (final it in sfxCrossingCentre(items, geom, _autoPlayed)) {
      await playSfx(it, volume);
    }
  }

  /// Novel mode: switch to a PlayMusic row (deduped by row id upstream).
  Future<void> switchMusic(MusicRow row, double volume) async {
    currentMusicId = row.id;
    currentMusicKey = row.key;
    notifyListeners();
    await _startMusic(row.key, volume, token: row.id);
  }

  /// VN mode: play a track by key, ignoring a repeat of the one already playing.
  Future<void> playMusicKey(String key, double volume) async {
    if (key == currentMusicKey) return;
    currentMusicId = null;
    currentMusicKey = key;
    notifyListeners();
    await _startMusic(key, volume, token: null);
  }

  /// [token] guards against a later switch winning the race while this loads;
  /// null means "guard on the key alone".
  Future<void> _startMusic(String key, double volume, {int? token}) async {
    final p = _player(true);
    if (p == null) return;
    try {
      await p.stop();
      final ok = await _load(p, audio_data.resolveSound(key, _soundMap));
      if (!ok || _disposed) return;
      final superseded =
          token != null ? currentMusicId != token : currentMusicKey != key;
      if (superseded) return;
      await p.setLoopMode(LoopMode.one);
      await p.setVolume(volume);
      unawaited(p.play());
    } catch (_) {
      // leave the chip lit but silent rather than throwing mid-scroll
    }
  }

  /// Switch to whichever track the current scroll position calls for.
  Future<void> updateMusic(
    List<MusicRow> music,
    RowGeometry geom,
    double volume,
  ) async {
    if (music.isEmpty) return;
    final active = activeMusic(music, geom);
    if (active == null || active.id == currentMusicId) return;
    await switchMusic(active, volume);
  }

  void stopMusic() {
    _musicPlayer?.stop();
    if (currentMusicId != null || currentMusicKey != null) {
      currentMusicId = null;
      currentMusicKey = null;
      if (!_disposed) notifyListeners();
    }
  }

  void stopAll() {
    _sfxPlayer?.stop();
    playingSfxId = null;
    stopMusic();
  }

  void setMusicVolume(double v) => _musicPlayer?.setVolume(v);

  @override
  void dispose() {
    _disposed = true;
    _sfxPlayer?.dispose();
    _musicPlayer?.dispose();
    super.dispose();
  }
}
