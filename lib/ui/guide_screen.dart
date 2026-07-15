// The reading-guide hub — the app's landing screen (the "main menu"). Backdrop
// (focused episode's background) + ambient embers, a vertical snap-scroller of
// episode cards (Flutter PageView gives the snap + focus-scaling for free), an
// arc rail for Main Story, and a bottom storyline selector.
//
// Tapping a card (chapter drill-down) + notes + downloads come next.

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/backgrounds.dart';
import '../data/chapter_images.dart';
import '../data/guide.dart';
import '../data/menu.dart';
import '../stores/progress_store.dart';
import '../stores/settings_store.dart';
import 'ash_fx.dart';
import 'guide_controller.dart';
import 'settings_screen.dart';

Color _statusColor(ReadStatus s) => switch (s) {
      ReadStatus.read => const Color(0xFF5AA469),
      ReadStatus.reading => _gold,
      ReadStatus.unread => Colors.white24,
    };

const _roman = ['I', 'II', 'III', 'IV', 'V', 'VI'];
const _gold = Color(0xFFE8C987);

// Approximate heights of the frosted header pieces, so the scroller can reserve
// space for the focused card below the header while cards still scroll up behind
// it (the header overlays the scroller).
const _topBarHeight = 54.0;
const _arcRailHeight = 46.0;
const _headerBottomPad = 20.0;

/// Snap-to-item physics that preserves fling momentum: a fling carries across
/// several items (using the parent's friction) and then settles on the nearest
/// item — unlike PageView, which advances only one page per swipe.
class _SnapScrollPhysics extends ScrollPhysics {
  final double itemExtent;
  const _SnapScrollPhysics({required this.itemExtent, super.parent});

  @override
  _SnapScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      _SnapScrollPhysics(itemExtent: itemExtent, parent: buildParent(ancestor));

  double _snapTarget(ScrollMetrics position, double velocity) {
    // Where a normal fling would land, then round to the nearest item.
    final sim = super.createBallisticSimulation(position, velocity);
    var natural = sim != null ? sim.x(double.infinity) : position.pixels;
    if (natural.isNaN) natural = position.pixels;
    natural = natural.clamp(position.minScrollExtent, position.maxScrollExtent);
    final snapped = (natural / itemExtent).roundToDouble() * itemExtent;
    return snapped.clamp(position.minScrollExtent, position.maxScrollExtent);
  }

  @override
  Simulation? createBallisticSimulation(
      ScrollMetrics position, double velocity) {
    final tolerance = toleranceFor(position);
    final target = _snapTarget(position, velocity);
    if ((target - position.pixels).abs() < tolerance.distance &&
        velocity.abs() < tolerance.velocity) {
      return null;
    }
    return ScrollSpringSimulation(spring, position.pixels, target, velocity,
        tolerance: tolerance);
  }

  @override
  bool get allowImplicitScrolling => false;
}

class GuideScreen extends StatefulWidget {
  const GuideScreen({super.key});

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  final _scroll = ScrollController();
  EpisodeNode? _openEpisode; // chapter drill-down target (null = closed)
  bool _notesVisible = false;
  bool _lightbox = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _resetToTop() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _open(EpisodeNode n) {
    if (n.event == null) return; // IS nodes have no chapters
    setState(() => _openEpisode = n);
  }

  void _close() {
    if (_openEpisode != null) setState(() => _openEpisode = null);
  }

  /// Handle Android back: close the topmost overlay. Returns whether one closed.
  bool _handleBack() {
    if (_lightbox) {
      setState(() => _lightbox = false);
      return true;
    }
    if (_openEpisode != null) {
      setState(() => _openEpisode = null);
      return true;
    }
    if (_notesVisible) {
      setState(() => _notesVisible = false);
      return true;
    }
    return false;
  }

  static bool _hasNote(EpisodeNode? n) =>
      n != null &&
      ((n.note?.isNotEmpty ?? false) ||
          (n.lead?.isNotEmpty ?? false) ||
          (n.subStories?.isNotEmpty ?? false));

