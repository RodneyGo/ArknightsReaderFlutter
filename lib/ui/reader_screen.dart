// Novel-mode reader: the chapter as a scrolling transcript. Ported from the
// template half of BetterPhoneReader/src/views/StoryView.vue.
//
// The web version hand-rolled virtualization (@tanstack/vue-virtual) because a
// long chapter is thousands of DOM nodes. ListView.builder is lazy by
// construction, so that machinery is gone — but it also means we can't ask for a
// pixel offset of an unbuilt row, so "resume" and progress-saving work in item
// indices (which is what the store already persists).
//
// Not here yet: audio playback (sound rows render as passive chips), VN mode, and
// the offline/downloaded-asset path.

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/menu.dart';
import '../data/models.dart';
import '../data/offline.dart';
import '../data/source.dart';
import '../stores/progress_store.dart';
import '../stores/settings_store.dart';
import 'avatar.dart';
import 'css_color.dart';
import 'reader_audio.dart';
import 'reader_controller.dart';
import 'row_geometry.dart';
import 'settings_screen.dart';
import 'vn_reader.dart';

const _gold = Color(0xFFC8A96A);
const _ink = Color(0xFFF3F0E7);

/// What a vertical swipe on the VN scene wants the floating bar to do: `true` =
/// reveal (swipe down), `false` = hide (swipe up), `null` = too small to count.
/// A fast fling ([velocity]) or a deliberate slow drag ([netDy]) both qualify;
/// down is positive, matching Flutter's screen-space y-axis.
bool? barSwipeReveal(double netDy, double velocity) {
  if (netDy > 40 || velocity > 120) return true;
  if (netDy < -40 || velocity < -120) return false;
  return null;
}

class ReaderScreen extends StatefulWidget {
  final Story story;

  /// True when we arrived via prev/next: start at the top instead of offering to
  /// resume (you've just chosen to move to this chapter).
  final bool fresh;

  const ReaderScreen({super.key, required this.story, this.fresh = false});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

/// The scene behind the transcript: a background id, or a full-screen CG when
/// [img] is set.
typedef SceneRef = ({String id, bool img});

/// The scene for a set of visible row indices: the first one that actually
/// carries a scene. Skipping rows without one avoids blanking when the top row
/// is a gap, a sound chip, or a decision. Null when nothing on screen carries a
/// scene.
SceneRef? sceneForVisible(List<StoryItem> items, List<int> visible) {
  for (final i in visible) {
    if (i < 0 || i >= items.length) continue;
    final bg = items[i].bg;
    if (bg != null) return (id: bg, img: items[i].bgImage);
  }
  return null;
}

class _ReaderScreenState extends State<ReaderScreen> {
  late final ReaderController _controller;
  final _scroll = ScrollController();
  final _listKey = GlobalKey();

  /// Current scene. Separate from setState so scrolling past a scene change
  /// repaints the backdrop alone.
  final _scene = ValueNotifier<SceneRef?>(null);

  final _audio = ReaderAudio();

  /// PlayMusic rows of the current chapter, recomputed when the shown items
  /// change (a decision can add or hide branches).
  List<MusicRow> _musicRows = const [];

  final _vnKey = GlobalKey<VnReaderState>();

  /// Where VN mode should start. 0 unless the resume prompt is accepted, or the
  /// reader was toggled out of novel mode mid-chapter.
  int _vnResumeIndex = 0;

  /// Non-reactive read, for callbacks outside build.
  bool get _vnMode => _settings.state.readerMode == 'vn';
  String _lastMode = '';

  late SettingsStore _settings;
  String _loadedSig = '';

  bool _headerHidden = false;
  double _lastScroll = 0;
  int _lastSavedIndex = -1;

  /// Landscape only: whether the header is hidden. Driven by vertical swipes —
  /// swipe up to hide, swipe down to reveal — rather than a toggle button, since a
  /// full-width bar eats too much of a short viewport. Portrait uses the
  /// scroll-direction auto-hide instead.
  ///
  /// Seeded from [_rememberedBarCollapsed] so the choice carries across chapters
  /// (prev/next spins up a fresh screen).
  late bool _barCollapsed = _rememberedBarCollapsed;

