import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../effects/effects_sheet.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _lastfmCtl;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(sharedPrefsProvider);
    _lastfmCtl =
        TextEditingController(text: prefs.getString('lastfm_api_key') ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.read(authServiceProvider);
    final user = ref.watch(authStateProvider).valueOrNull as User?;
    final prefs = ref.read(sharedPrefsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.person),
            title: Text(user?.email ?? 'Not signed in'),
            subtitle: Text(user?.uid ?? ''),
            trailing: user == null
                ? null
                : OutlinedButton(
                    onPressed: () => auth?.signOut(),
                    child: const Text('Sign out'),
                  ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('Last.fm API key',
                style: Theme.of(context).textTheme.titleSmall),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Required for infinity-radio (genre / similar-track recommendations). Free from last.fm/api.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _lastfmCtl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'API key',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () async {
                    await prefs.setString(
                        'lastfm_api_key', _lastfmCtl.text.trim());
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Saved')),
                      );
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.graphic_eq),
            title: const Text('Equalizer'),
            subtitle: const Text('Per-band gain, all presets'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).pushNamed('/equalizer'),
          ),
          ListTile(
            leading: const Icon(Icons.folder_special),
            title: const Text('Music folders'),
            subtitle: const Text('Include / exclude scan locations'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).pushNamed('/folders'),
          ),
          ListTile(
            leading: const Icon(Icons.equalizer),
            title: const Text('Equalizer & effects'),
            subtitle: const Text('Presets, speed, pitch, crossfade'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showModalBottomSheet<void>(
              context: context,
              showDragHandle: true,
              isScrollControlled: true,
              builder: (_) => const EffectsSheet(),
            ),
          ),
          Consumer(builder: (context, ref, _) {
            final gapless =
                ref.watch(gaplessProvider).valueOrNull ?? true;
            return SwitchListTile(
              secondary: const Icon(Icons.link),
              title: const Text('Gapless playback'),
              subtitle: const Text('No silence between consecutive tracks'),
              value: gapless,
              onChanged: (v) =>
                  ref.read(audioHandlerProvider).setGapless(v),
            );
          }),
          Consumer(builder: (context, ref, _) {
            final cf =
                ref.watch(crossfadeProvider).valueOrNull ?? Duration.zero;
            return ListTile(
              leading: const Icon(Icons.shuffle),
              title: const Text('Crossfade duration'),
              subtitle: Slider(
                min: 0,
                max: 12,
                divisions: 12,
                label: cf == Duration.zero ? 'off' : '${cf.inSeconds}s',
                value: cf.inSeconds.toDouble().clamp(0, 12),
                onChanged: (v) => ref
                    .read(audioHandlerProvider)
                    .setCrossfade(Duration(seconds: v.round())),
              ),
              trailing: Text(cf == Duration.zero ? 'off' : '${cf.inSeconds}s'),
            );
          }),
          SwitchListTile(
            secondary: const Icon(Icons.wifi),
            title: const Text('Download on Wi-Fi only'),
            value: prefs.getBool('wifi_only_downloads') ?? true,
            onChanged: (v) async {
              await prefs.setBool('wifi_only_downloads', v);
              setState(() {});
            },
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('Visualizer style',
                style: Theme.of(context).textTheme.titleSmall),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Choose the animation shown on the now-playing screen.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Consumer(builder: (context, ref, _) {
            final style = ref.watch(visualizerStyleProvider);
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SegmentedButton<VisualizerStyle>(
                segments: const [
                  ButtonSegment(
                    value: VisualizerStyle.bars,
                    icon: Icon(Icons.equalizer),
                    label: Text('Bars'),
                  ),
                  ButtonSegment(
                    value: VisualizerStyle.wave,
                    icon: Icon(Icons.show_chart),
                    label: Text('Wave'),
                  ),
                  ButtonSegment(
                    value: VisualizerStyle.dots,
                    icon: Icon(Icons.more_horiz),
                    label: Text('Dots'),
                  ),
                  ButtonSegment(
                    value: VisualizerStyle.off,
                    icon: Icon(Icons.visibility_off_outlined),
                    label: Text('Off'),
                  ),
                ],
                selected: {style},
                onSelectionChanged: (sel) => ref
                    .read(visualizerStyleProvider.notifier)
                    .set(sel.first),
              ),
            );
          }),
        ],
      ),
    );
  }
}
