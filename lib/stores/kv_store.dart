// A tiny synchronous key-value store abstraction — the Dart stand-in for the
// web app's `localStorage`. The stores (settings/progress/offline) talk to this
// so they stay pure and unit-testable (inject [MemoryKeyValueStore]) while the
// app wires in [SharedPrefsStore]. Swapping to Hive later means one new impl.

import 'package:shared_preferences/shared_preferences.dart';

abstract class KeyValueStore {
  String? getString(String key);
  void setString(String key, String value);
  void remove(String key);
}

/// In-memory implementation for tests.
class MemoryKeyValueStore implements KeyValueStore {
  final Map<String, String> _m;
  MemoryKeyValueStore([Map<String, String>? initial]) : _m = {...?initial};

  @override
  String? getString(String key) => _m[key];
  @override
  void setString(String key, String value) => _m[key] = value;
  @override
  void remove(String key) => _m.remove(key);
}

/// shared_preferences-backed implementation. The legacy [SharedPreferences] keeps
/// an in-memory cache, so reads are synchronous and writes update the cache
/// immediately (persisting asynchronously — fire-and-forget, mirroring the web's
/// synchronous localStorage writes).
class SharedPrefsStore implements KeyValueStore {
  final SharedPreferences _prefs;
  SharedPrefsStore(this._prefs);

  static Future<SharedPrefsStore> create() async =>
      SharedPrefsStore(await SharedPreferences.getInstance());

  @override
  String? getString(String key) => _prefs.getString(key);
  @override
  void setString(String key, String value) => _prefs.setString(key, value);
  @override
  void remove(String key) => _prefs.remove(key);
}
