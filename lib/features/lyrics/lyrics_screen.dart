import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/lrclib_client.dart';
import '../../core/providers.dart';

/// Synced-lyrics view using LRCLIB. Karaoke-style auto-scroll.
class LyricsScreen extends ConsumerStatefulWidget {
  const LyricsScreen({super.key});
  @override
  ConsumerState<LyricsScreen> createState() => _LyricsScreenState();
}

class _LyricsScreenState extends ConsumerState<LyricsScreen> {
  List<LyricLine> _lines = const [];
  String? _plain;
  bool _loading = true;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool forceNetwork = false}) async {
    final track = ref.read(currentTrackProvider).valueOrNull;
    if (track == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    final db = ref.read(databaseProvider);
    final cacheKey = db.lyricsCacheKey(
        _stripTags(track.title), track.artist, track.album);

    // Try the cache first (unless the user explicitly tapped refresh).
    if (!forceNetwork) {
      final cached = await db.getCachedLyrics(cacheKey);
      if (cached != null &&
          ((cached.synced ?? '').isNotEmpty ||
              (cached.plain ?? '').isNotEmpty)) {
        if (!mounted) return;
        setState(() {
          _lines = (cached.synced ?? '').isNotEmpty
              ? parseLrc(cached.synced!)
              : const [];
          _plain = cached.plain;
          _loading = false;
        });
        return;
      }
    }

    final r = await ref.read(lrclibClientProvider).fetch(
          trackName: _stripTags(track.title),
          artistName: track.artist,
          albumName: track.album,
          durationSeconds: track.durationMs ~/ 1000,
        );
    if (!mounted) return;

    // Persist for offline use.
    if ((r.synced ?? '').isNotEmpty || (r.plain ?? '').isNotEmpty) {
      await db.cacheLyrics(cacheKey, synced: r.synced, plain: r.plain);
    }

    setState(() {
      _lines = r.synced != null ? parseLrc(r.synced!) : const [];
      _plain = r.plain;
      _loading = false;
    });
  }

  String _stripTags(String s) {
    // Drop "(Official Video)", "[Lyrics]", "feat. ...", file extensions, etc.
    return s
        .replaceAll(RegExp(r'\.(mp3|m4a|aac|ogg|flac|wav)$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*[\(\[][^)\]]*[\)\]]\s*'), ' ')
        .replaceAll(RegExp(r'\s+feat\.?\s+.*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final position = ref.watch(positionProvider).valueOrNull ?? Duration.zero;
    final track = ref.watch(currentTrackProvider).valueOrNull;
    final scheme = Theme.of(context).colorScheme;

    int activeIndex = -1;
    for (var i = 0; i < _lines.length; i++) {
      if (_lines[i].time <= position) activeIndex = i;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(track == null ? 'Lyrics' : '${track.title} — Lyrics',
            overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => _load(forceNetwork: true),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _lines.isEmpty && (_plain ?? '').isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lyrics_outlined,
                            size: 64, color: scheme.onSurfaceVariant),
                        const SizedBox(height: 12),
                        Text('No lyrics found',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text(
                          'LRCLIB has no match for "${track?.title ?? '?'}" by ${track?.artist ?? '?'}.\n'
                          'Check that the track metadata is correct.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                )
              : _lines.isNotEmpty
                  ? ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 32),
                      itemCount: _lines.length,
                      itemBuilder: (_, i) {
                        final active = i == activeIndex;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOutCubic,
                            style: TextStyle(
                              fontSize: active ? 22 : 16,
                              fontWeight:
                                  active ? FontWeight.w700 : FontWeight.w400,
                              color: active
                                  ? scheme.primary
                                  : scheme.onSurfaceVariant
                                      .withValues(alpha: 0.7),
                            ),
                            child: Text(_lines[i].text,
                                textAlign: TextAlign.center),
                          ),
                        );
                      },
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Text(_plain ?? '',
                          style: const TextStyle(fontSize: 16, height: 1.5)),
                    ),
    );
  }
}
