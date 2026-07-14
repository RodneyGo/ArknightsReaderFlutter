// App entry point. Loads the guide data + image asset lookups, wires the
// persisted stores + the guide controller via Provider, and shows the reading
// guide (the landing screen).

import 'package:flutter/material.dart';
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
  final kv = await SharedPrefsStore.create();
  await loadImageAssets(); // chapter-image + background lookups
  await loadGuide(); // ARCS + NOTE_RU from the bundled asset
  runApp(AkReaderApp(kv: kv));
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
