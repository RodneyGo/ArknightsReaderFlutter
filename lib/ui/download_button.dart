// Download controls for the guide. Two entry points, one pipeline:
//  - [DownloadButton]        a single chapter row in the drill-down
//  - [EpisodeDownloadButton] the whole event, overlaid on an episode card
//
// Both drive the shared [DownloadQueue] (never Offline directly), so downloads
// are serialised and can't race on the filesystem. Long-press / tap-when-full
// opens the verify sheet.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/menu.dart';
import '../data/offline.dart';
import '../stores/settings_store.dart';
import 'download_queue.dart';
import 'verify_sheet.dart';

const _gold = Color(0xFFE8C987);
const _green = Color(0xFF5AA469);
const _red = Color(0xFFE07A7A);

/// Whole-event download control, overlaid on an episode card's banner.
class EpisodeDownloadButton extends StatelessWidget {
  final EventGroup event;
  const EpisodeDownloadButton({super.key, required this.event});

  List<String> get _txts => [for (final s in event.stories) s.txt];

  @override
  Widget build(BuildContext context) {
    final offline = context.read<Offline?>();
    if (offline == null || !offline.isNative || _txts.isEmpty) {
      return const SizedBox.shrink();
    }
    final queue = context.watch<DownloadQueue>();
    final state = queue.stateOf(event.id, _txts);

    return _DownloadChip(
      state: state,
      percent: queue.percentOf(event.id),
      onTap: () => _onTap(context, queue, state),
    );
  }

  void _onTap(BuildContext context, DownloadQueue queue, DownloadState state) {
    final server = context.read<SettingsStore>().state.server;
    switch (state) {
      case DownloadState.busy:
        break; // running — ignore
      case DownloadState.full:
        showVerifySheet(context, title: event.name, txts: _txts);
      case DownloadState.none:
      case DownloadState.partial:
      case DownloadState.queued:
      case DownloadState.failed:
        queue.enqueueEpisode(server, event.id, _txts);
    }
  }
}

/// Single-chapter control for the drill-down chapter rows.
class DownloadButton extends StatelessWidget {
  final String txt;
  const DownloadButton({super.key, required this.txt});

  @override
  Widget build(BuildContext context) {
    final offline = context.read<Offline?>();
    if (offline == null || !offline.isNative) return const SizedBox.shrink();
    final queue = context.watch<DownloadQueue>();
    final state = queue.stateOf(txt, [txt]);

    return _DownloadChip(
      state: state,
      percent: queue.percentOf(txt),
      compact: true,
      onTap: () {
        final server = context.read<SettingsStore>().state.server;
        switch (state) {
          case DownloadState.busy:
            break;
          case DownloadState.full:
            showVerifySheet(context, title: txt, txts: [txt]);
          case DownloadState.none:
          case DownloadState.partial:
          case DownloadState.queued:
          case DownloadState.failed:
            queue.enqueueEpisode(server, txt, [txt]);
        }
      },
    );
  }
}

class _DownloadChip extends StatelessWidget {
  final DownloadState state;
  final double percent;
  final bool compact;
  final VoidCallback onTap;

  const _DownloadChip({
    required this.state,
    required this.percent,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = compact ? 40.0 : 34.0;
    Widget inner;
    String tip;
    switch (state) {
      case DownloadState.busy:
        tip = 'Downloading ${(percent * 100).round()}%';
        inner = SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            value: percent > 0 ? percent : null,
            strokeWidth: 2,
            color: _gold,
          ),
        );
      case DownloadState.queued:
        tip = 'Queued — tap to cancel';
        inner = const Icon(Icons.hourglass_empty, size: 20, color: _gold);
      case DownloadState.full:
        tip = 'Downloaded — tap to manage';
        inner = const Icon(Icons.download_done, size: 20, color: _green);
      case DownloadState.partial:
        tip = 'Partly downloaded — tap to finish';
        inner = const Icon(Icons.donut_large, size: 20, color: _gold);
      case DownloadState.failed:
        tip = 'Download failed — tap to retry';
        inner = const Icon(Icons.error_outline, size: 20, color: _red);
      case DownloadState.none:
        tip = 'Download for offline';
        inner = const Icon(Icons.download_outlined, size: 20, color: Colors.white70);
    }

    final chip = SizedBox(
      width: size,
      height: size,
      child: Center(child: inner),
    );
    // Episode overlay gets a scrim so the icon reads over bright artwork; the
    // chapter row sits on a dark panel already.
    return Semantics(
      button: true,
      label: tip,
      child: Material(
        color: compact ? Colors.transparent : const Color(0x99000000),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: chip),
      ),
    );
  }
}
