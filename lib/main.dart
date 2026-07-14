// Temporary entry point for the Flutter port.
//
// This is NOT the real app yet — it's a smoke screen that runs the ported
// `normalizeStory` on a small hardcoded sample and lists the resulting items, so
// `flutter run` gives immediate proof the data layer works on-device. The real
// UI (Guide / Story / VN reader) will replace this as it's built.

import 'package:flutter/material.dart';

import 'data/models.dart';
import 'data/parse.dart';

void main() => runApp(const PortSmokeApp());

const _sample = <Map<String, dynamic>>[
  {'prop': 'Background', 'attributes': {'image': 'bg_rhodes'}},
  {'prop': 'Character', 'attributes': {'name': 'char_002_amiya_1', 'focus': '1'}},
  {'prop': 'name', 'attributes': {'name': 'Amiya', 'content': 'Doctor, {@nickname}! You are finally awake.'}},
  {'prop': 'name', 'attributes': {'name': '', 'content': 'The room is silent.'}},
  {'prop': 'Decision', 'attributes': {'options': 'Where am I?;Who are you?', 'values': '1;2'}},
  {'prop': 'Blocker'},
  {'prop': 'name', 'attributes': {'name': 'Amiya', 'content': 'This is Rhodes Island.'}},
];

class PortSmokeApp extends StatelessWidget {
  const PortSmokeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AK Reader (port)',
      theme: ThemeData.dark(useMaterial3: true),
      home: const _SmokeScreen(),
    );
  }
}

class _SmokeScreen extends StatelessWidget {
  const _SmokeScreen();

  @override
  Widget build(BuildContext context) {
    final raw = <RawLine>[
      for (var i = 0; i < _sample.length; i++) RawLine.fromJson(_sample[i], i),
    ];
    final items = normalizeStory(raw, 'Kal\'tsit');

    return Scaffold(
      appBar: AppBar(title: const Text('Data-layer smoke test')),
      body: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 8),
        itemBuilder: (_, i) {
          final it = items[i];
          return ListTile(
            dense: true,
            leading: Text(it.kind, style: const TextStyle(fontSize: 11, color: Colors.tealAccent)),
            title: Text(_describe(it)),
            subtitle: Text('bg: ${it.bg ?? "—"}'
                '${it.branch != null ? "  ·  ${it.branch}" : ""}'),
          );
        },
      ),
    );
  }

  static String _plain(List<TextRun> runs) => runs.map((r) => r.text).join();

  String _describe(StoryItem it) => switch (it) {
        DialogItem d =>
          '${d.name}: ${_plain(d.runs)}   (portrait: ${d.portrait ?? "none"})',
        NarrationItem n => _plain(n.runs),
        SubtitleItem s => _plain(s.runs),
        DecisionItem d => 'CHOICE: ${d.options.join(" / ")}',
        SoundItem s => '${s.music ? "music" : "sfx"}: ${s.key}',
        SceneBreakItem _ => '— scene break —',
      };
}
