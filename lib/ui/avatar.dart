// Speaker portrait for a dialog row. Ported from
// BetterPhoneReader/src/components/Avatar.vue.
//
// A portrait id maps to several candidate URLs (the game data isn't consistent
// about naming), so we walk the chain until one loads and remember the winner in
// [ResolvedUrls] — next time it's tried first, which avoids the 404 round-trips
// that used to make portraits flicker in. If there's no portrait, or every
// candidate fails, we render nothing rather than a placeholder.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../data/offline.dart';
import '../data/resolved.dart';
import '../data/source.dart';
import 'local_image.dart';

const double avatarSize = 44;

class Avatar extends StatefulWidget {
  final String? portrait;
  const Avatar({super.key, this.portrait});

  @override
  State<Avatar> createState() => _AvatarState();
}

class _AvatarState extends State<Avatar> {
  List<AvatarCandidate> _candidates = const [];
  int _index = 0;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _rebuild();
  }

  @override
  void didUpdateWidget(Avatar old) {
    super.didUpdateWidget(old);
    if (old.portrait != widget.portrait) _rebuild();
  }

  String get _memoKey => 'av:${widget.portrait}';

  void _rebuild() {
    final portrait = widget.portrait;
    if (portrait == null || portrait.isEmpty) {
      _candidates = const [];
    } else {
      // Drop the mystery-NPC silhouette: rendering nothing reads better than a
      // generic placeholder next to a named speaker.
      final list = avatarCandidates(portrait)
          .where((c) => c.url != mysteryAvatar)
          .toList();
      final known = context.read<ResolvedUrls>().get(_memoKey);
      if (known != null) {
        final hit = list.indexWhere((c) => c.url == known);
        if (hit > 0) list.insert(0, list.removeAt(hit));
      }
      _candidates = list;
    }
    _index = 0;
    _failed = _candidates.isEmpty;
  }

  void _onError() {
    if (!mounted) return;
    if (_index < _candidates.length - 1) {
      setState(() => _index++);
    } else {
      setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return const SizedBox(width: avatarSize, height: avatarSize);
    final candidate = _candidates[_index];

    Widget image = Image(
      image: readerImage(candidate.url, context.read<Offline?>()),
      width: avatarSize,
      height: avatarSize,
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) {
        // Advance after this frame — errorBuilder runs during build, and
        // setState isn't allowed there.
        WidgetsBinding.instance.addPostFrameCallback((_) => _onError());
        return const SizedBox(width: avatarSize, height: avatarSize);
      },
      frameBuilder: (_, child, frame, wasSyncLoaded) {
        if (frame != null || wasSyncLoaded) {
          context.read<ResolvedUrls>().set(_memoKey, candidate.url);
        }
        return child;
      },
    );

    // Full character art (not a cropped avatar): zoom into the head region at the
    // top-centre of the portrait. 50% 14% in CSS terms -> Alignment(0, -0.72).
    if (candidate.crop) {
      image = Transform.scale(
        scale: 3.1,
        alignment: const Alignment(0, -0.72),
        child: image,
      );
    }

    return Container(
      width: avatarSize,
      height: avatarSize,
      margin: const EdgeInsets.only(top: 16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0x55000000),
        borderRadius: BorderRadius.circular(8),
      ),
      child: image,
    );
  }
}
