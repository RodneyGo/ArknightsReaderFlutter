// Main-menu screen state: fetches the chapter menu, builds the main menu, and
// tracks the selected storyline / arc / focused episode. A ChangeNotifier so the
// screen rebuilds on change; the menu fetch is injectable so tests don't hit the
// network.

import 'package:flutter/foundation.dart';

import '../data/main_menu.dart';
import '../data/menu.dart';

class MainMenuController extends ChangeNotifier {
  final Future<Menu> Function(String server) _fetchMenu;
  final Future<Menu?> Function(String server) _refreshMenu;

  MainMenuController({
    Future<Menu> Function(String server)? fetchMenu,
    Future<Menu?> Function(String server)? refreshMenu,
  })  : _fetchMenu = fetchMenu ?? getMenu,
        _refreshMenu = refreshMenu ?? refreshMenu_;

  /// Default background revalidator (tear-off wrapper so the field can name it).
  static Future<Menu?> refreshMenu_(String server) => refreshMenu(server);

  MainMenu? _mainMenu;
  Object? _error;
  bool _loading = false;
  int _storyline = 0; // 0 = Main Story; else sideStorylines[_storyline - 1]
  int _arc = 0; // active main-story arc (only when Main Story is selected)
  int _focused = 0; // focused episode within the current node list

  MainMenu? get mainMenu => _mainMenu;
  Object? get error => _error;
  bool get loading => _loading;
  int get storylineIndex => _storyline;
  int get arcIndex => _arc;
  int get focusedIndex => _focused;
  bool get isMainStory => _storyline == 0;
  int get arcCount => _mainMenu?.mainArcs.length ?? 0;

  Future<void> load(String server) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      // Cache-first: this returns instantly from disk when available, so the
      // main menu renders offline; the network revalidation runs behind it.
      final menu = await _fetchMenu(server);
      _mainMenu = buildMainMenu(menu.categories);
    } catch (e) {
      _error = e;
    } finally {
      _loading = false;
      notifyListeners();
    }
    if (_error == null) _revalidate(server);
  }

  /// Fire-and-forget network refresh. Rebuilds only when new episodes appeared;
  /// a network failure is silent, since the cached list is already showing.
  Future<void> _revalidate(String server) async {
    try {
      final fresh = await _refreshMenu(server);
      if (fresh == null) return; // nothing new
      _mainMenu = buildMainMenu(fresh.categories);
      notifyListeners();
    } catch (_) {
      // offline / transient — keep the rendered cache
    }
  }

  @visibleForTesting
  void setMainMenu(MainMenu g) {
    _mainMenu = g;
    _error = null;
    _loading = false;
    notifyListeners();
  }

  /// Bottom-selector labels: one "Main Story" item + each side storyline.
  List<String> get selectorLabels {
    final g = _mainMenu;
    if (g == null) return const [];
    return ['Main Story', for (final s in g.sideStorylines) s.name];
  }

  List<EpisodeNode> get currentNodes {
    final g = _mainMenu;
    if (g == null) return const [];
    if (_storyline == 0) {
      if (g.mainArcs.isEmpty) return const [];
      return g.mainArcs[_arc.clamp(0, g.mainArcs.length - 1)].nodes;
    }
    return g.sideStorylines[_storyline - 1].nodes;
  }

  EpisodeNode? get focusedNode {
    final nodes = currentNodes;
    if (nodes.isEmpty) return null;
    return nodes[_focused.clamp(0, nodes.length - 1)];
  }

  void selectStoryline(int i) {
    if (i == _storyline) return;
    _storyline = i;
    _arc = 0;
    _focused = 0;
    notifyListeners();
  }

  void selectArc(int i) {
    if (i == _arc) return;
    _arc = i;
    _focused = 0;
    notifyListeners();
  }

  void setFocused(int i) {
    if (i == _focused) return;
    _focused = i;
    notifyListeners();
  }
}
