// Minimal settings screen (opened from the guide top bar). Reads/writes the
// SettingsStore; changing the story language reloads the guide.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/servers.dart';
import '../stores/settings_store.dart';
import 'guide_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _name;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(
        text: context.read<SettingsStore>().state.doctorName);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SettingsStore>();
    final s = store.state;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SectionTitle('Doctor name'),
          TextField(
            controller: _name,
            decoration: const InputDecoration(
                border: OutlineInputBorder(), hintText: 'Doctor'),
            onChanged: (v) => store.set(
                s.copyWith(doctorName: v.trim().isEmpty ? 'Doctor' : v.trim())),
          ),
          const SizedBox(height: 20),
          const _SectionTitle('Story language'),
          DropdownButton<String>(
            value: servers.contains(s.server) ? s.server : servers.first,
            isExpanded: true,
            items: [
              for (final sv in servers)
                DropdownMenuItem(value: sv, child: Text(sv)),
            ],
            onChanged: (v) {
              if (v == null) return;
              store.set(s.copyWith(server: v));
              context.read<GuideController>().load(v);
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Visual-novel mode'),
            subtitle: const Text('One line at a time; tap to advance'),
            value: s.readerMode == 'vn',
            onChanged: (v) =>
                store.set(s.copyWith(readerMode: v ? 'vn' : 'novel')),
          ),
          if (s.readerMode == 'vn') ...[
            const SizedBox(height: 12),
            const _SectionTitle('Text speed'),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'slow', label: Text('Slow')),
                ButtonSegment(value: 'normal', label: Text('Normal')),
                ButtonSegment(value: 'fast', label: Text('Fast')),
                ButtonSegment(value: 'instant', label: Text('Instant')),
              ],
              selected: {s.textSpeed},
              showSelectedIcon: false,
              onSelectionChanged: (v) =>
                  store.set(s.copyWith(textSpeed: v.first)),
            ),
          ],
          const SizedBox(height: 12),
          _SectionTitle('Font size — ${s.fontSize}'),
          Slider(
            min: 12,
            max: 24,
            divisions: 12,
            value: s.fontSize.toDouble().clamp(12, 24),
            label: '${s.fontSize}',
            onChanged: (v) => store.set(s.copyWith(fontSize: v.round())),
          ),
          const SizedBox(height: 12),
          const _SectionTitle('Audio'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Background music'),
            subtitle: const Text('Plays the story track, switching as you read'),
            value: s.musicEnabled,
            onChanged: (v) => store.set(s.copyWith(musicEnabled: v)),
          ),
          if (s.musicEnabled)
            Slider(
              min: 0,
              max: 1,
              divisions: 20,
              value: s.musicVolume.clamp(0, 1),
              label: '${(s.musicVolume * 100).round()}%',
              onChanged: (v) => store.set(s.copyWith(musicVolume: v)),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Sound effects'),
            subtitle: const Text('Show tappable sound buttons in the story'),
            value: s.soundEnabled,
            onChanged: (v) => store.set(s.copyWith(soundEnabled: v)),
          ),
          if (s.soundEnabled) ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Play sounds automatically'),
              subtitle: const Text('Play each sound once as you scroll past it'),
              value: s.soundAutoplay,
              onChanged: (v) => store.set(s.copyWith(soundAutoplay: v)),
            ),
            Slider(
              min: 0,
              max: 1,
              divisions: 20,
              value: s.soundVolume.clamp(0, 1),
              label: '${(s.soundVolume * 100).round()}%',
              onChanged: (v) => store.set(s.copyWith(soundVolume: v)),
            ),
          ],
          const SizedBox(height: 12),
          const _SectionTitle('Developer'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('FPS meter'),
            subtitle: const Text('Show measured frame rate + worst frame time'),
            value: s.debugPerf,
            onChanged: (v) => store.set(s.copyWith(debugPerf: v)),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(text,
            style: const TextStyle(
                color: Color(0xFFE8C987), fontWeight: FontWeight.w600)),
      );
}
