// Load pipeline + view state for one chapter. Ported from the script half of
// BetterPhoneReader/src/views/StoryView.vue (the parts that aren't rendering).
//
// The screen stays dumb: this fetches the chapter, merges the optional alt-server
// text, normalizes it, seeds the decision defaults, and resolves the prev/next
// neighbours.

import 'package:flutter/foundation.dart';

import '../data/audio.dart';
import '../data/menu.dart';
import '../data/models.dart';
import '../data/offline.dart';
import '../data/parse.dart';
import '../data/servers.dart';
import '../data/source.dart';

class ReaderController extends ChangeNotifier {
  final Offline? offline;

  ReaderController({this.offline});

  bool _loading = true;
  int _loadingPct = 0;
  String? _error;
  String _title = '';
  List<StoryItem> _items = const [];
  Map<int, String> _selections = const {};
  Story? _prev;
  Story? _next;

  bool get loading => _loading;

  /// Asset-preload progress, 0-100. Stays 0 while the chapter json is in flight,
  /// and jumps straight to 100 for a downloaded chapter (nothing to fetch).
  int get loadingPct => _loadingPct;
  String? get error => _error;
  String get title => _title;
  Story? get prev => _prev;
  Story? get next => _next;
  Map<int, String> get selections => _selections;

  /// Items actually shown: branches whose option isn't selected are hidden.
  List<StoryItem> get displayItems {
    if (_selections.isEmpty) return _items;
    return _items.where((it) {
      final b = it.branch;
      return b == null || b.refs.contains(_selections[b.group]);
    }).toList();
  }

  /// Bumped on every [load] (and on dispose) so a slow, stale in-flight load can
  /// detect it's been superseded and bail out before mutating state.
  int _token = 0;

  void selectOption(int group, String value) {
    if (_selections[group] == value) return;
    _selections = {..._selections, group: value};
    notifyListeners();
  }

  /// Adopt a normalized chapter: default every decision to its first option.
  void setItems(List<StoryItem> items, {String title = ''}) {
    _title = title;
    _items = items;
    final sel = <int, String>{};
    for (final it in items) {
      if (it is DecisionItem) sel[it.group] = it.values.first;
    }
    _selections = sel;
    _loading = false;
    _error = null;
    notifyListeners();
  }

  Future<void> load({
    required String path,
    required String server,
    required String altServer,
    required String doctorName,
  }) async {
    final myToken = ++_token;
    _loading = true;
    _loadingPct = 0;
    _error = null;
    _items = const [];
    _selections = const {};
    _prev = null;
    _next = null;
    notifyListeners();

    // Fire-and-forget: the chapter shouldn't wait on the neighbour lookup.
    getNeighbors(server, path).then((n) {
      if (myToken != _token) return;
      _prev = n.prev;
      _next = n.next;
      notifyListeners();
    }).catchError((_) {/* nav buttons just stay disabled */});

    try {
      final base = baseServer(server);
      final off = offline;
      // TODO(ru): applyRu() overlay — Russian falls back to English until the
      // ru overlay assets are ported.
      final downloaded = await off?.isStoryDownloaded(server, path) ?? false;
      final data = off != null
          ? await off.getStoryData(server, path)
          : StoryData.fromJson(await getJson<Map<String, dynamic>>(
              base, '/gamedata/story/$path.json'));
      if (myToken != _token) return;

      var raw = data.storyList;
      if (altServer != 'none' && baseServer(altServer) != base) {
        try {
          final altData = StoryData.fromJson(
            await getJson<Map<String, dynamic>>(
                baseServer(altServer), '/gamedata/story/$path.json'),
          );
          raw = mergeAltStory(raw, altData.storyList);
        } catch (_) {
          // alt unavailable — show the base language alone
        }
      }
      if (myToken != _token) return;

      // Resolve every asset before showing the chapter, so portraits request a
      // working url first. A downloaded chapter already has its assets (and
      // resolved urls) on disk, so skip the network preload entirely — it would
      // just fail when offline.
      if (off != null) {
        if (downloaded) {
          _loadingPct = 100;
          notifyListeners();
        } else {
          final soundMap = await loadSoundMap();
          if (myToken != _token) return;
          await off.preloadStory(raw, soundMap, onProgress: (d, t) {
            if (myToken != _token || t == 0) return;
            final pct = (d * 100 / t).round();
            if (pct == _loadingPct) return;
            _loadingPct = pct;
            notifyListeners();
          });
        }
      }
      if (myToken != _token) return;
      setItems(normalizeStory(raw, doctorName), title: data.eventName ?? '');
    } catch (e) {
      if (myToken != _token) return;
      _error = '$e';
    } finally {
      if (myToken == _token) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _token++; // invalidate any in-flight load
    super.dispose();
  }
}
