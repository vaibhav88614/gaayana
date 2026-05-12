import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

/// A lightweight procedural "visualizer". The Android Visualizer system API
/// requires `RECORD_AUDIO` permission, which is unfriendly for a music app, so
/// we synthesise an organic-looking bar animation driven by the player's
/// position and playing state instead. Looks like an EQ when music plays,
/// flat-lines when paused.
class AudioVisualizerBar extends ConsumerStatefulWidget {
  const AudioVisualizerBar({
    super.key,
    this.barCount = 24,
    this.height = 48,
  });
  final int barCount;
  final double height;

  @override
  ConsumerState<AudioVisualizerBar> createState() =>
      _AudioVisualizerBarState();
}

class _AudioVisualizerBarState extends ConsumerState<AudioVisualizerBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playbackStateProvider).valueOrNull;
    final playing = state?.playing ?? false;
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: widget.height,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final phase = _c.value * 2 * pi;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < widget.barCount; i++)
                _bar(i, phase, playing, scheme),
            ],
          );
        },
      ),
    );
  }

  Widget _bar(int i, double phase, bool playing, ColorScheme scheme) {
    // Smooth pseudo-random envelope using stacked sines so adjacent bars look
    // related (like real frequency bins) rather than pure noise.
    final f1 = sin(phase + i * 0.45);
    final f2 = sin(phase * 1.7 + i * 0.31 + _rng.nextDouble() * 0.0001);
    final f3 = sin(phase * 0.6 + i * 0.18);
    final env = (f1 + f2 * 0.7 + f3 * 0.5).abs() / 2.2;
    final amp = playing ? (0.15 + env * 0.85) : 0.04;
    final h = widget.height * amp;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      width: 3,
      height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        color: playing ? scheme.primary : scheme.outlineVariant,
      ),
    );
  }
}
