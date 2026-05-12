import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/music_source/local_file_source.dart';
import '../../core/providers.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/track_tile.dart';
import '../player/mini_player.dart';

/// Main library screen with All / Artists / Albums / Genres tabs.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});
  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  bool _scanning = false;
  List<Track> _tracks = const [];
  List<Track> _recent = const [];
  List<Track> _mostPlayed = const [];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 6, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // On the very first launch, force a scan so we prompt for the
      // READ_MEDIA_AUDIO / storage permission immediately and populate the
      // library before the user has to hunt for the refresh button.
      final prefs = ref.read(sharedPrefsProvider);
      final firstRun = !(prefs.getBool('library.firstScanDone') ?? false);
      await _refresh(forceScan: firstRun);
      if (firstRun) await prefs.setBool('library.firstScanDone', true);
    });
  }

  Future<void> _refresh({bool forceScan = false}) async {
    final db = ref.read(databaseProvider);
    setState(() => _scanning = true);
    try {
      if (forceScan) {
        final source = ref.read(musicSourceProvider);
        await source.listAll();
      }
      _tracks = await db.allTracks();
      _recent = await db.recentlyPlayed(limit: 100);
      _mostPlayed = await db.mostPlayed(limit: 100);
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _playFrom(int index) async {
    final handler = ref.read(audioHandlerProvider);
    await handler.setQueue(_tracks, initialIndex: index);
    await handler.play();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Songs'),
            Tab(text: 'Recent'),
            Tab(text: 'Top'),
            Tab(text: 'Artists'),
            Tab(text: 'Albums'),
            Tab(text: 'Genres'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Search',
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.of(context).pushNamed('/search'),
          ),
          _ThemeToggleButton(),
          IconButton(
            tooltip: 'Refresh',
            icon: _scanning
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
            onPressed: _scanning ? null : () => _refresh(forceScan: true),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              switch (v) {
                case 'import':
                  _import();
                case 'playlists':
                  Navigator.of(context).pushNamed('/playlists');
                case 'favorites':
                  Navigator.of(context).pushNamed('/favorites');
                case 'downloads':
                  Navigator.of(context).pushNamed('/downloads');
                case 'settings':
                  Navigator.of(context).pushNamed('/settings');
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'import', child: Text('Import files…')),
              PopupMenuItem(value: 'playlists', child: Text('Playlists')),
              PopupMenuItem(value: 'favorites', child: Text('Favorites')),
              PopupMenuItem(value: 'downloads', child: Text('Downloads')),
              PopupMenuItem(value: 'settings', child: Text('Settings')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _songsTab(),
                _listTab(_recent, 'No recent plays yet',
                    Icons.history),
                _listTab(_mostPlayed, 'Play some music to see your top tracks',
                    Icons.local_fire_department_outlined),
                _groupedTab((t) => t.artist),
                _groupedTab((t) => t.album),
                _groupedTab((t) => t.genre ?? '—'),
              ],
            ),
          ),
          const MiniPlayer(),
        ],
      ),
    );
  }

  Widget _songsTab() {
    if (_tracks.isEmpty && !_scanning) {
      return EmptyState(
        icon: Icons.library_music_outlined,
        title: 'No music yet',
        message:
            'Grant media access and tap refresh, or import audio files manually.',
        action: FilledButton.icon(
          onPressed: () => _refresh(forceScan: true),
          icon: const Icon(Icons.refresh),
          label: const Text('Scan library'),
        ),
      );
    }
    return ListView.builder(
      itemCount: _tracks.length,
      itemBuilder: (_, i) => TrackTile(
        track: _tracks[i],
        onTap: () => _playFrom(i),
        onMore: () => _showTrackMenu(_tracks[i]),
      ),
    );
  }

  Widget _listTab(List<Track> list, String emptyMsg, IconData icon) {
    if (list.isEmpty) {
      return EmptyState(icon: icon, title: emptyMsg, message: '');
    }
    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (_, i) => TrackTile(
        track: list[i],
        onTap: () async {
          final handler = ref.read(audioHandlerProvider);
          await handler.setQueue(list, initialIndex: i);
          await handler.play();
        },
        onMore: () => _showTrackMenu(list[i]),
      ),
    );
  }

  Widget _groupedTab(String Function(Track) key) {
    if (_tracks.isEmpty) return _songsTab();
    final groups = <String, List<Track>>{};
    for (final t in _tracks) {
      groups.putIfAbsent(key(t), () => []).add(t);
    }
    final keys = groups.keys.toList()..sort();
    return ListView.builder(
      itemCount: keys.length,
      itemBuilder: (_, i) {
        final k = keys[i];
        final tracks = groups[k]!;
        return ExpansionTile(
          title: Text(k),
          subtitle: Text('${tracks.length} songs'),
          children: [
            for (final t in tracks)
              TrackTile(
                track: t,
                onTap: () {
                  final idx = _tracks.indexOf(t);
                  _playFrom(idx);
                },
              ),
          ],
        );
      },
    );
  }

  void _showTrackMenu(Track t) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => TrackActionSheet(track: t),
    );
  }

  Future<void> _import() async {
    final src = ref.read(musicSourceProvider);
    if (src is LocalFileSource) {
      await src.pickAndImport();
      await _refresh();
    }
  }
}

/// Actions that can be performed on any track from any list.
class TrackActionSheet extends ConsumerWidget {
  const TrackActionSheet({required this.track, super.key});
  final Track track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(databaseProvider);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.queue_music),
            title: const Text('Add to playlist'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).pushNamed('/playlists', arguments: track);
            },
          ),
          FutureBuilder<bool>(
            future: db.isFavorite(track.globalId),
            builder: (_, snap) {
              final fav = snap.data ?? false;
              return ListTile(
                leading: Icon(fav ? Icons.favorite : Icons.favorite_border),
                title: Text(fav ? 'Remove from favorites' : 'Add to favorites'),
                onTap: () async {
                  await db.setFavorite(track.globalId, !fav);
                  await ref
                      .read(firestoreSyncProvider)
                      ?.setFavorite(track.globalId, !fav);
                  if (context.mounted) Navigator.pop(context);
                },
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.radio),
            title: const Text('Start radio from this song'),
            onTap: () async {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text(
                        'Starting radio — needs a Last.fm API key in Settings.')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Download for offline'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).pushNamed('/downloads', arguments: track);
            },
          ),
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('Share'),
            onTap: () {
              Navigator.pop(context);
              // share_plus is available; we keep it lightweight here.
            },
          ),
        ],
      ),
    );
  }
}

class _ThemeToggleButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final (icon, tooltip) = switch (mode) {
      ThemeMode.system => (Icons.brightness_auto, 'Theme: system (tap for light)'),
      ThemeMode.light => (Icons.light_mode, 'Theme: light (tap for dark)'),
      ThemeMode.dark => (Icons.dark_mode, 'Theme: dark (tap for system)'),
    };
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon),
      onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
    );
  }
}