  /// Last bar state, shared across reader instances so hiding it stays hidden
  /// when you move to the next chapter. Starts shown for discoverability on a
  /// fresh launch (it's in-memory, so app restart resets it).
  static bool _rememberedBarCollapsed = false;

  /// Orientation cached from the last build, so scroll/drag callbacks (which run
  /// without a BuildContext) know which hide mechanism applies.
  bool _landscape = false;

  /// Net vertical travel of an in-progress VN swipe, so a slow drag counts too
  /// (not just a fast fling).
  double _vnDragDy = 0;

  /// Saved index awaiting a resume decision; null = no prompt.
  int? _resumeAsk;

  String get _path => widget.story.txt;

  @override
  void initState() {
    super.initState();
    _controller = ReaderController(offline: context.read<Offline?>());
    _settings = context.read<SettingsStore>();
    _lastMode = _settings.state.readerMode;
    _settings.addListener(_onSettingsChanged);
    _scroll.addListener(_onScroll);
    _controller.addListener(_onItemsChanged);
    // Not awaited: the sound map only gates audio, and a chapter should render
    // (and be readable) whether or not it arrives.
    _audio.loadSoundMap();
    // Record the last-opened chapter before the fetch, so the guide's
    // return-to-episode centring is right even if you back out mid-load.
    // Deferred a frame: this notifies ProgressStore, and the guide rows we were
    // pushed over are listening — touching it now would dirty them mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ProgressStore>().setLast(_path, _settings.state.server);
    });
    _reload();
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    _controller.removeListener(_onItemsChanged);
    _scroll.dispose();
    _scene.dispose();
    _audio.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// A decision can hide or reveal branches, which shifts every later row —
  /// including the PlayMusic ones.
  void _onItemsChanged() {
    _musicRows = musicRowsOf(_controller.displayItems);
  }

  String _sigOf(SettingsState s) => '${s.server}|${s.altServer}|${s.doctorName}';

  void _onSettingsChanged() {
    if (_sigOf(_settings.state) != _loadedSig) {
      _reload();
      return;
    }
    final s = _settings.state;
    if (s.readerMode != _lastMode) {
      _onModeChanged(s.readerMode);
      return;
    }
    if (_vnMode) {
      // VN owns its own audio; only the volume knob applies from out here.
      if (!s.musicEnabled) _audio.stopMusic();
      _audio.setMusicVolume(s.musicVolume);
      return;
    }
    // Mirror the web's musicEnabled watcher: off stops the track, on picks the
    // one the current position calls for.
    if (!s.musicEnabled) {
      _audio.stopMusic();
    } else if (_audio.currentMusicId == null) {
      _updateAudio(_rowGeometry());
    } else {
      _audio.setMusicVolume(s.musicVolume);
    }
    if (!s.soundEnabled) _audio.stopAll();
  }

