import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../shared/widgets/album_art.dart';
import '../effects/effects_sheet.dart';
import '../sleep_timer/sleep_timer_sheet.dart';

/// Full-screen player. Album art, dynamic gradient, scrubber, transport,
/// loop/shuffle, route indicator, lyrics button, sleep timer.
class NowPlayingScreen extends ConsumerWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(currentTrackProvider).valueOrNull;
    final state = ref.watch(playbackStateProvider).valueOrNull;
    final position = ref.watch(positionProvider).valueOrNull ?? Duration.zero;
    final loop = ref.watch(loopModeProvider).valueOrNull ?? LoopMode.off;
    final shuffle = ref.watch(shuffleModeProvider).valueOrNull ?? false;
    final route = ref.watch(outputRouteProvider).valueOrNull;
    final handler = ref.read(audioHandlerProvider);
    final scheme = Theme.of(context).colorScheme;

    if (track == null) {
      return const Scaffold(
        body: Center(child: Text('Nothing playing')),
      );
    }

    final playing = state?.playing ?? false;
    final duration = Duration(milliseconds: track.durationMs);

    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) > 200) {
            Navigator.maybePop(context);
          }
        },
        child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              scheme.primaryContainer,
              scheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                _topBar(context, route),
                const Spacer(),
                AlbumArt(track: track, size: 320),
                const SizedBox(height: 32),
                Text(track.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(track.artist,
                    style: TextStyle(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 24),
                _scrubber(handler, position, duration),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_fmt(position),
                        style: TextStyle(color: scheme.onSurfaceVariant)),
                    Text(_fmt(duration),
                        style: TextStyle(color: scheme.onSurfaceVariant)),
                  ],
                ),
                const SizedBox(height: 12),
                _transport(handler, playing),
                const SizedBox(height: 8),
                _secondary(context, ref, loop, shuffle, handler),
                const Spacer(),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context, OutputRoute? route) {
    final scheme = Theme.of(context).colorScheme;
    IconData icon;
    String label;
    switch (route?.kind ?? OutputRouteKind.speaker) {
      case OutputRouteKind.bluetooth:
        icon = Icons.bluetooth_audio;
        label = route?.deviceName ?? 'Bluetooth';
      case OutputRouteKind.wired:
        icon = Icons.headphones;
        label = 'Headphones';
      case OutputRouteKind.cast:
        icon = Icons.cast_connected;
        label = route?.deviceName ?? 'Cast';
      case OutputRouteKind.speaker:
      case OutputRouteKind.unknown:
        icon = Icons.speaker;
        label = 'Speaker';
    }
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_down),
          onPressed: () => Navigator.maybePop(context),
        ),
        const Spacer(),
        Chip(
          avatar: Icon(icon, size: 18, color: scheme.primary),
          label: Text(label),
          visualDensity: VisualDensity.compact,
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.queue_music),
          tooltip: 'Up next',
          onPressed: () {}, // TODO: show queue
        ),
      ],
    );
  }

  Widget _scrubber(handler, Duration position, Duration duration) {
    final max = duration.inMilliseconds == 0
        ? 1.0
        : duration.inMilliseconds.toDouble();
    final v = position.inMilliseconds.toDouble().clamp(0.0, max);
    return Slider(
      min: 0,
      max: max,
      value: v,
      onChanged: (ms) => handler.seek(Duration(milliseconds: ms.toInt())),
    );
  }

  Widget _transport(handler, bool playing) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton.filledTonal(
          iconSize: 32,
          icon: const Icon(Icons.skip_previous),
          onPressed: handler.skipToPrevious,
        ),
        IconButton.filled(
          iconSize: 48,
          icon: Icon(playing ? Icons.pause : Icons.play_arrow),
          onPressed: () => playing ? handler.pause() : handler.play(),
        ),
        IconButton.filledTonal(
          iconSize: 32,
          icon: const Icon(Icons.skip_next),
          onPressed: handler.skipToNext,
        ),
      ],
    );
  }

  Widget _secondary(BuildContext context, WidgetRef ref, LoopMode loop,
      bool shuffle, handler) {
    final loopIcon = switch (loop) {
      LoopMode.off => Icons.repeat,
      LoopMode.one => Icons.repeat_one,
      LoopMode.all => Icons.repeat,
    };
    final loopColor = loop == LoopMode.off
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          tooltip: 'Shuffle',
          icon: Icon(Icons.shuffle,
              color: shuffle
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant),
          onPressed: () => handler.setShuffleEnabled(!shuffle),
        ),
        IconButton(
          tooltip: 'Loop',
          icon: Icon(loopIcon, color: loopColor),
          onPressed: () {
            final next = switch (loop) {
              LoopMode.off => LoopMode.all,
              LoopMode.all => LoopMode.one,
              LoopMode.one => LoopMode.off,
            };
            handler.setLoopMode(next);
          },
        ),
        IconButton(
          tooltip: 'Lyrics',
          icon: const Icon(Icons.lyrics_outlined),
          onPressed: () => Navigator.of(context).pushNamed('/lyrics'),
        ),
        IconButton(
          tooltip: 'Sleep timer',
          icon: const Icon(Icons.bedtime_outlined),
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            showDragHandle: true,
            builder: (_) => const SleepTimerSheet(),
          ),
        ),
        IconButton(
          tooltip: 'Effects',
          icon: const Icon(Icons.tune),
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            showDragHandle: true,
            isScrollControlled: true,
            builder: (_) => const EffectsSheet(),
          ),
        ),
      ],
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}
