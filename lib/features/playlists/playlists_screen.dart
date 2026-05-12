import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/track_tile.dart';

/// Lists playlists, lets the user create / rename / delete and add tracks.
class PlaylistsScreen extends ConsumerStatefulWidget {
  const PlaylistsScreen({super.key});
  @override
  ConsumerState<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends ConsumerState<PlaylistsScreen> {
  Future<List<Playlist>> _load() => ref.read(databaseProvider).allPlaylists();
  Future<List<Playlist>>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  void _refresh() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    final addTrack = ModalRoute.of(context)?.settings.arguments as Track?;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Playlists'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New playlist',
            onPressed: () => _createDialog(addTrack),
          ),
        ],
      ),
      body: FutureBuilder<List<Playlist>>(
        future: _future,
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data ?? const [];
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.queue_music,
              title: 'No playlists yet',
              message: 'Create one to organise your music.',
              action: FilledButton.icon(
                onPressed: () => _createDialog(addTrack),
                icon: const Icon(Icons.add),
                label: const Text('New playlist'),
              ),
            );
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (_, i) {
              final p = list[i];
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.queue_music)),
                title: Text(p.name),
                subtitle: Text('${p.trackIds.length} songs'),
                onTap: () async {
                  if (addTrack != null) {
                    await ref
                        .read(databaseProvider)
                        .addToPlaylist(p.id, addTrack.globalId);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Added to ${p.name}')));
                      Navigator.pop(context);
                    }
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlaylistDetailScreen(playlist: p),
                      ),
                    ).then((_) => _refresh());
                  }
                },
                trailing: PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'play') {
                      final tracks = await ref
                          .read(databaseProvider)
                          .playlistTracks(p.id);
                      if (tracks.isEmpty) return;
                      final handler = ref.read(audioHandlerProvider);
                      await handler.setQueue(tracks, initialIndex: 0);
                      await handler.play();
                    } else if (v == 'rename') {
                      final name = await _prompt('Rename playlist', p.name);
                      if (name != null) {
                        await ref
                            .read(databaseProvider)
                            .renamePlaylist(p.id, name);
                        _refresh();
                      }
                    } else if (v == 'delete') {
                      await ref.read(databaseProvider).deletePlaylist(p.id);
                      await ref
                          .read(firestoreSyncProvider)
                          ?.deletePlaylist(p.id);
                      _refresh();
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'play',
                      child: ListTile(
                        leading: Icon(Icons.play_arrow),
                        title: Text('Play all'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'rename',
                      child: ListTile(
                        leading: Icon(Icons.edit),
                        title: Text('Rename'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete_outline),
                        title: Text('Delete'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _createDialog(Track? addAfter) async {
    final name = await _prompt('New playlist', '');
    if (name == null || name.isEmpty) return;
    final id = await ref.read(databaseProvider).createPlaylist(name);
    if (addAfter != null) {
      await ref.read(databaseProvider).addToPlaylist(id, addAfter.globalId);
    }
    _refresh();
  }

  Future<String?> _prompt(String title, String initial) async {
    final ctl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(controller: ctl, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctl.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class PlaylistDetailScreen extends ConsumerStatefulWidget {
  const PlaylistDetailScreen({required this.playlist, super.key});
  final Playlist playlist;
  @override
  ConsumerState<PlaylistDetailScreen> createState() =>
      _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState
    extends ConsumerState<PlaylistDetailScreen> {
  Future<List<Track>>? _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(databaseProvider).playlistTracks(widget.playlist.id);
  }

  void _refresh() => setState(() => _future =
      ref.read(databaseProvider).playlistTracks(widget.playlist.id));

  @override
  Widget build(BuildContext context) {
    final handler = ref.read(audioHandlerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(widget.playlist.name)),
      floatingActionButton: FutureBuilder<List<Track>>(
        future: _future,
        builder: (_, snap) {
          final list = snap.data ?? const <Track>[];
          if (list.isEmpty) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            icon: const Icon(Icons.play_arrow),
            label: const Text('Play all'),
            onPressed: () async {
              await handler.setQueue(list, initialIndex: 0);
              await handler.play();
            },
          );
        },
      ),
      body: FutureBuilder<List<Track>>(
        future: _future,
        builder: (_, snap) {
          final list = snap.data ?? const [];
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.queue_music_outlined,
              title: 'Empty playlist',
              message: 'Add songs from the library.',
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
              trailing: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (v) async {
                  switch (v) {
                    case 'play':
                      await handler.setQueue(list, initialIndex: i);
                      await handler.play();
                      break;
                    case 'play_next':
                      await handler.appendToQueue([list[i]]);
                      break;
                    case 'remove':
                      await ref
                          .read(databaseProvider)
                          .removeFromPlaylist(
                              widget.playlist.id, list[i].globalId);
                      _refresh();
                      break;
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'play',
                    child: ListTile(
                      leading: Icon(Icons.play_arrow),
                      title: Text('Play'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'play_next',
                    child: ListTile(
                      leading: Icon(Icons.queue_play_next),
                      title: Text('Add to queue'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'remove',
                    child: ListTile(
                      leading: Icon(Icons.playlist_remove),
                      title: Text('Remove from playlist'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
