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
                const _ArtCarousel(),
                const SizedBox(height: 32),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(track.title,
                      key: ValueKey<String>('t-${track.globalId}'),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 6),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(track.artist,
                      key: ValueKey<String>('a-${track.globalId}'),
                      style: TextStyle(color: scheme.onSurfaceVariant)),
                ),
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
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            showDragHandle: true,
            isScrollControlled: true,
            builder: (_) => const _QueueSheet(),
          ),
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
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, anim) => ScaleTransition(
              scale: anim,
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: Icon(
              playing ? Icons.pause : Icons.play_arrow,
              key: ValueKey<bool>(playing),
            ),
          ),
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
    final sleepActive = ref.watch(sleepTimerProvider).isActive;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ToggleIconButton(
          tooltip: 'Shuffle',
          icon: Icons.shuffle,
          active: shuffle,
          onPressed: () => handler.setShuffleEnabled(!shuffle),
        ),
        _ToggleIconButton(
          tooltip: 'Loop',
          icon: loopIcon,
          active: loop != LoopMode.off,
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
        _ToggleIconButton(
          tooltip: 'Sleep timer',
          icon: Icons.bedtime_outlined,
          active: sleepActive,
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

/// Swipeable carousel of album-art for the active queue. Swiping a page calls
/// [GaayanaAudioHandler.skipToQueueItem]; the player's index drives the
/// carousel back in sync when the song changes naturally.
class _ArtCarousel extends ConsumerStatefulWidget {
  const _ArtCarousel();
  @override
  ConsumerState<_ArtCarousel> createState() => _ArtCarouselState();
}

class _ArtCarouselState extends ConsumerState<_ArtCarousel> {
  late final PageController _controller;
  int _expectedIndex = -1;

  @override
  void initState() {
    super.initState();
    final handler = ref.read(audioHandlerProvider);
    _expectedIndex = handler.player.currentIndex ?? 0;
    _controller = PageController(initialPage: _expectedIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _syncToPlayer(int playerIndex) {
    if (!_controller.hasClients) return;
    if (playerIndex == _expectedIndex) return;
    _expectedIndex = playerIndex;
    _controller.animateToPage(
      playerIndex,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final handler = ref.read(audioHandlerProvider);
    final queue = ref.watch(queueProvider).valueOrNull ?? const <Track>[];
    final currentIdx = handler.player.currentIndex ?? 0;

    // Whenever the player index changes externally (autoplay / notification),
    // animate the PageView to it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncToPlayer(currentIdx);
    });

    if (queue.isEmpty) {
      return const SizedBox(width: 320, height: 320);
    }

    return SizedBox(
      height: 320,
      child: PageView.builder(
        controller: _controller,
        itemCount: queue.length,
        onPageChanged: (i) async {
          if (i == _expectedIndex) return;
          _expectedIndex = i;
          await handler.skipToQueueItem(i);
        },
        itemBuilder: (_, i) {
          final t = queue[i];
          return Center(
            child: AlbumArt(
              track: t,
              size: 320,
              heroTag: i == currentIdx ? 'nowPlayingArt' : null,
            ),
          );
        },
      ),
    );
  }
}

/// IconButton that visibly highlights when [active] is true.
class _ToggleIconButton extends StatelessWidget {
  const _ToggleIconButton({
    required this.icon,
    required this.active,
    required this.onPressed,
    required this.tooltip,
  });
  final IconData icon;
  final bool active;
  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active
              ? scheme.primary.withValues(alpha: 0.22)
              : Colors.transparent,
        ),
        child: IconButton(
          icon: Icon(
            icon,
            color: active ? scheme.primary : scheme.onSurfaceVariant,
          ),
          onPressed: onPressed,
        ),
      ),
    );
  }
}

/// Bottom-sheet showing the active queue with tap-to-jump.
class _QueueSheet extends ConsumerWidget {
  const _QueueSheet();

  Future<void> _saveAsPlaylist(
      BuildContext context, WidgetRef ref, List<Track> queue) async {
    final ctl = TextEditingController(
      text: 'Queue ${DateTime.now().toString().substring(5, 16)}',
    );
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Save queue as playlist'),
        content: TextField(controller: ctl, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final db = ref.read(databaseProvider);
    final id = await db.createPlaylist(name);
    for (final t in queue) {
      await db.addToPlaylist(id, t.globalId);
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved "$name" with ${queue.length} songs')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(queueProvider).valueOrNull ?? const <Track>[];
    final current = ref.watch(currentTrackProvider).valueOrNull;
    final handler = ref.read(audioHandlerProvider);
    final scheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (_, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Text('Up next',
                    style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                Text('${queue.length} songs',
                    style: TextStyle(color: scheme.onSurfaceVariant)),
                IconButton(
                  tooltip: 'Save as playlist',
                  icon: const Icon(Icons.playlist_add),
                  onPressed: queue.isEmpty
                      ? null
                      : () => _saveAsPlaylist(context, ref, queue),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ReorderableListView.builder(
              scrollController: controller,
              buildDefaultDragHandles: false,
              itemCount: queue.length,
              onReorder: (from, to) {
                // ReorderableListView increments `to` once past `from`; undo.
                final target = to > from ? to - 1 : to;
                handler.moveQueueItem(from, target);
              },
              itemBuilder: (_, i) {
                final t = queue[i];
                final selected = current?.globalId == t.globalId;
                return Dismissible(
                  key: ValueKey('q-${t.globalId}-$i'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    color: scheme.errorContainer,
                    child: Icon(Icons.delete_outline,
                        color: scheme.onErrorContainer),
                  ),
                  onDismissed: (_) => handler.removeAt(i),
                  child: ListTile(
                    selected: selected,
                    selectedTileColor:
                        scheme.primaryContainer.withValues(alpha: 0.4),
                    leading: AlbumArt(track: t, size: 40),
                    title: Text(t.title,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(t.artist,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: ReorderableDragStartListener(
                      index: i,
                      child: Icon(Icons.drag_handle,
                          color: scheme.onSurfaceVariant),
                    ),
                    onTap: () async {
                      await handler.skipToQueueItem(i);
                      await handler.play();
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