  /// Hand audio ownership between the two readers, and carry the reading
  /// position across so toggling mid-chapter doesn't lose your place.
  void _onModeChanged(String mode) {
    final wasNovel = _lastMode == 'novel';
    _lastMode = mode;
    if (mode == 'vn') {
      if (wasNovel) _vnResumeIndex = _lastSavedIndex.clamp(0, 1 << 30);
      // VnReader.init() stops the novel track and starts the one for its line.
    } else {
      _audio.stopAll();
      // Resync the novel track to wherever the list lands.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _updateAudio(_rowGeometry());
      });
    }
  }

  Future<void> _reload() async {
    final s = _settings.state;
    _loadedSig = _sigOf(s);
    // Plain assignment, not setState: _reload() runs from initState, and the
    // load() below notifies the Consumer anyway.
    _resumeAsk = null;
    _scene.value = null;
    _vnResumeIndex = 0;
    _audio.stopAll();
    _audio.resetAutoplay();
    await _controller.load(
      path: _path,
      server: s.server,
      altServer: s.altServer,
      doctorName: s.doctorName,
    );
    if (!mounted || _controller.error != null) return;
    context.read<ProgressStore>().markReading(_path);
    // Always begin at the top; if there's saved progress and we didn't arrive via
    // prev/next, offer to resume rather than silently jumping.
    final saved = widget.fresh ? 0 : context.read<ProgressStore>().getScroll(_path);
    _lastSavedIndex = 0;
    setState(() => _resumeAsk = saved > 0 ? saved : null);
    // Seed the opening scene + track: no scroll has happened yet, and the rows
    // only have geometry once this load's first frame is laid out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final geom = _rowGeometry();
      _updateScene(geom.visibleIndices);
      _updateAudio(geom);
    });
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final top = _scroll.offset;
    if ((top - _lastScroll).abs() > 12) {
      // Reading forward (offset growing) is an upward finger swipe -> hide;
      // scrolling back (a downward swipe) reveals it. Landscape drives the
      // swipe-controlled bar; portrait keeps its own auto-hide flag.
      final forward = top > _lastScroll;
      if (_landscape) {
        _setBarCollapsed(forward && top > 40);
      } else {
        setState(() => _headerHidden = forward && top > 80);
      }
      _lastScroll = top;
    }
    // Reaching the bottom marks the chapter finished; otherwise record how far
    // through it we've scrolled, for the guide's per-episode reading bar.
    final pos = _scroll.position;
    if (top >= pos.maxScrollExtent - 80 && _path.isNotEmpty) {
      context.read<ProgressStore>().markRead(_path);
    } else if (_path.isNotEmpty && pos.maxScrollExtent > 0) {
      context.read<ProgressStore>().savePercent(_path, top / pos.maxScrollExtent);
    }
    // One geometry pass feeds the resume position, the backdrop and the audio.
    final geom = _rowGeometry();
    _saveTopIndex(geom.visibleIndices);
    _updateScene(geom.visibleIndices);
    _updateAudio(geom);
  }

  /// Novel-mode audio only: in VN mode the reader drives audio off the timeline
  /// it's walking, and the two must not fight over the music player.
  void _updateAudio(RowGeometry geom) {
    if (_vnMode) return;
    final s = _settings.state;
    final items = _controller.displayItems;
    if (s.musicEnabled) {
      _audio.updateMusic(_musicRows, geom, s.musicVolume);
    }
    if (s.soundEnabled && s.soundAutoplay) {
      _audio.autoPlay(items, geom, s.soundVolume);
    }
  }

  /// Persist the topmost visible item index for resume.
  void _saveTopIndex(List<int> visible) {
    if (visible.isEmpty) return;
    final index = visible.first;
    if (index == _lastSavedIndex) return;
    _lastSavedIndex = index;
    context.read<ProgressStore>().saveScroll(_path, index);
  }

  /// Pushes the current scene through the notifier, so a scene change repaints
  /// only the backdrop rather than rebuilding the whole transcript.
  void _updateScene(List<int> visible) {
    final next = sceneForVisible(_controller.displayItems, visible);
    final cur = _scene.value;
    if (cur?.id == next?.id && cur?.img == next?.img) return;
    _scene.value = next;
  }

  /// Measure the built rows, in viewport-relative coordinates.
  ///
  /// ListView.builder has no "visible range" — and unlike the web version's
  /// virtualizer, unbuilt rows have no measured extent — so we read it off the
  /// built children's render objects. One pass per scroll notification serves
  /// every consumer.
  RowGeometry _rowGeometry() {
    final ctx = _listKey.currentContext;
    final box = ctx?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return RowGeometry.empty;
    final viewportTop = box.localToGlobal(Offset.zero).dy;

    final rows = <RowBox>[];
    void visit(Element el) {
      final widget = el.widget;
      if (widget is _IndexedRow) {
        final rb = el.findRenderObject();
        if (rb is RenderBox && rb.hasSize) {
          final top = rb.localToGlobal(Offset.zero).dy - viewportTop;
          rows.add((
            index: widget.index,
            top: top,
            bottom: top + rb.size.height,
          ));
        }
      }
      el.visitChildren(visit);
    }

    if (ctx is Element) ctx.visitChildren(visit);
    rows.sort((a, b) => a.index.compareTo(b.index));
    return RowGeometry(rows, box.size.height);
  }

  void _continueResume() {
    final index = _resumeAsk;
    setState(() => _resumeAsk = null);
    if (index == null) return;
    if (_vnMode) {
      _vnKey.currentState?.jumpTo(index);
    } else {
      _jumpToIndex(index);
    }
  }

  /// Jump to an item index. Rows are variable-height and unbuilt rows have no
  /// measured extent, so we approximate, then correct once the target is built.
  void _jumpToIndex(int index) {
    if (!_scroll.hasClients) return;
    final count = _controller.displayItems.length;
    if (count == 0) return;
    final frac = (index / count).clamp(0.0, 1.0);
    _scroll.jumpTo(_scroll.position.maxScrollExtent * frac);
    _lastSavedIndex = index;
  }

  void _goStory(Story? s) {
    if (s == null) return;
    // Replace, so Back returns to the chapter list rather than walking every
    // chapter visited via prev/next.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => ReaderScreen(story: s, fresh: true)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    _landscape = landscape;
    // Landscape back press: reveal the hidden bar first, and only exit the
    // chapter once it's already shown. Portrait exits straight away.
    final interceptBack = landscape && _barCollapsed;
    return PopScope(
      canPop: !interceptBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _setBarCollapsed(false);
      },
      child: ChangeNotifierProvider.value(
        value: _controller,
        child: Consumer<ReaderController>(
          builder: (context, c, _) {
            final showBg = context.select<SettingsStore, bool>(
                (s) => s.state.showBackground);
            final isVn = context
                .select<SettingsStore, bool>((s) => s.state.readerMode == 'vn');
            final ready = !c.loading && c.error == null;
            return Scaffold(
            backgroundColor: const Color(0xFF161618),
            body: Stack(
              children: [
                // VN mode paints its own scene behind the sprite.
                if (showBg && !isVn)
                  ValueListenableBuilder<SceneRef?>(
                    valueListenable: _scene,
                    builder: (_, scene, __) => scene == null
                        ? const SizedBox.shrink()
                        : _Backdrop(scene: scene),
                  ),
                Column(
                  children: [
                    // VN mode is a full-screen scene, so the bar floats over it
                    // rather than taking a band off the top.
                    if (!isVn) _bar(c, isVn, landscape),
                    Expanded(
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: isVn && ready
                                ? _vnArea(c, landscape)
                                : _body(c),
                          ),
                          if (isVn)
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              child: _bar(c, isVn, landscape),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_resumeAsk != null && ready)
                  _ResumePrompt(
                    onStart: () => setState(() => _resumeAsk = null),
                    onContinue: _continueResume,
                  ),
              ],
            ),
          );
          },
        ),
      ),
    );
  }

  Widget _vn(ReaderController c) => VnReader(
        key: _vnKey,
        items: c.displayItems,
        path: _path,
        prev: c.prev,
        next: c.next,
        audio: _audio,
        resumeIndex: _vnResumeIndex,
        onSelect: c.selectOption,
        onNavigate: _goStory,
      );

  /// The VN scene, wrapped in landscape with a vertical-swipe recognizer that
  /// shows/hides the floating bar. VnReader owns tap-to-advance and
  /// hold-to-peek; a vertical drag exceeds the touch slop those ignore, so the
  /// gesture arena hands it here without stealing taps.
  Widget _vnArea(ReaderController c, bool landscape) {
    if (!landscape) return _vn(c);
    return GestureDetector(
      onVerticalDragStart: (_) => _vnDragDy = 0,
      onVerticalDragUpdate: (d) => _vnDragDy += d.delta.dy,
      onVerticalDragEnd: _onVnDragEnd,
      child: _vn(c),
    );
  }

  void _onVnDragEnd(DragEndDetails d) {
    final reveal = barSwipeReveal(_vnDragDy, d.primaryVelocity ?? 0);
    if (reveal == null || reveal == !_barCollapsed) return;
    _setBarCollapsed(!reveal);
  }

  /// Set the bar's hidden state and remember it, so the choice carries to the
  /// next chapter's fresh screen.
  void _setBarCollapsed(bool v) {
    _rememberedBarCollapsed = v;
    if (_barCollapsed == v) return;
    setState(() => _barCollapsed = v);
  }

  Widget _bar(ReaderController c, bool isVn, bool landscape) {
    final isRead = context.watch<ProgressStore>().statusOf(_path) == ReadStatus.read;
    // Landscape hides on a vertical swipe; portrait uses the scroll-direction
    // auto-hide, which VN mode has no scrolling for.
    final hidden = landscape ? _barCollapsed : (_headerHidden && !isVn);
    return AnimatedSlide(
      offset: hidden ? const Offset(0, -1) : Offset.zero,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      child: Material(
        color: const Color(0xF0161618),
        elevation: 4,
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: 52,
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Back',
                  icon: const Icon(Icons.chevron_left, color: _ink),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                Expanded(
                  child: Text(
                    c.title.isNotEmpty ? c.title : widget.story.name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _ink, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                if (isVn)
                  IconButton(
                    tooltip: 'Log',
                    icon: const Icon(Icons.menu, color: _ink),
                    onPressed: () => _vnKey.currentState?.openLog(),
                  ),
                IconButton(
                  tooltip: isVn ? 'Novel mode' : 'Visual-novel mode',
                  icon: Icon(isVn ? Icons.notes : Icons.view_carousel_outlined,
                      color: _ink),
                  onPressed: () {
                    final store = context.read<SettingsStore>();
                    store.set(store.state
                        .copyWith(readerMode: isVn ? 'novel' : 'vn'));
                    setState(() => _headerHidden = false);
                  },
                ),
                IconButton(
                  tooltip: isRead ? 'Mark unread' : 'Mark read',
                  icon: Icon(Icons.check,
                      size: 20,
                      color: isRead ? const Color(0xFF5AA469) : Colors.white38),
                  onPressed: () =>
                      context.read<ProgressStore>().toggleRead(_path),
                ),
                IconButton(
                  tooltip: 'Settings',
                  icon: const Icon(Icons.settings_outlined, color: _ink),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(ReaderController c) {
    if (c.loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Loading ${c.loadingPct}%',
                style: const TextStyle(color: Color(0xFFBBBBBB), fontSize: 14)),
            const SizedBox(height: 12),
            SizedBox(
              width: 220,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: c.loadingPct / 100,
                  minHeight: 6,
                  backgroundColor: const Color(0xFF2C2B28),
                  valueColor: const AlwaysStoppedAnimation(_gold),
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (c.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Failed to load',
                  style: TextStyle(color: Color(0xFFE07A7A), fontSize: 16)),
              const SizedBox(height: 8),
              Text(c.error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white38, fontSize: 12)),
              const SizedBox(height: 16),
              TextButton(onPressed: _reload, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final items = c.displayItems;
    final fontSize = context.select<SettingsStore, int>((s) => s.state.fontSize);
    return ListView.builder(
      key: _listKey,
      controller: _scroll,
      // One extra row: the prev/next footer.
      itemCount: items.length + 1,
      itemBuilder: (context, i) {
        if (i == items.length) {
          return _ChapterNav(
            prev: c.prev,
            next: c.next,
            onGo: _goStory,
          );
        }
        return _IndexedRow(
          index: i,
          child: StoryRow(
            item: items[i],
            fontSize: fontSize.toDouble(),
            selections: c.selections,
            onSelect: c.selectOption,
            audio: _audio,
          ),
        );
      },
    );
  }
}

/// Tags a built row with its index so [_ReaderScreenState._firstVisibleIndex] can
/// find the topmost visible one for resume.
class _IndexedRow extends StatelessWidget {
  final int index;
  final Widget child;
  const _IndexedRow({required this.index, required this.child});

  @override
  Widget build(BuildContext context) => child;
}

/// One normalized story item. Public so the VN reader can reuse the text styling.
class StoryRow extends StatelessWidget {
  final StoryItem item;
  final double fontSize;
  final Map<int, String> selections;
  final void Function(int group, String value) onSelect;
  final ReaderAudio audio;

  const StoryRow({
    super.key,
    required this.item,
    required this.fontSize,
    required this.selections,
    required this.onSelect,
    required this.audio,
  });

  @override
  Widget build(BuildContext context) {
    final it = item;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: switch (it) {
        DialogItem() => _dialog(it),
        NarrationItem() => _narration(it),
        SubtitleItem() => _subtitle(it),
        DecisionItem() => _decision(it),
        SoundItem() => _sound(context, it),
        SceneBreakItem() => _sceneBreak(),
      },
    );
  }

  Widget _dialog(DialogItem it) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Avatar(portrait: it.portrait),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (it.name.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    it.name,
                    style: TextStyle(
                      color: const Color(0xFFD8B878),
                      fontSize: fontSize * 0.8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: it.alt ? const Color(0x8C161618) : const Color(0xCC161618),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: RunText(
                      runs: it.runs,
                      style: TextStyle(
                        color: it.alt ? const Color(0xFF9A9A9A) : _ink,
                        fontSize: fontSize,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _narration(NarrationItem it) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: RunText(
          runs: it.runs,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: it.alt ? const Color(0xFF9A9A9A) : const Color(0xFFE6E2D6),
            fontSize: fontSize,
            height: 1.5,
            fontStyle: FontStyle.italic,
            shadows: const [
              Shadow(color: Colors.black, offset: Offset(0, 1), blurRadius: 3),
            ],
          ),
        ),
      );

  Widget _subtitle(SubtitleItem it) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: RunText(
          runs: it.runs,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            height: 1.5,
            fontWeight: FontWeight.w600,
            shadows: const [
              Shadow(color: Colors.black, offset: Offset(0, 1), blurRadius: 3),
            ],
          ),
        ),
      );

  Widget _decision(DecisionItem it) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            'CHOICE',
            style: TextStyle(
              color: Colors.white60,
              fontSize: fontSize * 0.7,
              letterSpacing: 1.6,
            ),
          ),
        ),
        for (var i = 0; i < it.options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _ChoiceButton(
              label: it.options[i],
              selected: selections[it.group] == it.values[i],
              fontSize: fontSize * 0.95,
              onTap: () => onSelect(it.group, it.values[i]),
            ),
          ),
      ],
    );
  }

  /// Music rows are a passive now-playing chip (the track switches itself as you
  /// scroll); SFX rows are tap-to-play.
  Widget _sound(BuildContext context, SoundItem it) {
    final settings = context.watch<SettingsStore>().state;
    if (!it.music && !settings.soundEnabled) return const SizedBox.shrink();

    final label = it.key.startsWith('\$') ? it.key.substring(1) : it.key;
    return Center(
      child: AnimatedBuilder(
        animation: audio,
        builder: (context, _) {
          final playing = it.music
              ? audio.currentMusicId == it.id
              : audio.playingSfxId == it.id;
          final chip = Container(
            decoration: BoxDecoration(
              color: const Color(0xD9222224),
              border: Border.all(
                color: playing
                    ? _gold
                    : it.music
                        ? const Color(0x996A8FC8)
                        : const Color(0x99555555),
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(it.music ? '♪' : '▶',
                    style: TextStyle(color: _gold, fontSize: fontSize * 0.78)),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: playing ? _ink : const Color(0xFFBDBDBD),
                    fontSize: fontSize * 0.78,
                  ),
                ),
              ],
            ),
          );
          if (it.music) return chip;
          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => audio.playSfx(it, settings.soundVolume),
            child: chip,
          );
        },
      ),
    );
  }

  Widget _sceneBreak() => Center(
        child: Container(
          height: 26,
          width: 140,
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0x2EC8A96A)),
            ),
          ),
        ),
      );
}

