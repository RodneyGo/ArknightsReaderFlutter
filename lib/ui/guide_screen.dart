// The reading-guide hub — the app's landing screen (the "main menu"). Backdrop
// (focused episode's background) + ambient embers, a vertical snap-scroller of
// episode cards (Flutter PageView gives the snap + focus-scaling for free), an
// arc rail for Main Story, and a bottom storyline selector.
//
// Tapping a card (chapter drill-down) + notes + downloads come next.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/backgrounds.dart';
import '../data/chapter_images.dart';
import '../data/guide.dart';
import '../stores/progress_store.dart';
import 'ash_fx.dart';
import 'guide_controller.dart';

const _roman = ['I', 'II', 'III', 'IV', 'V', 'VI'];
const _gold = Color(0xFFE8C987);

class GuideScreen extends StatefulWidget {
  const GuideScreen({super.key});

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  final _page = PageController(viewportFraction: 0.6);

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  void _resetToTop() {
    if (_page.hasClients) _page.jumpToPage(0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<GuideController>(
        builder: (context, gc, _) {
          final nodes = gc.currentNodes;
          return Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: Color(0xFF0D0D0F)),
              _Backdrop(node: gc.focusedNode),
              const Positioned.fill(child: AshFx()),
              if (gc.loading)
                const Center(child: CircularProgressIndicator())
              else if (gc.error != null)
                _ErrorView(onRetry: () => gc.load('en_US'))
              else
                SafeArea(
                  child: Column(
                    children: [
                      if (gc.isMainStory && gc.arcCount > 1) _arcRail(gc),
                      Expanded(child: _scroller(gc, nodes)),
                      _selector(gc),
                    ],
                  ),
                ),
            ],
          );
        },
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
    return PageView.builder(
      controller: _page,
      scrollDirection: Axis.vertical,
      onPageChanged: gc.setFocused,
      itemCount: nodes.length,
      itemBuilder: (context, i) {
        final node = nodes[i];
        return AnimatedBuilder(
          animation: _page,
          child: EpisodeCard(node: node),
          builder: (context, child) {
            var pageVal = gc.focusedIndex.toDouble();
            if (_page.hasClients && _page.position.haveDimensions) {
              pageVal = _page.page ?? pageVal;
            }
            final t = (pageVal - i).abs().clamp(0.0, 1.0);
            return Opacity(
              opacity: 1 - 0.5 * t,
              child: Transform.scale(scale: 1 - 0.12 * t, child: child),
            );
          },
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
  const EpisodeCard({super.key, required this.node});

  @override
  Widget build(BuildContext context) {
    final banner = chapterImage(node.event?.name ?? node.title);
    final progress = context.watch<ProgressStore>();
    final summary = node.event == null
        ? null
        : progress.summarize([for (final s in node.event!.stories) s.txt]);

    return Padding(
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
