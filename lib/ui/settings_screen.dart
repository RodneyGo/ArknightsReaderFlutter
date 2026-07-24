// Minimal settings screen (opened from the guide top bar). Reads/writes the
// SettingsStore; changing the story language reloads the guide.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/i18n.dart';
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
      appBar: AppBar(title: Text(context.l('settings'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionTitle(context.l('doctorName')),
          TextField(
            controller: _name,
            decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: context.l('doctorHint')),
            onChanged: (v) => store.set(
                s.copyWith(doctorName: v.trim().isEmpty ? 'Doctor' : v.trim())),
          ),
          const SizedBox(height: 20),
          _SectionTitle(context.l('storyLanguage')),
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
            title: Text(context.l('vnModeSetting')),
            subtitle: Text(context.l('vnModeSettingDesc')),
            value: s.readerMode == 'vn',
            onChanged: (v) =>
                store.set(s.copyWith(readerMode: v ? 'vn' : 'novel')),
          ),
          if (s.readerMode == 'vn') ...[
            const SizedBox(height: 12),
            _SectionTitle(context.l('textSpeed')),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'slow', label: Text(context.l('speedSlow'))),
                ButtonSegment(
                    value: 'normal', label: Text(context.l('speedNormal'))),
                ButtonSegment(value: 'fast', label: Text(context.l('speedFast'))),
                ButtonSegment(
                    value: 'instant', label: Text(context.l('speedInstant'))),
              ],
              selected: {s.textSpeed},
              showSelectedIcon: false,
              onSelectionChanged: (v) =>
                  store.set(s.copyWith(textSpeed: v.first)),
            ),
          ],
          const SizedBox(height: 12),
          _SectionTitle('${context.l('fontSize')} — ${s.fontSize}'),
          Slider(
            min: 12,
            max: 24,
            divisions: 12,
            value: s.fontSize.toDouble().clamp(12, 24),
            label: '${s.fontSize}',
            onChanged: (v) => store.set(s.copyWith(fontSize: v.round())),
          ),
          const SizedBox(height: 12),
          _SectionTitle(context.l('backdropFade')),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(context.l('backdropFadeDesc'),
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'none', label: Text(context.l('fadeNone'))),
              ButtonSegment(
                  value: 'small', label: Text(context.l('fadeSmall'))),
              ButtonSegment(
                  value: 'normal', label: Text(context.l('fadeNormal'))),
            ],
            selected: {s.backdropFade},
            showSelectedIcon: false,
            onSelectionChanged: (v) =>
                store.set(s.copyWith(backdropFade: v.first)),
          ),
          const SizedBox(height: 12),
          _SectionTitle(context.l('audio')),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.l('backgroundMusic')),
            subtitle: Text(context.l('backgroundMusicDesc')),
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
            title: Text(context.l('soundEffects')),
            subtitle: Text(context.l('soundEffectsDesc')),
            value: s.soundEnabled,
            onChanged: (v) => store.set(s.copyWith(soundEnabled: v)),
          ),
          if (s.soundEnabled) ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.l('autoPlaySounds')),
              subtitle: Text(context.l('autoPlaySoundsDesc')),
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
          _SectionTitle(context.l('developer')),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.l('fpsMeter')),
            subtitle: Text(context.l('fpsMeterDesc')),
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
