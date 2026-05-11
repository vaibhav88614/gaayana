import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../shared/widgets/album_art.dart';
import 'now_playing_screen.dart';

/// Persistent bottom bar that shows the current track and play/pause.
/// Tapping opens the Now-Playing screen.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(currentTrackProvider).valueOrNull;
    if (track == null) return const SizedBox.shrink();
    final state = ref.watch(playbackStateProvider).valueOrNull;
    final playing = state?.playing ?? false;
    final handler = ref.read(audioHandlerProvider);
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surfaceContainerHighest,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const NowPlayingScreen(),
        )),
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              const SizedBox(width: 8),
              AlbumArt(track: track, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(track.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                onPressed: () =>
                    playing ? handler.pause() : handler.play(),
              ),
              Consumer(builder: (context, ref, _) {
                final fav = ref.watch(isFavoriteProvider(track.globalId))
                        .valueOrNull ??
                    false;
                return IconButton(
                  tooltip: fav ? 'Remove from favorites' : 'Add to favorites',
                  icon: Icon(fav ? Icons.favorite : Icons.favorite_border,
                      color: fav ? Colors.redAccent : null),
                  onPressed: () async {
                    await ref
                        .read(databaseProvider)
                        .setFavorite(track.globalId, !fav);
                    ref.read(favoritesRefreshProvider.notifier).state++;
                  },
                );
              }),
              IconButton(
                icon: const Icon(Icons.skip_next),
                onPressed: handler.skipToNext,
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}
