// Full-screen in-app trailer player. Plays a YouTube video via the official
// iFrame player (ToS-compliant) with no chapter semantics — it's launched from
// the ChaptersPanel header and knows nothing about progress, downloads, or the
// reader. YoutubePlayer (v6) handles fullscreen internally via OverlayPortal.

import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../data/i18n.dart';

class TrailerScreen extends StatefulWidget {
  final String videoId;
  final String title;
  const TrailerScreen({super.key, required this.videoId, required this.title});

  @override
  State<TrailerScreen> createState() => _TrailerScreenState();
}

class _TrailerScreenState extends State<TrailerScreen> {
  late final YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.videoId,
      // No autoplay — the user taps play. Avoids a video starting under the
      // menu and keeps data use opt-in.
      autoPlay: false,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        enableCaption: true,
      ),
    );
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.title.isNotEmpty ? widget.title : context.l('trailer'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Center(
        child: YoutubePlayer(
          controller: _controller,
          aspectRatio: 16 / 9,
          // Don't let device rotation drive fullscreen: the app rotates freely,
          // and auto-fullscreen fights the back button (exit-fullscreen loops
          // straight back to fullscreen while the device is still landscape) and
          // flashes the loading thumbnail on every rotation. Fullscreen stays
          // available via the player's own button, whose back-to-exit is clean.
          autoFullScreen: false,
          enableFullScreenOnVerticalDrag: false,
        ),
      ),
    );
  }
}
