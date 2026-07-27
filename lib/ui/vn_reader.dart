// Visual-novel mode: one line at a time over a scene, with a character sprite,
// a typewriter, tap-to-advance and press-and-hold-to-peek. Ported from
// BetterPhoneReader/src/components/VnReader.vue.
//
// The stepping/log/typewriter rules live in vn_timeline.dart (pure, tested);
// this is the widget around them.

import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';

import '../data/menu.dart';
import '../data/i18n.dart';
import '../data/models.dart';
import '../data/offline.dart';
import '../data/resolved.dart';
import '../data/source.dart';
import '../stores/progress_store.dart';
import '../stores/settings_store.dart';
import 'css_color.dart';
import 'local_image.dart';
import 'reader_audio.dart';
import 'vn_sprites.dart';
import 'vn_timeline.dart';

const _gold = Color(0xFFD8B878);
const _ink = Color(0xFFF3F0E7);

/// How long a press must be held before the UI hides to reveal the scene. The
/// web used 240ms; Flutter's default long-press is 500ms, so the recognizer is
/// built by hand to keep the feel.
const _holdDuration = Duration(milliseconds: 240);

class VnReader extends StatefulWidget {
  final List<StoryItem> items;
  final String path;
  final Story? prev;
  final Story? next;
  final ReaderAudio audio;
  final int resumeIndex;
  final void Function(int group, String value) onSelect;
  final void Function(Story) onNavigate;

  const VnReader({
    super.key,
    required this.items,
    required this.path,
    required this.prev,
    required this.next,
    required this.audio,
    required this.resumeIndex,
    required this.onSelect,
    required this.onNavigate,
  });

  @override
  State<VnReader> createState() => VnReaderState();
}

class VnReaderState extends State<VnReader> {
  int _index = 0;
  bool _atEnd = false;
  bool _peeking = false;
  bool _logOpen = false;

  // typewriter
  List<TextRun> _fullRuns = const [];
  int _shown = 0;
  bool _typing = false;
  Timer? _typer;

  late SpriteResolver _sprites;
  bool _bgFallback = false;
  String? _lastBgId;

  StoryItem? get _current =>
      _index >= 0 && _index < widget.items.length ? widget.items[_index] : null;
  bool get _isDecision => _current is DecisionItem;

  SettingsState get _settings => context.read<SettingsStore>().state;

