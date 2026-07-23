// App entry point. Loads the guide data + image asset lookups, wires the
// persisted stores + the guide controller via Provider, and shows the reading
// guide (the landing screen).

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:provider/provider.dart';

import 'data/guide.dart';
import 'data/image_assets.dart';
import 'data/offline.dart';
import 'data/resolved.dart';
import 'data/ru.dart';
import 'stores/kv_store.dart';
import 'stores/offline_store.dart';
import 'stores/progress_store.dart';
import 'stores/settings_store.dart';
import 'ui/download_queue.dart';
import 'ui/guide_controller.dart';
import 'ui/guide_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Draw behind the (transparent) system bars so the scene reaches every edge,
  // and don't let Android tint the nav bar. Orientation then decides whether the
  // status bar shows — see [_OrientationChrome].
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarContrastEnforced: false,
  ));
  await _requestHighRefreshRate();
  final kv = await SharedPrefsStore.create();
  final resolved = ResolvedUrls(kv);
  final offline = await Offline.create(resolved);
  final ru = await RuStore.create(); // RU index cache-first (saved -> bundled)
  await loadImageAssets(); // chapter-image + background lookups
  await loadGuide(); // ARCS + NOTE_RU from the bundled asset
  runApp(AkReaderApp(kv: kv, resolved: resolved, offline: offline, ru: ru));
}

/// Android runs apps at 60Hz by default — Flutter renders to whatever mode the
/// display is in, so a 120Hz panel stays locked at 60 unless we ask for more.
/// Requests the highest refresh mode at the current resolution. No-op where it
/// isn't supported (and some OEM skins, e.g. MIUI, may still cap it via their
/// own refresh-rate settings).
Future<void> _requestHighRefreshRate() async {
  if (!Platform.isAndroid) return;
  try {
    await FlutterDisplayMode.setHighRefreshRate();
  } catch (_) {
    // Unsupported device/OS — stay at the default mode.
  }
}

class AkReaderApp extends StatelessWidget {
  final KeyValueStore kv;
  final ResolvedUrls resolved;
  final Offline offline;
  final RuStore ru;

  const AkReaderApp({
    super.key,
    required this.kv,
    required this.resolved,
    required this.offline,
    required this.ru,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ResolvedUrls>(
          create: (_) => resolved,
          dispose: (_, r) => r.dispose(),
        ),
        Provider<Offline?>(create: (_) => offline),
        ChangeNotifierProvider<RuStore>.value(value: ru),
        ChangeNotifierProvider(create: (_) => SettingsStore(kv)),
        ChangeNotifierProvider(create: (_) => ProgressStore(kv)),
        ChangeNotifierProvider(
          // The filesystem is the truth: reconcile the marker index against the
          // chapters actually on disk (files can vanish — cache wipes, uninstalls
          // of app data, a failed download).
          create: (_) => OfflineStore(kv)..rebuildFrom(offline.downloadedTxts()),
        ),
        ChangeNotifierProvider(
          // Serialises every download so jobs can't race on the shared url map;
          // saves the RU overlay too when downloading in Russian.
          create: (ctx) =>
              DownloadQueue(offline, ctx.read<OfflineStore>(), ru: ru),
        ),
        ChangeNotifierProvider(
          create: (ctx) =>
              GuideController()..load(ctx.read<SettingsStore>().state.server),
        ),
      ],
      child: MaterialApp(
        title: 'AK Story Reader',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true).copyWith(
          scaffoldBackgroundColor: const Color(0xFF0D0D0F),
        ),
        builder: (context, child) =>
            _OrientationChrome(child: child ?? const SizedBox.shrink()),
        home: const GuideScreen(),
      ),
    );
  }
}

/// Applies the system-UI mode for the current orientation: landscape hides the
/// status bar (the immersive reading surface the user asked for) while keeping
/// the nav bar; portrait shows both, edge-to-edge, so the scene stays seamless
/// behind their transparent backgrounds. Wraps every route via MaterialApp's
/// builder, so it covers the guide and the reader alike.
class _OrientationChrome extends StatefulWidget {
  final Widget child;
  const _OrientationChrome({required this.child});

  @override
  State<_OrientationChrome> createState() => _OrientationChromeState();
}

class _OrientationChromeState extends State<_OrientationChrome> {
  Orientation? _applied;

  @override
  Widget build(BuildContext context) {
    final o = MediaQuery.orientationOf(context);
    if (o != _applied) {
      _applied = o;
      // Defer: setEnabledSystemUIMode is a platform call, not for build().
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _apply(o);
      });
    }
    return widget.child;
  }

  void _apply(Orientation o) {
    if (o == Orientation.landscape) {
      // Status bar gone; nav bar stays. Not immersive — an immersive mode would
      // reappear the bars on the reader's own swipe gesture.
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: const [SystemUiOverlay.bottom],
      );
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }
}
