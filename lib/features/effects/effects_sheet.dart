import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart' as ja;

import '../../core/providers.dart';

/// Bottom sheet exposing equalizer + speed + pitch + crossfade controls.
class EffectsSheet extends ConsumerStatefulWidget {
  const EffectsSheet({super.key});
  @override
  ConsumerState<EffectsSheet> createState() => _EffectsSheetState();
}

class _EffectsSheetState extends ConsumerState<EffectsSheet> {
  static const presets = <String, List<double>>{
    'Normal': [0, 0, 0, 0, 0],
    'Bass boost': [10, 6, 0, -2, -3],
    'Treble boost': [-3, -2, 0, 6, 10],
    'Vocal': [-2, 0, 6, 4, 0],
    'Rock': [6, 3, -3, 3, 6],
    'Jazz': [4, 2, -2, 2, 4],
    'Pop': [-1, 4, 6, 4, -1],
    'Classical': [4, 2, 0, 2, 4],
  };

  String _activePreset = 'Normal';

  @override
  Widget build(BuildContext context) {
    final handler = ref.read(audioHandlerProvider);
    final speed = ref.watch(speedProvider).valueOrNull ?? 1.0;
    final pitch = ref.watch(pitchProvider).valueOrNull ?? 1.0;
    final crossfade = ref.watch(crossfadeProvider).valueOrNull ?? Duration.zero;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Audio effects',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),

          // Equalizer presets
          Text('Equalizer presets',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final name in presets.keys)
                ChoiceChip(
                  label: Text(name),
                  selected: _activePreset == name,
                  onSelected: (_) async {
                    setState(() => _activePreset = name);
                    await _applyPreset(handler.equalizer, presets[name]!);
                  },
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Speed
          _Slider(
            label: 'Speed',
            value: speed,
            min: 0.5,
            max: 2.0,
            divisions: 30,
            display: '${speed.toStringAsFixed(2)}×',
            onChanged: handler.setSpeed,
            onReset: () => handler.setSpeed(1.0),
          ),

          // Pitch
          _Slider(
            label: 'Pitch',
            value: pitch,
            min: 0.5,
            max: 1.5,
            divisions: 20,
            display: pitch == 1.0 ? 'normal' : '${pitch.toStringAsFixed(2)}×',
            onChanged: handler.setPitch,
            onReset: () => handler.setPitch(1.0),
          ),

          // Crossfade
          _Slider(
            label: 'Crossfade',
            value: crossfade.inSeconds.toDouble(),
            min: 0,
            max: 12,
            divisions: 12,
            display: crossfade == Duration.zero
                ? 'off'
                : '${crossfade.inSeconds}s',
            onChanged: (v) =>
                handler.setCrossfade(Duration(seconds: v.round())),
            onReset: () => handler.setCrossfade(Duration.zero),
          ),
        ],
      ),
    );
  }

  Future<void> _applyPreset(
      ja.AndroidEqualizer eq, List<double> bandGainsDb) async {
    try {
      final isNormal = bandGainsDb.every((g) => g == 0);
      // For "Normal", disable the EQ entirely so the source signal passes
      // through untouched. Otherwise enable and apply the band gains.
      await eq.setEnabled(!isNormal);
      if (isNormal) return;
      final params = await eq.parameters;
      for (var i = 0; i < params.bands.length && i < bandGainsDb.length; i++) {
        await params.bands[i].setGain(bandGainsDb[i]);
      }
    } catch (_) {
      // Equalizer is Android-only; silently ignore on iOS / desktop.
    }
  }
}

class _Slider extends StatelessWidget {
  const _Slider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.display,
    required this.onChanged,
    required this.onReset,
  });
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String display;
  final ValueChanged<double> onChanged;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label,
                    style: Theme.of(context).textTheme.titleSmall),
              ),
              Text(display,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.primary)),
              IconButton(
                icon: const Icon(Icons.refresh, size: 18),
                tooltip: 'Reset',
                onPressed: onReset,
              ),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
