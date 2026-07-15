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

  /// Story-item id of the active music row.
  int? currentMusicId;

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
    final p = _player(false);
    if (p == null) return;
    _autoPlayed.add(item.id);
    playingSfxId = item.id;
    notifyListeners();
    try {
      await p.stop();
      final ok = await _load(p, audio_data.resolveSound(item.key, _soundMap));
      // Bail if disposed or superseded by a newer sound while we were loading.
      if (!ok || _disposed || playingSfxId != item.id) {
        if (!ok && playingSfxId == item.id) {
          playingSfxId = null;
          if (!_disposed) notifyListeners();
        }
        return;
      }
      await p.setVolume(volume);
      unawaited(p.play());
    } catch (_) {
      if (playingSfxId == item.id) {
        playingSfxId = null;
        if (!_disposed) notifyListeners();
      }
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

  Future<void> switchMusic(MusicRow row, double volume) async {
    final p = _player(true);
    if (p == null) return;
    currentMusicId = row.id;
    notifyListeners();
    try {
      await p.stop();
      final ok = await _load(p, audio_data.resolveSound(row.key, _soundMap));
      // A later row may have won the race while this one loaded.
      if (!ok || _disposed || currentMusicId != row.id) return;
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
    if (currentMusicId != null) {
      currentMusicId = null;
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
