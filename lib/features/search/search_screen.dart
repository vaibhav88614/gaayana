import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/track_tile.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _ctl = TextEditingController();
  List<Track> _results = const [];
  List<String> _history = const [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final h = await ref.read(databaseProvider).recentSearches();
    if (mounted) setState(() => _history = h);
  }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) {
      setState(() => _results = const []);
      return;
    }
    final db = ref.read(databaseProvider);
    final r = await db.search(q);
    await db.recordSearch(q);
    if (mounted) setState(() => _results = r);
  }

  @override
  Widget build(BuildContext context) {
    final handler = ref.read(audioHandlerProvider);
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _ctl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search songs, artists, albums',
            border: InputBorder.none,
          ),
          onChanged: _search,
          onSubmitted: _search,
        ),
        actions: [
          if (_ctl.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _ctl.clear();
                _search('');
              },
            ),
        ],
      ),
      body: _ctl.text.isEmpty
          ? ListView(
              children: [
                if (_history.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text('Recent searches',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  for (final q in _history)
                    ListTile(
                      leading: const Icon(Icons.history),
                      title: Text(q),
                      onTap: () {
                        _ctl.text = q;
                        _search(q);
                      },
                    ),
                ] else
                  const EmptyState(
                    icon: Icons.search,
                    title: 'Search your library',
                  ),
              ],
            )
          : _results.isEmpty
              ? const EmptyState(icon: Icons.search_off, title: 'No matches')
              : ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (_, i) => TrackTile(
                    track: _results[i],
                    onTap: () async {
                      await handler.setQueue(_results, initialIndex: i);
                      await handler.play();
                    },
                  ),
                ),
    );
  }
}
