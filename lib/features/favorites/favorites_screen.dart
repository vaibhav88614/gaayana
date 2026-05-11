import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/track_tile.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});
  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  late Future<List<Track>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(databaseProvider).favoriteTracks();
  }

  void _reload() => setState(() {
        _future = ref.read(databaseProvider).favoriteTracks();
      });

  @override
  Widget build(BuildContext context) {
    final handler = ref.read(audioHandlerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Favorites')),
      body: FutureBuilder<List<Track>>(
        future: _future,
        builder: (_, snap) {
          final list = snap.data ?? const [];
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.favorite_border,
              title: 'No favorites yet',
              message: 'Tap the heart on any song to add it here.',
            );
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (_, i) => TrackTile(
              track: list[i],
              onTap: () async {
                await handler.setQueue(list, initialIndex: i);
                await handler.play();
              },
              trailing: IconButton(
                icon: const Icon(Icons.favorite),
                color: Theme.of(context).colorScheme.primary,
                onPressed: () async {
                  await ref
                      .read(databaseProvider)
                      .setFavorite(list[i].globalId, false);
                  await ref
                      .read(firestoreSyncProvider)
                      ?.setFavorite(list[i].globalId, false);
                  _reload();
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
