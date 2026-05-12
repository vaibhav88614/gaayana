import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

/// A lightweight procedural "visualizer". The Android Visualizer system API
/// requires `RECORD_AUDIO` permission, which is unfriendly for a music app, so
/// we synthesise an organic-looking animation driven by the player's
/// position and playing state instead.
///
/// The rendered style is user-selectable via [visualizerStyleProvider]:
///   * [VisualizerStyle.bars] — classic EQ-style bars (default).
///   * [VisualizerStyle.wave] — smooth flowing sine wave.
///   * [VisualizerStyle.dots] — row of pulsing circular dots.
///   * [VisualizerStyle.off]  — hidden.
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
    final style = ref.watch(visualizerStyleProvider);
    if (style == VisualizerStyle.off) return const SizedBox.shrink();

    final state = ref.watch(playbackStateProvider).valueOrNull;
    final playing = state?.playing ?? false;
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: widget.height,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final phase = _c.value * 2 * pi;
          switch (style) {
            case VisualizerStyle.bars:
              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 0; i < widget.barCount; i++)
                    _bar(i, phase, playing, scheme),
                ],
              );
            case VisualizerStyle.dots:
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 0; i < widget.barCount; i++)
                    _dot(i, phase, playing, scheme),
                ],
              );
            case VisualizerStyle.wave:
              return CustomPaint(
                size: Size.infinite,
                painter: _WavePainter(
                  phase: phase,
                  playing: playing,
                  color: playing ? scheme.primary : scheme.outlineVariant,
                ),
              );
            case VisualizerStyle.off:
              return const SizedBox.shrink();
          }
        },
      ),
    );
  }

  double _envelope(int i, double phase) {
    final f1 = sin(phase + i * 0.45);
    final f2 = sin(phase * 1.7 + i * 0.31 + _rng.nextDouble() * 0.0001);
    final f3 = sin(phase * 0.6 + i * 0.18);
    return (f1 + f2 * 0.7 + f3 * 0.5).abs() / 2.2;
  }

  Widget _bar(int i, double phase, bool playing, ColorScheme scheme) {
    final env = _envelope(i, phase);
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

  Widget _dot(int i, double phase, bool playing, ColorScheme scheme) {
    final env = _envelope(i, phase);
    final size = playing
        ? (widget.height * 0.25 + env * widget.height * 0.5)
        : widget.height * 0.18;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: playing ? scheme.primary : scheme.outlineVariant,
      ),
    );
  }
}

/// Smooth two-octave sine wave that flat-lines when paused.
class _WavePainter extends CustomPainter {
  _WavePainter({
    required this.phase,
    required this.playing,
    required this.color,
  });
  final double phase;
  final bool playing;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final mid = size.height / 2;
    final amp = playing ? size.height * 0.42 : 1.0;
    final path = Path();
    const steps = 64;
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final x = t * size.width;
      final y = mid +
          sin(phase + t * 4 * pi) * amp * 0.6 +
          sin(phase * 1.7 + t * 6 * pi) * amp * 0.4;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) =>
      old.phase != phase || old.playing != playing || old.color != color;
}
