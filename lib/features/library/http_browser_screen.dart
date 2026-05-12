import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

/// Browse a remote HTTP(S) directory listing (the kind Apache / Nginx serve
/// when "Indexes" is enabled) and stream audio files directly. No paid API
/// or backend; works with any open file server.
///
/// Tap on a file ending in mp3/flac/m4a/ogg/wav/opus to play it.
class HttpBrowserScreen extends ConsumerStatefulWidget {
  const HttpBrowserScreen({super.key});
  @override
  ConsumerState<HttpBrowserScreen> createState() => _HttpBrowserScreenState();
}

class _HttpBrowserScreenState extends ConsumerState<HttpBrowserScreen> {
  final _urlCtl = TextEditingController();
  bool _loading = false;
  String? _error;
  Uri? _current;
  List<_Entry> _entries = const [];

  static final _audioExt = RegExp(
    r'\.(mp3|m4a|mp4|aac|ogg|opus|flac|wav|wma)$',
    caseSensitive: false,
  );
  static final _hrefRegex = RegExp(
    r'''<a\s+href=["']([^"']+)["']''',
    caseSensitive: false,
  );

  Future<void> _load(String url) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
      ));
      final r = await dio.get<String>(
        url,
        options: Options(responseType: ResponseType.plain),
      );
      final html = r.data ?? '';
      final base = Uri.parse(url);
      final found = <_Entry>{};
      for (final m in _hrefRegex.allMatches(html)) {
        final href = m.group(1)!;
        if (href.startsWith('?') || href == '/' || href.startsWith('#')) {
          continue;
        }
        final abs = base.resolve(href);
        // Only show same-host children (avoid linking to the wider web).
        if (abs.host != base.host) continue;
        // Skip the parent shortcut entries themselves; we'll add our own.
        if (abs.toString() == base.toString()) continue;
        final isDir = href.endsWith('/');
        final isAudio = _audioExt.hasMatch(href);
        if (!isDir && !isAudio) continue;
        found.add(_Entry(
          name: Uri.decodeComponent(href.replaceAll(RegExp(r'/$'), '')),
          url: abs.toString(),
          isDirectory: isDir,
        ));
      }
      final list = found.toList()
        ..sort((a, b) {
          if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
      setState(() {
        _current = base;
        _entries = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _open(_Entry e) async {
    if (e.isDirectory) {
      await _load(e.url);
      return;
    }
    final handler = ref.read(audioHandlerProvider);
    await handler.playUrl(e.url, title: e.name);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Playing ${e.name}')),
      );
    }
  }

  void _goUp() {
    final c = _current;
    if (c == null) return;
    final parent = c.replace(
      pathSegments: c.pathSegments.where((s) => s.isNotEmpty).toList()
        ..removeLast(),
    );
    _load(parent.toString().endsWith('/')
        ? parent.toString()
        : '${parent.toString()}/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HTTP browser'),
        actions: [
          if (_current != null)
            IconButton(
              tooltip: 'Up',
              icon: const Icon(Icons.arrow_upward),
              onPressed: _goUp,
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlCtl,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      hintText: 'https://example.com/music/',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: _load,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Go'),
                  onPressed: () => _load(_urlCtl.text.trim()),
                ),
              ],
            ),
          ),
          if (_current != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _current.toString(),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_error!,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error)),
            ),
          Expanded(
            child: _entries.isEmpty && !_loading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Paste any open directory URL (Apache / Nginx style) '
                        'such as https://server/music/ and tap Go.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _entries.length,
                    itemBuilder: (_, i) {
                      final e = _entries[i];
                      return ListTile(
                        leading: Icon(e.isDirectory
                            ? Icons.folder
                            : Icons.music_note),
                        title: Text(e.name,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(e.url,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        onTap: () => _open(e),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _Entry {
  const _Entry(
      {required this.name, required this.url, required this.isDirectory});
  final String name;
  final String url;
  final bool isDirectory;

  @override
  bool operator ==(Object other) =>
      other is _Entry && other.url == url;
  @override
  int get hashCode => url.hashCode;
}