  @override
  void initState() {
    super.initState();
    _sprites =
        SpriteResolver(context.read<ResolvedUrls>(), context.read<Offline?>());
    _sprites.addListener(_onSpritesChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _init();
    });
  }

  @override
  void didUpdateWidget(VnReader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _init();
    } else if (!identical(oldWidget.items, widget.items)) {
      // A decision was answered: the shown list changed under us.
      _warmSprites();
    }
  }

  @override
  void dispose() {
    _typer?.cancel();
    _sprites.removeListener(_onSpritesChanged);
    _sprites.dispose();
    super.dispose();
  }

  void _onSpritesChanged() {
    if (mounted) setState(() {});
  }

  void _setPeeking(bool v) {
    if (_peeking != v) setState(() => _peeking = v);
  }

  void _init() {
    widget.audio.stopAll();
    _atEnd = false;
    context.read<ProgressStore>().markReading(widget.path);
    _warmSprites();
    final saved =
        widget.resumeIndex.clamp(0, widget.items.isEmpty ? 0 : widget.items.length - 1);
    // Resume the track that was playing here: the forward walk only fires music
    // commands it steps through, and resuming lands past them.
    _syncMusicTo(saved);
    _goTo(saved);
  }

  void _warmSprites() {
    final portraits = <String>{
      for (final it in widget.items)
        if (it is DialogItem) ...[
          if (it.portrait?.isNotEmpty ?? false) it.portrait!,
          for (final sp in it.stage)
            if (sp.id.isNotEmpty) sp.id,
        ],
    };
    _sprites.warmAll(portraits, context);
  }

  void _syncMusicTo(int index) {
    final s = _settings;
    if (!s.musicEnabled) return;
    final key = activeMusicKeyAt(widget.items, index);
    if (key != null) {
      widget.audio.playMusicKey(key, s.musicVolume);
    } else {
      widget.audio.stopMusic();
    }
  }

  /// Step to the next renderable item, firing the sounds passed on the way.
  void _goTo(int from) {
    final walk = walkToVisible(widget.items, from);
    final s = _settings;
    for (final snd in walk.sounds) {
      if (snd.music) {
        if (s.musicEnabled) widget.audio.playMusicKey(snd.key, s.musicVolume);
      } else {
        if (s.soundEnabled) widget.audio.playSfxKey(snd.key, s.soundVolume);
      }
    }
    if (walk.index >= widget.items.length) {
      _typer?.cancel();
      context.read<ProgressStore>().markRead(widget.path);
      setState(() {
        _atEnd = true;
        _typing = false;
      });
      return;
    }
    final progress = context.read<ProgressStore>();
    progress.saveScroll(widget.path, walk.index);
    progress.savePercent(widget.path, _fractionAt(walk.index));
    setState(() {
      _atEnd = false;
      _index = walk.index;
    });
    _startLine();
  }

  /// How far through the chapter a line index is, for the main menu's reading bar.
  double _fractionAt(int index) {
    final last = widget.items.length - 1;
    return last <= 0 ? 0 : index / last;
  }

  void _startLine() {
    _typer?.cancel();
    _fullRuns = switch (_current) {
      DialogItem(:final runs) => runs,
      NarrationItem(:final runs) => runs,
      SubtitleItem(:final runs) => runs,
      _ => const [],
    };
    final total = _fullRuns.fold<int>(0, (n, r) => n + r.text.length);
    final ms = vnTypeSpeedMs(_settings.textSpeed);
    if (_isDecision || ms == 0) {
      setState(() {
        _shown = total;
        _typing = false;
      });
      return;
    }
    setState(() {
      _shown = 0;
      _typing = true;
    });
    _typer = Timer.periodic(Duration(milliseconds: ms), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _shown++;
        if (_shown >= total) {
          _typing = false;
          t.cancel();
        }
      });
    });
  }

  void _finishTyping() {
    _typer?.cancel();
    setState(() {
      _shown = _fullRuns.fold<int>(0, (n, r) => n + r.text.length);
      _typing = false;
    });
  }

  void _advance() {
    if (_atEnd || _isDecision) return;
    if (_typing) {
      _finishTyping();
    } else {
      _goTo(_index + 1);
    }
  }

  void _choose(int group, String value) {
    widget.onSelect(group, value);
    // The items list is rebuilt with the branch applied; step past the decision
    // once that has landed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _goTo(_index + 1);
    });
  }

  // --- exposed to ReaderScreen (via GlobalKey), mirroring the web defineExpose ---

  void openLog() {
    setState(() => _logOpen = true);
  }

  /// Jump to a line: from the backlog, or when the resume prompt is accepted.
  void jumpTo(int index) {
    _logOpen = false;
    _atEnd = false;
    _index = index;
    // A jump skips the forward walk, so resync the track by scanning backward.
    _syncMusicTo(index);
    final progress = context.read<ProgressStore>();
    progress.saveScroll(widget.path, index);
    progress.savePercent(widget.path, _fractionAt(index));
    _startLine();
  }

  // --- rendering ---

  String? get _bgId {
    if (!_settings.showBackground) return null;
    return _current?.bg;
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild on settings changes (text speed, background toggle).
    context.watch<SettingsStore>();
    final bgId = _bgId;
    if (bgId != _lastBgId) {
      _lastBgId = bgId;
      _bgFallback = false;
    }

    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: {
        TapGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
          () => TapGestureRecognizer(),
          (r) => r.onTap = _advance,
        ),
        // Hand-built so the hold threshold matches the web's 240ms. Winning the
        // arena also means the tap never fires after a hold — the web tracked
        // that by hand with a `peeked` flag.
        LongPressGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
          () => LongPressGestureRecognizer(duration: _holdDuration),
          (r) {
            r.onLongPressStart = (_) => _setPeeking(true);
            r.onLongPressEnd = (_) => _setPeeking(false);
            r.onLongPressCancel = () => _setPeeking(false);
          },
        ),
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0xFF0E0E10)),
          if (bgId != null) _background(bgId),
          _sprite(),
          if (_atEnd)
            _endCard()
          else if (_isDecision)
            _choices(_current as DecisionItem)
          else
            _dialogueBox(),
          if (_logOpen) _log(),
        ],
      ),
    );
  }

  Widget _background(String id) {
    final srcs = sceneSrcs(id, isImage: _current?.bgImage ?? false);
    final url = _bgFallback ? srcs[1] : srcs[0];
    // Landscape crops the scene to fill the wide screen (no letterbox bars);
    // holding to peek switches back to the whole, uncropped image. Portrait
    // always shows the full image.
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final mainFit =
        landscape && !_peeking ? BoxFit.cover : BoxFit.contain;
    final img = readerImage(url, context.read<Offline?>());
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Blurred copy fills the letterbox gaps. Static image + RepaintBoundary,
          // so this rasterizes once per scene rather than every frame.
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
            child: Image(
              image: img,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              color: Colors.black.withValues(alpha: 0.55),
              colorBlendMode: BlendMode.darken,
              errorBuilder: (_, __, ___) {
                if (!_bgFallback) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _bgFallback = true);
                  });
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          Image(
            image: img,
            fit: mainFit,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _sprite() {
    final it = _current;
    final stage = it is DialogItem ? it.stage : const <StagePortrait>[];

    // Resolve every on-stage portrait; drop the ones that haven't loaded yet.
    // Keep the slot index so the horizontal placement stays left-to-right.
    final shown = <({int slot, bool active, String id, String url})>[];
    for (var i = 0; i < stage.length; i++) {
      final sp = stage[i];
      if (sp.id.isEmpty) continue;
      final url = _sprites.urlFor(sp.id);
      if (url == null) continue;
      shown.add((slot: i, active: sp.active, id: sp.id, url: url));
    }
    // Fallback for items with no stage (older data / direct construction): use
    // the single active portrait so nothing regresses.
    if (shown.isEmpty && it is DialogItem && (it.portrait?.isNotEmpty ?? false)) {
      final url = _sprites.urlFor(it.portrait!);
      if (url != null) {
        shown.add((slot: 0, active: true, id: it.portrait!, url: url));
      }
    }

    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    // The multi-character stage (both figures, non-speaker dimmed) is a
    // landscape-only feature — portrait is too narrow for two. Collapse to just
    // the speaking sprite there, matching the old single-portrait behaviour.
    if (!landscape && shown.length > 1) {
      final active =
          shown.firstWhere((s) => s.active, orElse: () => shown.first);
      shown
        ..clear()
        ..add(active);
    }

    // Hidden on narration, decisions, the end card, or once everyone has left
    // the stage — rather than leaving the previous character lingering.
    final show = !_atEnd && !_isDecision && !_peeking && shown.isNotEmpty;

    final n = shown.length;
    // Spread the cast horizontally: one stays centred; two flank the middle;
    // three-plus fan out evenly. Slot index (not draw order) drives position.
    double xFor(int slot) {
      if (n <= 1) return 0;
      final t = slot / (n - 1); // 0..1 across the placed characters
      final spread = n == 2 ? 0.58 : 0.82;
      return (t * 2 - 1) * spread;
    }

    // Draw the dimmed (non-speaking) characters first so the speaker sits in
    // front of them.
    shown.sort((a, b) {
      if (a.active != b.active) return a.active ? 1 : -1;
      return a.slot.compareTo(b.slot);
    });

    // Key the crossfade on the *set* of characters on stage (base ids), not on
    // focus or expression. So a character walking on/off fades, while a focus
    // flip or an expression change updates in place. Sort the key so the same
    // cast in a different draw order still counts as unchanged.
    final setKey = (shown.map((s) => portraitBaseId(s.id)).toList()..sort())
        .join('|');

    final child = show
        ? Stack(
            key: ValueKey(setKey),
            alignment: Alignment.bottomCenter,
            children: [
              for (final s in shown)
                Align(
                  alignment: Alignment(xFor(s.slot), 1),
                  // Grow the sprite 15% about its bottom edge: the feet stay
                  // pinned where they are, and the character gets taller/wider
                  // (grows up, left, and right). Portrait only — landscape keeps
                  // its original size.
                  child: Transform.scale(
                    scale: landscape ? 1.0 : 1.15,
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      // Narrower in landscape, and narrower still when several
                      // characters share the stage, so they don't overlap heavily.
                      widthFactor: n <= 1
                          ? (landscape ? 0.42 : 0.96)
                          : (landscape ? 0.4 : 0.66),
                      child: _stageSprite(s.url, s.active),
                    ),
                  ),
                ),
            ],
          )
        : const SizedBox.shrink();

    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      // Landscape viewports are short: anchor the sprite to the very bottom so
      // the character stands on it (feet behind the dialogue box — the usual VN
      // look) instead of floating above a box that would eat a third of the
      // screen. Portrait keeps it clear of the taller box.
      bottom: landscape ? 0 : 128,
      child: IgnorePointer(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 140),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          // Keep the outgoing and incoming sprites both pinned to the bottom
          // centre during a fade, instead of the default centred stack.
          layoutBuilder: (currentChild, previousChildren) => Stack(
            alignment: Alignment.bottomCenter,
            children: [
              ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  /// One character on the stage. The non-speaking cast is pushed into shadow —
  /// darkened and slightly faded — the way the game dims whoever isn't the
  /// current `focus`, so the eye lands on the speaker.
  Widget _stageSprite(String url, bool active) {
    Widget img = Image(
      image: readerImage(url, context.read<Offline?>()),
      fit: BoxFit.contain,
      alignment: Alignment.bottomCenter,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
    if (!active) {
      img = ColorFiltered(
        colorFilter: const ColorFilter.mode(
          Color(0x730A0A0C), // ~45% black, painted only over the sprite
          BlendMode.srcATop,
        ),
        child: img,
      );
    }
    // Animate the fade so a focus flip eases between lit and dim in place.
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: active ? 1.0 : 0.9,
      child: img,
    );
  }

  Widget _dialogueBox() {
    final it = _current;
    final speaker = it is DialogItem ? it.name : '';
    final isNarration = it is NarrationItem || it is SubtitleItem;
    final runs = truncateRuns(_fullRuns, _shown);
    // Landscape: shrink the box — 130px is about a third of a short viewport.
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    // Story text tracks the font-size setting; landscape trims 2pt to fit the
    // shorter box. Defaults reproduce the old 18/16.
    final base = _settings.fontSize.toDouble();
    final bodySize = landscape ? base : base + 2;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: AnimatedOpacity(
        opacity: _peeking ? 0 : 1,
        duration: const Duration(milliseconds: 180),
        child: Container(
          constraints: BoxConstraints(minHeight: landscape ? 56 : 130),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Color(0xF50A0A0C), Color(0x000A0A0C)],
              stops: [0.62, 1.0],
            ),
          ),
          padding: EdgeInsets.fromLTRB(
            18,
            landscape ? 10 : 16,
            18,
            (landscape ? 12 : 20) + MediaQuery.paddingOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: isNarration
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (speaker.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(bottom: landscape ? 3 : 6),
                  child: Text(
                    speaker,
                    style: TextStyle(
                        color: _gold,
                        fontSize: base - 1,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              Text.rich(
                TextSpan(children: [
                  for (final r in runs)
                    TextSpan(
                      text: r.text,
                      style: r.color == null
                          ? null
                          : TextStyle(color: cssColor(r.color) ?? _ink),
                    ),
                  if (_typing)
                    const TextSpan(
                        text: '▍', style: TextStyle(color: _gold)),
                ]),
                textAlign: isNarration ? TextAlign.center : TextAlign.start,
                style: TextStyle(
                  color: _ink,
                  fontSize: bodySize,
                  height: landscape ? 1.4 : 1.55,
                  fontStyle: isNarration ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _choices(DecisionItem it) {
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0x8C0A0A0C),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var k = 0; k < it.options.length; k++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Material(
                        color: const Color(0xF22D2A26),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0x88C8A96A)),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _choose(it.group, it.values[k]),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 14),
                            child: Text(
                              it.options[k],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: _ink,
                                  fontSize: _settings.fontSize.toDouble()),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _endCard() {
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0xB30A0A0C),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.l('theEnd'),
                  style: const TextStyle(color: _ink, fontSize: 18)),
              const SizedBox(height: 20),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _EndNav(
                    label: context.l('previous'),
                    onTap: widget.prev == null
                        ? null
                        : () => widget.onNavigate(widget.prev!),
                  ),
                  const SizedBox(width: 12),
                  _EndNav(
                    label: context.l('next'),
                    onTap: widget.next == null
                        ? null
                        : () => widget.onNavigate(widget.next!),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _log() => VnLog(
        entries: vnLog(widget.items),
        currentIndex: _index,
        onJump: (i) => setState(() => jumpTo(i)),
        onClose: () => setState(() => _logOpen = false),
      );
}

class _EndNav extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const _EndNav({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: onTap == null ? 0.3 : 1,
        child: Material(
          color: const Color(0xF2222224),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Color(0xFF555555)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Text(label,
                  style: const TextStyle(
                      color: _ink, fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      );
}

/// The backlog. Shows the whole chapter (so you can jump forward too) with the
/// current line highlighted, scrolled to it on open.
class VnLog extends StatefulWidget {
  final List<VnLogEntry> entries;
  final int currentIndex;
  final void Function(int index) onJump;
  final VoidCallback onClose;

  const VnLog({
    super.key,
    required this.entries,
    required this.currentIndex,
    required this.onJump,
    required this.onClose,
  });

  @override
  State<VnLog> createState() => _VnLogState();
}

class _VnLogState extends State<VnLog> {
  final _scroll = ScrollController();
  final _currentKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Rows are variable-height, so approximate by index first, then centre
  /// precisely once the current row is actually built.
  void _scrollToCurrent() {
    if (!mounted || !_scroll.hasClients || widget.entries.isEmpty) return;
    final at = widget.entries.indexWhere((e) => e.index >= widget.currentIndex);
    if (at < 0) return;
    final frac = at / widget.entries.length;
    _scroll.jumpTo(_scroll.position.maxScrollExtent * frac);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _currentKey.currentContext;
      if (ctx != null) Scrollable.ensureVisible(ctx, alignment: 0.5);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Swallow taps so they don't advance the story underneath.
    return Positioned.fill(
      child: GestureDetector(
        onTap: () {},
        child: ColoredBox(
          color: const Color(0xF70C0C0E),
          child: SafeArea(
            child: Column(
              children: [
                Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Text(context.l('log'),
                          style: const TextStyle(
                              color: _ink, fontWeight: FontWeight.w700)),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: context.l('closeLog'),
                      icon: const Icon(Icons.close, color: _ink),
                      onPressed: widget.onClose,
                    ),
                  ],
                ),
                const Divider(height: 1, color: Color(0xFF2C2B28)),
                Expanded(
                  child: ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: widget.entries.length,
                    itemBuilder: (context, i) {
                      final e = widget.entries[i];
                      final isCurrent = e.index == widget.currentIndex;
                      return InkWell(
                        key: isCurrent ? _currentKey : null,
                        onTap: () => widget.onJump(e.index),
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? const Color(0x29C8A96A)
                                : Colors.transparent,
                            border: Border(
                              bottom:
                                  const BorderSide(color: Color(0xFF232220)),
                              left: BorderSide(
                                color: isCurrent ? _gold : Colors.transparent,
                                width: 3,
                              ),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (e.name.isNotEmpty)
                                Text(e.name,
                                    style: const TextStyle(
                                        color: _gold,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700)),
                              Text(e.text,
                                  style: const TextStyle(
                                      color: Color(0xFFE6E2D6), fontSize: 14)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
