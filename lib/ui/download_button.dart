// Per-chapter download control. Replaces the web's composables/downloads.ts +
// its chapter-list button.
//
// Owns one chapter's download lifecycle: idle -> downloading (with progress) ->
// downloaded, plus removal. The OfflineStore marker is only set after the files
// are actually written, so a failed or cancelled download never claims the
// chapter is available offline.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/offline.dart';
import '../stores/offline_store.dart';
import '../stores/settings_store.dart';

class DownloadButton extends StatefulWidget {
  final String txt;
  const DownloadButton({super.key, required this.txt});

  @override
  State<DownloadButton> createState() => _DownloadButtonState();
}

class _DownloadButtonState extends State<DownloadButton> {
  bool _busy = false;
  double _progress = 0;
  bool _failed = false;

  Future<void> _download() async {
    final offline = context.read<Offline?>();
    if (offline == null || _busy) return;
    final server = context.read<SettingsStore>().state.server;
    final store = context.read<OfflineStore>();
    setState(() {
      _busy = true;
      _progress = 0;
      _failed = false;
    });
    try {
      await offline.downloadStory(
        server,
        widget.txt,
        onProgress: (done, total) {
          if (!mounted || total == 0) return;
          setState(() => _progress = done / total);
        },
      );
      if (!mounted) return;
      store.mark(widget.txt);
    } catch (_) {
      // Leave the chapter unmarked: a half-written download must not look
      // available offline.
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    final offline = context.read<Offline?>();
    if (offline == null || _busy) return;
    final server = context.read<SettingsStore>().state.server;
    final store = context.read<OfflineStore>();
    setState(() => _busy = true);
    try {
      await offline.removeStory(server, widget.txt);
      if (mounted) store.unmark(widget.txt);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // No filesystem (web): nothing to download to.
    if (context.read<Offline?>() == null) return const SizedBox.shrink();
    final downloaded = context.watch<OfflineStore>().hasStory(widget.txt);

    if (_busy) {
      return SizedBox(
        width: 40,
        height: 40,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              // Indeterminate until the first progress report lands.
              value: _progress > 0 ? _progress : null,
              strokeWidth: 2,
              color: const Color(0xFFE8C987),
            ),
          ),
        ),
      );
    }

    return IconButton(
      tooltip: downloaded
          ? 'Remove download'
          : _failed
              ? 'Download failed — tap to retry'
              : 'Download for offline',
      icon: Icon(
        downloaded
            ? Icons.download_done
            : _failed
                ? Icons.error_outline
                : Icons.download_outlined,
        size: 20,
        color: downloaded
            ? const Color(0xFF5AA469)
            : _failed
                ? const Color(0xFFE07A7A)
                : Colors.white38,
      ),
      onPressed: downloaded ? _remove : _download,
    );
  }
}
