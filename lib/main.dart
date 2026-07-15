// App entry point. Loads the guide data + image asset lookups, wires the
// persisted stores + the guide controller via Provider, and shows the reading
// guide (the landing screen).

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:provider/provider.dart';

import 'data/guide.dart';
import 'data/image_assets.dart';
import 'stores/kv_store.dart';
import 'stores/offline_store.dart';
import 'stores/progress_store.dart';
import 'stores/settings_store.dart';
import 'ui/guide_controller.dart';
import 'ui/guide_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _requestHighRefreshRate();
  final kv = await SharedPrefsStore.create();
  await loadImageAssets(); // chapter-image + background lookups
  await loadGuide(); // ARCS + NOTE_RU from the bundled asset
  runApp(AkReaderApp(kv: kv));
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
  const AkReaderApp({super.key, required this.kv});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsStore(kv)),
        ChangeNotifierProvider(create: (_) => ProgressStore(kv)),
        ChangeNotifierProvider(create: (_) => OfflineStore(kv)),
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
        home: const GuideScreen(),
      ),
    );
  }
}
