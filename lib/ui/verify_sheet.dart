// Verify / repair / delete sheet for downloaded content. Long-pressed from an
// episode card or a chapter row (and opened by tapping a fully-downloaded
// episode). Ports the verify dialog from BetterPhoneReader/src/views/HomeView.vue.
//
// Given the chapter txts to check (one for a chapter, all of an event's for an
// episode), it aggregates Offline.verifyStory across them and offers Repair
// (re-download only the incomplete ones through the queue) and Delete.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/offline.dart';
import '../stores/offline_store.dart';
import '../stores/progress_store.dart';
import '../stores/settings_store.dart';
import 'download_queue.dart';

const _gold = Color(0xFFE8C987);

/// Open the verify sheet for [title] over the given [txts].
Future<void> showVerifySheet(
  BuildContext context, {
  required String title,
  required List<String> txts,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF1C1B1A),
    showDragHandle: true,
    builder: (_) => _VerifySheet(title: title, txts: txts),
  );
}

/// Aggregate verify result across a set of chapters.
class _Report {
  final int total; // asset files expected across all chapters
  final int present; // of those, how many are on disk
  final List<String> incomplete; // chapter txts needing repair
  final int downloadedCount; // chapters whose json is on disk

  const _Report({
    required this.total,
    required this.present,
    required this.incomplete,
    required this.downloadedCount,
  });

  int get missing => total - present;
  bool get anyDownloaded => downloadedCount > 0;
}

class _VerifySheet extends StatefulWidget {
  final String title;
  final List<String> txts;
  const _VerifySheet({required this.title, required this.txts});

  @override
  State<_VerifySheet> createState() => _VerifySheetState();
}

class _VerifySheetState extends State<_VerifySheet> {
  _Report? _report;
  bool _busy = true;
  bool _repairing = false;

  @override
  void initState() {
    super.initState();
    _verify();
  }

  Future<void> _verify() async {
    setState(() => _busy = true);
    final offline = context.read<Offline?>();
    final server = context.read<SettingsStore>().state.server;
    var total = 0, present = 0, downloaded = 0;
    final incomplete = <String>[];
    if (offline != null) {
      for (final txt in widget.txts) {
        final r = await offline.verifyStory(server, txt);
        if (r.downloaded) downloaded++;
        total += r.total;
        present += r.present;
        // Not fully present, or a legacy download with no manifest to check.
        if (!r.downloaded || !r.hasManifest || r.present < r.total) {
          incomplete.add(txt);
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _report = _Report(
        total: total,
        present: present,
        incomplete: incomplete,
        downloadedCount: downloaded,
      );
      _busy = false;
    });
  }

  Future<void> _repair() async {
    final report = _report;
    if (report == null || report.incomplete.isEmpty) return;
    setState(() => _repairing = true);
    final queue = context.read<DownloadQueue>();
    final server = context.read<SettingsStore>().state.server;
    for (final txt in report.incomplete) {
      await queue.repairChapter(server, txt);
    }
    if (!mounted) return;
    setState(() => _repairing = false);
    await _verify();
  }

  Future<void> _delete() async {
    setState(() => _busy = true);
    final offline = context.read<Offline?>();
    final store = context.read<OfflineStore>();
    final server = context.read<SettingsStore>().state.server;
    if (offline != null) {
      for (final txt in widget.txts) {
        await offline.removeStory(server, txt);
        store.unmark(txt);
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: _gold, fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text('${widget.txts.length} chapter(s)',
                style: const TextStyle(color: Colors.white38, fontSize: 12)),
            const SizedBox(height: 16),
            _status(report),
            const SizedBox(height: 16),
            _readToggle(),
            const SizedBox(height: 10),
            _actions(report),
          ],
        ),
      ),
    );
  }

  /// Mark every chapter of this item read (or unread if they all are already).
  /// Independent of download state — it's about reading progress.
  Widget _readToggle() {
    final progress = context.watch<ProgressStore>();
    final allRead = widget.txts.isNotEmpty &&
        widget.txts.every((t) => progress.statusOf(t) == ReadStatus.read);
    return _SheetButton(
      label: allRead ? 'Mark as unread' : 'Mark as read',
      color: const Color(0xFF5AA469),
      onTap: () {
        for (final t in widget.txts) {
          if (allRead) {
            progress.markUnread(t);
          } else {
            progress.markRead(t);
          }
        }
      },
    );
  }

  Widget _status(_Report? report) {
    if (_busy || report == null) {
      return const Row(
        children: [
          SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: _gold)),
          SizedBox(width: 12),
          Text('Verifying…', style: TextStyle(color: Colors.white70)),
        ],
      );
    }
    if (!report.anyDownloaded) {
      return const _StatusLine(
        icon: Icons.cloud_off,
        color: Colors.white54,
        text: "Not downloaded.",
      );
    }
    if (report.incomplete.isNotEmpty) {
      final missingLabel =
          report.total > 0 ? '${report.missing} of ${report.total}' : 'some';
      return _StatusLine(
        icon: Icons.warning_amber_rounded,
        color: const Color(0xFFE0A24A),
        text: '$missingLabel files missing.',
      );
    }
    return _StatusLine(
      icon: Icons.check_circle_outline,
      color: const Color(0xFF5AA469),
      text: 'All files present (${report.present}).',
    );
  }

  Widget _actions(_Report? report) {
    final needsRepair = report != null && report.incomplete.isNotEmpty;
    return Row(
      children: [
        if (report != null && report.anyDownloaded)
          Expanded(
            child: _SheetButton(
              label: 'Delete',
              color: const Color(0xFFE07A7A),
              onTap: _busy || _repairing ? null : _delete,
            ),
          ),
        if (report != null && report.anyDownloaded) const SizedBox(width: 10),
        Expanded(
          child: _SheetButton(
            label: needsRepair
                ? (_repairing ? 'Repairing…' : 'Repair')
                : 'Verify',
            color: _gold,
            filled: needsRepair,
            onTap: _busy || _repairing
                ? null
                : (needsRepair ? _repair : _verify),
          ),
        ),
      ],
    );
  }
}

class _StatusLine extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _StatusLine(
      {required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(color: color, fontSize: 14)),
          ),
        ],
      );
}

class _SheetButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool filled;
  final VoidCallback? onTap;
  const _SheetButton({
    required this.label,
    required this.color,
    this.filled = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Opacity(
      opacity: disabled ? 0.4 : 1,
      child: Material(
        color: filled ? color : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: color),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: filled ? const Color(0xFF1B1A18) : color,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