/// Renders styled [TextRun]s, mapping each run's CSS colour onto the base style.
class RunText extends StatelessWidget {
  final List<TextRun> runs;
  final TextStyle style;
  final TextAlign textAlign;

  const RunText({
    super.key,
    required this.runs,
    required this.style,
    this.textAlign = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          for (final r in runs)
            TextSpan(
              text: r.text,
              style: r.color == null
                  ? null
                  : TextStyle(color: cssColor(r.color) ?? style.color),
            ),
        ],
      ),
      textAlign: textAlign,
      style: style,
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  final String label;
  final bool selected;
  final double fontSize;
  final VoidCallback onTap;

  const _ChoiceButton({
    required this.label,
    required this.selected,
    required this.fontSize,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.9),
      child: Material(
        color: selected ? _gold : const Color(0xEB464034),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
              color: selected ? _gold : const Color(0x66C8A96A)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? const Color(0xFF1B1A18) : _ink,
                fontSize: fontSize,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChapterNav extends StatelessWidget {
  final Story? prev;
  final Story? next;
  final void Function(Story?) onGo;
  const _ChapterNav({required this.prev, required this.next, required this.onGo});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          14, 18, 14, 18 + MediaQuery.paddingOf(context).bottom),
      child: Row(
        children: [
          Expanded(
            child: _NavButton(
              label: '‹ Previous',
              onTap: prev == null ? null : () => onGo(prev),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _NavButton(
              label: 'Next ›',
              onTap: next == null ? null : () => onGo(next),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const _NavButton({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.3 : 1,
      child: Material(
        color: const Color(0xE6222224),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFF555555)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: _ink, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}

/// Scene backdrop: the full uncropped art, over a blurred copy that fills the
/// letterbox gaps.
///
/// The blur here is an [ImageFiltered] over a *static* image inside a
/// [RepaintBoundary] — it rasterizes once per scene change and is then cached.
/// That's the opposite of a BackdropFilter, which re-samples the live scene every
/// frame and is what tanked the menu's frame rate.
class _Backdrop extends StatefulWidget {
  final SceneRef scene;
  const _Backdrop({required this.scene});

  @override
  State<_Backdrop> createState() => _BackdropState();
}

class _BackdropState extends State<_Backdrop> {
  /// Scene art lives under one of two url shapes; fall back on the first 404.
  bool _fallback = false;

  @override
  void didUpdateWidget(_Backdrop old) {
    super.didUpdateWidget(old);
    if (old.scene.id != widget.scene.id) _fallback = false;
  }

  @override
  Widget build(BuildContext context) {
    final srcs = sceneSrcs(widget.scene.id, isImage: widget.scene.img);
    final url = _fallback ? srcs[1] : srcs[0];

    return Positioned.fill(
      child: RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          children: [
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
              child: Transform.scale(
                scale: 1.1,
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  color: Colors.black.withValues(alpha: 0.5),
                  colorBlendMode: BlendMode.darken,
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) {
                    if (!_fallback) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) setState(() => _fallback = true);
                      });
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
            Opacity(
              opacity: 0.5,
              child: Image.network(
                url,
                fit: BoxFit.contain,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResumePrompt extends StatelessWidget {
  final VoidCallback onStart;
  final VoidCallback onContinue;
  const _ResumePrompt({required this.onStart, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0x8C000000),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 360),
              decoration: BoxDecoration(
                color: const Color(0xFF1F1F22),
                border: Border.all(color: const Color(0xFF3A3A3E)),
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'You have saved progress in this chapter.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _ink, fontSize: 15, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _NavButton(label: 'Start over', onTap: onStart),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Material(
                          color: _gold,
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: onContinue,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                'Continue',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFF1B1A18),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
