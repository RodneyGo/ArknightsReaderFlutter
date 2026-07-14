// Settings store. Ported from BetterPhoneReader/src/stores/settings.ts (Pinia).
// State is an immutable [SettingsState] value; the store is a ChangeNotifier that
// persists the whole object as JSON on every change (mirroring Pinia's persist()).

import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'kv_store.dart';

const _lsKey = 'bpr.settings';

@immutable
class SettingsState {
  final String server; // content language / game server
  final String altServer; // side-by-side compare language, or "none"
  final String doctorName; // replaces {@nickname}
  final int fontSize; // px
  final bool showBackground;
  final bool soundEnabled; // show sound buttons + allow playback
  final bool soundAutoplay; // auto-play a sound once when it reaches centre
  final bool musicEnabled; // auto-play looping background music
  final double musicVolume; // 0..1
  final double soundVolume; // 0..1 (SFX)
  final String readerMode; // "novel" | "vn"
  final String textSpeed; // "slow" | "normal" | "fast" | "instant"
  final bool debugPerf; // show an FPS/perf overlay on the main menu

  const SettingsState({
    this.server = 'en_US',
    this.altServer = 'none',
    this.doctorName = 'Doctor',
    this.fontSize = 16,
    this.showBackground = true,
    this.soundEnabled = true,
    this.soundAutoplay = false,
    this.musicEnabled = true,
    this.musicVolume = 0.45,
    this.soundVolume = 1,
    this.readerMode = 'novel',
    this.textSpeed = 'normal',
    this.debugPerf = false,
  });

  /// Parse stored JSON, falling back to defaults for missing/invalid keys
  /// (mirrors the TS `{ ...defaults, ...JSON.parse(raw) }`).
  factory SettingsState.fromJson(Map<String, dynamic> j) {
    const d = SettingsState();
    String str(String k, String fb) => j[k] is String ? j[k] as String : fb;
    bool boolean(String k, bool fb) => j[k] is bool ? j[k] as bool : fb;
    int integer(String k, int fb) => j[k] is num ? (j[k] as num).toInt() : fb;
    double dbl(String k, double fb) =>
        j[k] is num ? (j[k] as num).toDouble() : fb;
    return SettingsState(
      server: str('server', d.server),
      altServer: str('altServer', d.altServer),
      doctorName: str('doctorName', d.doctorName),
      fontSize: integer('fontSize', d.fontSize),
      showBackground: boolean('showBackground', d.showBackground),
      soundEnabled: boolean('soundEnabled', d.soundEnabled),
      soundAutoplay: boolean('soundAutoplay', d.soundAutoplay),
      musicEnabled: boolean('musicEnabled', d.musicEnabled),
      musicVolume: dbl('musicVolume', d.musicVolume),
      soundVolume: dbl('soundVolume', d.soundVolume),
      readerMode: str('readerMode', d.readerMode),
      textSpeed: str('textSpeed', d.textSpeed),
      debugPerf: boolean('debugPerf', d.debugPerf),
    );
  }

  Map<String, dynamic> toJson() => {
        'server': server,
        'altServer': altServer,
        'doctorName': doctorName,
        'fontSize': fontSize,
        'showBackground': showBackground,
        'soundEnabled': soundEnabled,
        'soundAutoplay': soundAutoplay,
        'musicEnabled': musicEnabled,
        'musicVolume': musicVolume,
        'soundVolume': soundVolume,
        'readerMode': readerMode,
        'textSpeed': textSpeed,
        'debugPerf': debugPerf,
      };

  SettingsState copyWith({
    String? server,
    String? altServer,
    String? doctorName,
    int? fontSize,
    bool? showBackground,
    bool? soundEnabled,
    bool? soundAutoplay,
    bool? musicEnabled,
    double? musicVolume,
    double? soundVolume,
    String? readerMode,
    String? textSpeed,
    bool? debugPerf,
  }) =>
      SettingsState(
        server: server ?? this.server,
        altServer: altServer ?? this.altServer,
        doctorName: doctorName ?? this.doctorName,
        fontSize: fontSize ?? this.fontSize,
        showBackground: showBackground ?? this.showBackground,
        soundEnabled: soundEnabled ?? this.soundEnabled,
        soundAutoplay: soundAutoplay ?? this.soundAutoplay,
        musicEnabled: musicEnabled ?? this.musicEnabled,
        musicVolume: musicVolume ?? this.musicVolume,
        soundVolume: soundVolume ?? this.soundVolume,
        readerMode: readerMode ?? this.readerMode,
        textSpeed: textSpeed ?? this.textSpeed,
        debugPerf: debugPerf ?? this.debugPerf,
      );
}

class SettingsStore extends ChangeNotifier {
  final KeyValueStore _kv;
  SettingsState _state;

  SettingsStore(this._kv) : _state = _load(_kv);

  static SettingsState _load(KeyValueStore kv) {
    final raw = kv.getString(_lsKey);
    if (raw != null) {
      try {
        return SettingsState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        /* ignore malformed */
      }
    }
    return const SettingsState();
  }

  SettingsState get state => _state;

  /// Replace the whole settings object, persist, and notify. UI uses
  /// `store.set(store.state.copyWith(fontSize: 18))` (the Dart shape of the TS
  /// `settings.set(key, value)`).
  void set(SettingsState next) {
    _state = next;
    _kv.setString(_lsKey, jsonEncode(_state.toJson()));
    notifyListeners();
  }
}