  void _openSettings() => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const SettingsScreen()));

  void _openStoryList() => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const StoryListScreen()));

  @override
  Widget build(BuildContext context) {
    final overlayUp = _lightbox || _openEpisode != null;
    return PopScope(
      canPop: !overlayUp && !_notesVisible,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        body: Consumer<GuideController>(
          builder: (context, gc, _) {
            final nodes = gc.currentNodes;
            final focused = gc.focusedNode;
            final bgPath = focused == null ? null : episodeBackground(focused);
            return Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: Color(0xFF0D0D0F)),
                _Backdrop(node: focused),
                Positioned.fill(child: AshFx(paused: overlayUp)),
                if (gc.loading)
                  const Center(child: CircularProgressIndicator())
                else if (gc.error != null)
                  _ErrorView(
                      onRetry: () =>
                          gc.load(context.read<SettingsStore>().state.server))
                else
                  SafeArea(
                    child: Column(
                      children: [
                        // The scroller fills the area and the header overlays its
                        // top, so episodes slide UP behind the frosted header
                        // (blurred by it) instead of clipping at its edge.
                        Expanded(
                          child: Stack(
                            children: [
                              Positioned.fill(child: _scroller(gc, nodes)),
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                child: _blurHeader(gc, focused, bgPath),
                              ),
                            ],
                          ),
                        ),
                        _selector(gc),
                      ],
                    ),
                  ),

                // Floating notes panel for the focused node.
                if (_notesVisible && focused != null)
                  _NotesPanel(
                    node: focused,
                    onClose: () => setState(() => _notesVisible = false),
                  ),

                // Chapter drill-down (slides/fades in over the same backdrop).
                Positioned.fill(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween(
                                begin: const Offset(0, 0.03), end: Offset.zero)
                            .animate(anim),
                        child: child,
                      ),
                    ),
                    child: _openEpisode == null
                        ? const SizedBox.shrink()
                        : ChaptersPanel(
                            key: ValueKey(
                                _openEpisode!.event?.id ?? _openEpisode!.title),
                            node: _openEpisode!,
                            onBack: _close,
                          ),
                  ),
                ),

                // Full-screen background lightbox (topmost).
                if (_lightbox && bgPath != null)
                  _Lightbox(
                    path: bgPath,
                    onClose: () => setState(() => _lightbox = false),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Frosted, translucent header behind the top controls + arc rail, with a
  /// gradient that dissolves into the content below (no hard edge under the arcs).
  Widget _blurHeader(GuideController gc, EpisodeNode? focused, String? bgPath) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x730D0D0F), Color(0x3D0D0D0F), Color(0x000D0D0F)],
              stops: [0.0, 0.55, 1.0],
            ),
          ),
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _topBar(gc, focused, bgPath),
              if (gc.isMainStory && gc.arcCount > 1) _arcRail(gc),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar(GuideController gc, EpisodeNode? focused, String? bgPath) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
      child: Row(
        children: [
          _IconBtn(
              icon: Icons.settings_outlined,
              tooltip: 'Settings',
              onTap: _openSettings),
          _IconBtn(
            icon: Icons.sticky_note_2_outlined,
            tooltip: 'Notes',
            active: _notesVisible,
            badge: _hasNote(focused) && !_notesVisible,
            onTap: () => setState(() => _notesVisible = !_notesVisible),
          ),
          const Spacer(),
          if (bgPath != null)
            _TextBtn(
                label: 'Background',
                onTap: () => setState(() => _lightbox = true)),
          const SizedBox(width: 8),
          _TextBtn(label: '☰ Story List', onTap: _openStoryList),
        ],
      ),
    );
  }

  Widget _arcRail(GuideController gc) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < gc.arcCount; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _Pill(
                label: 'Arc ${_roman[i]}',
                active: gc.arcIndex == i,
                onTap: () {
                  gc.selectArc(i);
                  _resetToTop();
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _scroller(GuideController gc, List<EpisodeNode> nodes) {
    if (nodes.isEmpty) {
      return const Center(
        child: Text('No episodes', style: TextStyle(color: Colors.white54)),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final headerH = _topBarHeight +
            (gc.isMainStory && gc.arcCount > 1 ? _arcRailHeight : 0) +
            _headerBottomPad;
        final visibleH = h - headerH; // area below the overlaid header
        final itemExtent = visibleH * 0.72;
        // Centre the focused card in the VISIBLE area (below the header); a card
        // still scrolls up into the header band (where it's blurred) as it exits.
        final topPad = headerH + (visibleH - itemExtent) / 2;
        final bottomPad = h - itemExtent - topPad;
        return NotificationListener<ScrollEndNotification>(
          onNotification: (_) {
            if (_scroll.hasClients) {
              gc.setFocused((_scroll.offset / itemExtent)
                  .round()
                  .clamp(0, nodes.length - 1));
            }
            return false;
          },
          child: ListView.builder(
            controller: _scroll,
            physics: _SnapScrollPhysics(itemExtent: itemExtent),
            padding: EdgeInsets.only(top: topPad, bottom: bottomPad),
            itemExtent: itemExtent,
            itemCount: nodes.length,
            itemBuilder: (context, i) {
              final node = nodes[i];
              return AnimatedBuilder(
                animation: _scroll,
                child: EpisodeCard(node: node, onTap: () => _open(node)),
                builder: (context, child) {
                  var pos = gc.focusedIndex.toDouble();
                  if (_scroll.hasClients &&
                      _scroll.position.hasContentDimensions) {
                    pos = _scroll.offset / itemExtent;
                  }
                  // Keep off-centre cards fully visible (no dim/fade) — they just
                  // slide up and clip cleanly at the header edge. A subtle scale
                  // still marks the focused one.
                  final t = (pos - i).abs().clamp(0.0, 1.0);
                  return Transform.scale(scale: 1 - 0.06 * t, child: child);
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _selector(GuideController gc) {
    final labels = gc.selectorLabels;
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) => _Pill(
          label: labels[i],
          active: gc.storylineIndex == i,
          onTap: () {
            gc.selectStoryline(i);
            _resetToTop();
          },
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Pill({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? _gold.withValues(alpha: 0.18) : Colors.white10,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              color: active ? _gold : Colors.white70,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _Backdrop extends StatelessWidget {
  final EpisodeNode? node;
  const _Backdrop({required this.node});

  @override
  Widget build(BuildContext context) {
    final path = node == null ? null : episodeBackground(node!);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: path == null
          ? const SizedBox.shrink(key: ValueKey('none'))
          : Stack(
              key: ValueKey(path),
              fit: StackFit.expand,
              children: [
                Image.asset(
                  path,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xCC0D0D0F), Color(0x550D0D0F), Color(0xF20D0D0F)],
                      stops: [0.0, 0.4, 1.0],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("Couldn't load the story list",
              style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class EpisodeCard extends StatelessWidget {
  final EpisodeNode node;
  final VoidCallback? onTap;
  const EpisodeCard({super.key, required this.node, this.onTap});

  @override
  Widget build(BuildContext context) {
    final banner = chapterImage(node.event?.name ?? node.title);
    final progress = context.watch<ProgressStore>();
    final summary = node.event == null
        ? null
        : progress.summarize([for (final s in node.event!.stories) s.txt]);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: AspectRatio(
            aspectRatio: 0.84,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFF23221F),
                  border: Border.all(
                    color: node.isEpisode
                        ? _gold.withValues(alpha: 0.55)
                        : Colors.white24,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (banner != null)
                      Image.asset(banner, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholder())
                    else
                      _placeholder(),
                    if (node.isIS) _tag('IS', const Color(0xFF8A6CC0)),
                    if (node.optional || node.forceOptional)
                      _tag('Optional', const Color(0xCC141416)),
                  ],
                ),
              ),
            ),
          )),
          const SizedBox(height: 8),
          Text(
            node.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: node.isEpisode ? _gold : Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          if (summary != null) ...[
            const SizedBox(height: 6),
            _ProgressBar(
                pct: summary.total == 0 ? 0 : summary.read / summary.total,
                full: summary.status == ReadStatus.read),
          ],
        ],
      ),
      ),
    );
  }

  Widget _placeholder() => Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(node.title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFB7B2A6), fontSize: 13)),
        ),
      );

  Widget _tag(String text, Color bg) => Positioned(
        top: 8,
        left: 8,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(text,
              style: const TextStyle(
                  fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      );
}

class _ProgressBar extends StatelessWidget {
  final double pct;
  final bool full;
  const _ProgressBar({required this.pct, required this.full});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      height: 7,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Stack(
          children: [
            const ColoredBox(color: Colors.white24),
            FractionallySizedBox(
              widthFactor: pct.clamp(0.0, 1.0),
              child: ColoredBox(
                  color: full ? const Color(0xFF5AA469) : _gold),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chapter drill-down: the tapped event's stories over the guide backdrop.
class ChaptersPanel extends StatelessWidget {
  final EpisodeNode node;
  final VoidCallback onBack;
  const ChaptersPanel({super.key, required this.node, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final stories = node.event?.stories ?? const <Story>[];
    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xF20D0D0F)),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.chevron_left),
                  tooltip: 'Back',
                ),
                Expanded(
                  child: Text(
                    node.event?.name ?? node.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _gold,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: stories.length,
                itemBuilder: (context, i) => _ChapterRow(story: stories[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChapterRow extends StatelessWidget {
  final Story story;
  const _ChapterRow({required this.story});

  @override
  Widget build(BuildContext context) {
    final status = context.watch<ProgressStore>().statusOf(story.txt);
    return InkWell(
      onTap: () {}, // TODO: open the reader once StoryView is built
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 28,
              decoration: BoxDecoration(
                color: _statusColor(status),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            if (story.code.isNotEmpty) ...[
              Text(story.code,
                  style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(
                      text: story.name.isNotEmpty ? story.name : story.txt),
                  if (story.tag.isNotEmpty)
                    TextSpan(
                      text: '  ·  ${story.tag}',
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                ]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;
  final bool badge;
  const _IconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
    this.badge = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: tooltip,
          onPressed: onTap,
          icon: Icon(icon, color: active ? _gold : Colors.white70),
        ),
        if (badge)
          const Positioned(
            right: 8,
            top: 8,
            child: IgnorePointer(
              child: Icon(Icons.circle, size: 8, color: _gold),
            ),
          ),
      ],
    );
  }
}

class _TextBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _TextBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) =>
      _Pill(label: label, active: false, onTap: onTap);
}

/// Floating notes panel for the focused guide node (lead / note / sub-stories).
class _NotesPanel extends StatelessWidget {
  final EpisodeNode node;
  final VoidCallback onClose;
  const _NotesPanel({required this.node, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final lead = node.lead;
    final note = node.note;
    final subs = node.subStories ?? const <SubStory>[];
    final hasAny = (lead?.isNotEmpty ?? false) ||
        (note?.isNotEmpty ?? false) ||
        subs.isNotEmpty;
    return Positioned(
      top: MediaQuery.of(context).padding.top + 56,
      left: 24,
      right: 24,
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxHeight: 320),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xF01A1A1E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (lead != null && lead.isNotEmpty) ...[
                  Text(lead,
                      style: const TextStyle(
                          color: Color(0xFFD8B878),
                          fontSize: 13,
                          fontStyle: FontStyle.italic)),
                  const SizedBox(height: 10),
                ],
                if (note != null && note.isNotEmpty)
                  Text(note,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14, height: 1.4)),
                if (subs.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final ss in subs)
                        Chip(
                          label: Text('▸ ${ss.name}',
                              style: const TextStyle(fontSize: 12)),
                          backgroundColor: Colors.white10,
                          side: BorderSide.none,
                        ),
                    ],
                  ),
                ],
                if (!hasAny)
                  const Text('No notes for this entry.',
                      style: TextStyle(color: Colors.white54)),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(onPressed: onClose, child: const Text('Close')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-screen, tap-to-dismiss view of the uncropped scene background.
class _Lightbox extends StatelessWidget {
  final String path;
  final VoidCallback onClose;
  const _Lightbox({required this.path, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onClose,
      child: Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: InteractiveViewer(
          child: Image.asset(
            path,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

/// Placeholder for the full story browser (the "☰ Story List" destination).
class StoryListScreen extends StatelessWidget {
  const StoryListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Story List')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'The full story browser is coming soon.\n\n'
            'For now, tap an episode on the guide to open its chapter list.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, height: 1.5),
          ),
        ),
      ),
    );
  }
}
