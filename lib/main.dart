// App entry point. Wires the persisted stores via Provider (they compose with
// the ChangeNotifiers) and shows the main menu (the reading-guide landing).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'stores/kv_store.dart';
import 'stores/offline_store.dart';
import 'stores/progress_store.dart';
import 'stores/settings_store.dart';
import 'ui/menu_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final kv = await SharedPrefsStore.create();
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
      ],
      child: MaterialApp(
        title: 'AK Story Reader',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true).copyWith(
          scaffoldBackgroundColor: const Color(0xFF0D0D0F),
        ),
        home: const MenuScreen(),
      ),
    );
  }
}
