import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart' as ja;

import '../../core/providers.dart';

/// Full-screen equalizer with one slider per detected band.
///
/// The Android system equalizer reports between 5 and 10 bands depending on
/// the device. This screen probes [AndroidEqualizerParameters] at runtime and
/// renders a slider per band, plus preset chips. Gains are persisted so the
/// settings survive an app restart.
class EqualizerScreen extends ConsumerStatefulWidget {
  const EqualizerScreen({super.key});
  @override
  ConsumerState<EqualizerScreen> createState() => _EqualizerScreenState();
}

class _EqualizerScreenState extends ConsumerState<EqualizerScreen> {
  ja.AndroidEqualizerParameters? _params;
  List<double> _gains = const [];
  bool _enabled = true;
  String _preset = 'Custom';
  Object? _initError;

  // Preset shapes are resampled to the actual band count at apply-time.
  static const _presetShapes = <String, List<double>>{
    'Normal': [0, 0, 0, 0, 0],
    'Bass boost': [10, 6, 0, -2, -3],
    'Treble boost': [-3, -2, 0, 6, 10],
    'Vocal': [-2, 0, 6, 4, 0],
    'Rock': [6, 3, -3, 3, 6],
    'Jazz': [4, 2, -2, 2, 4],
    'Pop': [-1, 4, 6, 4, -1],
    'Classical': [4, 2, 0, 2, 4],
    'Dance': [7, 5, 2, -2, -4],
    'Acoustic': [3, 3, 1, 0, 2],
  };

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final handler = ref.read(audioHandlerProvider);
    final prefs = ref.read(sharedPrefsProvider);
    try {
      await handler.equalizer.setEnabled(true);
      final p = await handler.equalizer.parameters;
      final n = p.bands.length;

      // Restore persisted gains if length matches.
      final stored = prefs.getString('eq.gains');
      List<double> gains = List<double>.filled(n, 0);
      if (stored != null) {
        try {
          final list = (jsonDecode(stored) as List).cast<num>();
          if (list.length == n) gains = list.map((e) => e.toDouble()).toList();
        } catch (_) {}
      }
      final enabled = prefs.getBool('eq.enabled') ?? true;
      _preset = prefs.getString('eq.preset') ?? 'Custom';
      _enabled = enabled;

      // Apply
      await handler.equalizer.setEnabled(enabled);
      for (var i = 0; i < n; i++) {
        await p.bands[i].setGain(gains[i]);
      }

      if (!mounted) return;
      setState(() {
        _params = p;
        _gains = gains;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _initError = e);
    }
  }

  Future<void> _persist() async {
    final prefs = ref.read(sharedPrefsProvider);
    await prefs.setString('eq.gains', jsonEncode(_gains));
    await prefs.setBool('eq.enabled', _enabled);
    await prefs.setString('eq.preset', _preset);
  }

  Future<void> _setBand(int i, double gainDb) async {
    if (_params == null) return;
    final p = _params!;
    final clamped = gainDb.clamp(p.minDecibels, p.maxDecibels);
    setState(() {
      _gains = [..._gains]..[i] = clamped;
      _preset = 'Custom';
    });
    await p.bands[i].setGain(clamped);
    await _persist();
  }

  Future<void> _applyPreset(String name) async {
    final shape = _presetShapes[name];
    if (shape == null || _params == null) return;
    final p = _params!;
    final n = p.bands.length;
    // Resample 5-point shape to n bands.
    final out = List<double>.filled(n, 0);
    for (var i = 0; i < n; i++) {
      final t = i / (n - 1).clamp(1, double.infinity);
      final src = t * (shape.length - 1);
      final lo = src.floor();
      final hi = (lo + 1).clamp(0, shape.length - 1);
      final frac = src - lo;
      out[i] = (shape[lo] * (1 - frac) + shape[hi] * frac)
          .clamp(p.minDecibels, p.maxDecibels)
          .toDouble();
    }
    setState(() {
      _preset = name;
      _gains = out;
    });
    final isNormal = name == 'Normal';
    await ref.read(audioHandlerProvider).equalizer.setEnabled(!isNormal && _enabled);
    if (!isNormal) {
      for (var i = 0; i < n; i++) {
        await p.bands[i].setGain(out[i]);
      }
    }
    if (isNormal) _enabled = false; else _enabled = true;
    setState(() {});
    await _persist();
  }

  Future<void> _toggle(bool v) async {
    final handler = ref.read(audioHandlerProvider);
    await handler.equalizer.setEnabled(v);
    setState(() => _enabled = v);
    await _persist();
  }

  String _formatHz(double hz) {
    if (hz >= 1000) return '${(hz / 1000).toStringAsFixed(hz % 1000 == 0 ? 0 : 1)}k';
    return hz.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    if (_initError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Equalizer')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Equalizer unavailable on this device.\n\n${_initError!}',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    final p = _params;
    if (p == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Equalizer')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final minDb = p.minDecibels;
    final maxDb = p.maxDecibels;

    return Scaffold(
      appBar: AppBar(
        title: Text('Equalizer (${p.bands.length} bands)'),
        actions: [
          Switch(value: _enabled, onChanged: _toggle),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final name in _presetShapes.keys)
                  ChoiceChip(
                    label: Text(name),
                    selected: _preset == name,
                    onSelected: (_) => _applyPreset(name),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < p.bands.length; i++)
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            '${_gains[i] >= 0 ? '+' : ''}${_gains[i].toStringAsFixed(1)} dB',
                            style: TextStyle(
                              color: scheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Expanded(
                            child: RotatedBox(
                              quarterTurns: 3,
                              child: Slider(
                                min: minDb,
                                max: maxDb,
                                value: _gains[i].clamp(minDb, maxDb),
                                onChanged: _enabled
                                    ? (v) => _setBand(i, v)
                                    : null,
                              ),
                            ),
                          ),
                          Text(
                            _formatHz(p.bands[i].centerFrequency),
                            style: TextStyle(
                              fontSize: 11,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
