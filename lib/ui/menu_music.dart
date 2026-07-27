// Looping background music for the main menu. A single bundled track that plays
// while the main menu is the visible route and pauses under the reader (which
// has its own story music). Respects the musicEnabled / musicVolume settings.
//
// Defensive like [ReaderAudio]: without a platform audio channel (widget tests)
// the player fails to construct and every call degrades to a no-op.

import 'dart:async' show unawaited;

import 'package:flutter/widgets.dart';
import 'package:just_audio/just_audio.dart';

/// Observes route pushes/pops so the main menu can pause its music while another
/// screen is on top and resume on return. Registered on [MaterialApp] and
/// subscribed to by the main-menu screen (see [RouteAware]).
final RouteObserver<PageRoute<dynamic>> routeObserver =
    RouteObserver<PageRoute<dynamic>>();

class MenuMusic {
  // Space in the filename is intentional — matches the bundled asset.
  static const _asset = 'assets/Music/Main menu.mp3';

  AudioPlayer? _player;
  bool _loaded = false;
  bool _disposed = false;

  /// Whether the main menu is the foreground route (false while it's covered by
  /// the reader / settings / a trailer). Playback only runs when foreground.
  bool foreground = true;

  MenuMusic() {
    try {
      _player = AudioPlayer();
    } catch (_) {
      _player = null; // no audio channel — stay silent
    }
  }

  Future<void> _ensureLoaded() async {
    final p = _player;
    if (p == null || _loaded) return;
    try {
      await p.setAsset(_asset);
      await p.setLoopMode(LoopMode.one);
      _loaded = true;
    } catch (_) {
      // asset missing / unplayable — stay silent
    }
  }

  /// Reconcile playback with the current settings + foreground state. Safe to
  /// call repeatedly: on init, on settings changes, and on route transitions.
  Future<void> apply({required bool enabled, required double volume}) async {
    final p = _player;
    if (p == null || _disposed) return;
    await _ensureLoaded();
    if (!_loaded || _disposed) return;
    try {
      await p.setVolume(volume);
      if (enabled && foreground) {
        if (!p.playing) unawaited(p.play());
      } else {
        await p.pause();
      }
    } catch (_) {
      // ignore transient audio errors rather than throwing into the UI
    }
  }

  void dispose() {
    _disposed = true;
    _player?.dispose();
    _player = null;
  }
}
