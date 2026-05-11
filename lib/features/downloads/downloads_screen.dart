import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/track_tile.dart';
import 'download_manager.dart';

final _dioProvider = Provider<Dio>((_) => Dio());

final downloadManagerProvider = Provider<DownloadManager>((ref) {
  return DownloadManager(ref.watch(databaseProvider), ref.watch(_dioProvider));
});

class DownloadsScreen extends ConsumerStatefulWidget {
  const DownloadsScreen({super.key});
  @override
  ConsumerState<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends ConsumerState<DownloadsScreen> {
  Future<List<Track>>? _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(databaseProvider).downloadedTracks();
  }

  @override
  Widget build(BuildContext context) {
    final addTrack = ModalRoute.of(context)?.settings.arguments as Track?;

    if (addTrack != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final mgr = ref.read(downloadManagerProvider);
        final src = ref.read(musicSourceProvider);
        await mgr.enqueue(src, addTrack);
        if (mounted) {
          setState(() =>
              _future = ref.read(databaseProvider).downloadedTracks());
        }
      });
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Downloads')),
      body: FutureBuilder<List<Track>>(
        future: _future,
        builder: (_, snap) {
          final list = snap.data ?? const [];
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.download_outlined,
              title: 'No offline songs yet',
              message: 'Tap the download icon on any track.',
            );
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (_, i) => TrackTile(track: list[i]),
          );
        },
      ),
    );
  }
}
