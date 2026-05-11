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

  Future<void> _load() async {
    final track = ref.read(currentTrackProvider).valueOrNull;
    if (track == null) {
      setState(() => _loading = false);
      return;
    }
    final r = await ref.read(lrclibClientProvider).fetch(
          trackName: track.title,
          artistName: track.artist,
          albumName: track.album,
          durationSeconds: track.durationMs ~/ 1000,
        );
    if (!mounted) return;
    setState(() {
      _lines = r.synced != null ? parseLrc(r.synced!) : const [];
      _plain = r.plain;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final position = ref.watch(positionProvider).valueOrNull ?? Duration.zero;
    final scheme = Theme.of(context).colorScheme;

    int activeIndex = -1;
    for (var i = 0; i < _lines.length; i++) {
      if (_lines[i].time <= position) activeIndex = i;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Lyrics')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _lines.isEmpty && (_plain ?? '').isEmpty
              ? const Center(child: Text('No lyrics found.'))
              : _lines.isNotEmpty
                  ? ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 32),
                      itemCount: _lines.length,
                      itemBuilder: (_, i) {
                        final active = i == activeIndex;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            _lines[i].text,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: active ? 22 : 18,
                              fontWeight:
                                  active ? FontWeight.w700 : FontWeight.w400,
                              color: active
                                  ? scheme.primary
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        );
                      },
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child:
                          Text(_plain ?? '', style: const TextStyle(fontSize: 16)),
                    ),
    );
  }
}
