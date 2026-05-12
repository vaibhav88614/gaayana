import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/music_source/local_file_source.dart';
import '../../core/providers.dart';

/// Persistence helpers used both by this UI and by [LocalFileSource] at scan
/// time. Folders are stored as plain absolute paths in SharedPreferences.
class FolderFilterPrefs {
  static const includedKey = 'library.folders.included';
  static const excludedKey = 'library.folders.excluded';

  static List<String> _read(String key, dynamic prefs) {
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      return (jsonDecode(raw) as List).cast<String>();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> _write(String key, List<String> v, dynamic prefs) =>
      prefs.setString(key, jsonEncode(v));

  static List<String> included(dynamic prefs) => _read(includedKey, prefs);
  static List<String> excluded(dynamic prefs) => _read(excludedKey, prefs);

  /// Returns true if [filePath] should be kept after applying both lists.
  /// Include list (when non-empty) restricts to its subtrees; the exclude
  /// list is then applied on top.
  static bool keep(String filePath, dynamic prefs) {
    final inc = included(prefs);
    final exc = excluded(prefs);
    final norm = filePath.replaceAll('\\', '/');
    if (inc.isNotEmpty) {
      final ok = inc.any((d) => norm.startsWith(d.replaceAll('\\', '/')));
      if (!ok) return false;
    }
    for (final d in exc) {
      if (norm.startsWith(d.replaceAll('\\', '/'))) return false;
    }
    return true;
  }
}

class FoldersScreen extends ConsumerStatefulWidget {
  const FoldersScreen({super.key});
  @override
  ConsumerState<FoldersScreen> createState() => _FoldersScreenState();
}

class _FoldersScreenState extends ConsumerState<FoldersScreen> {
  late List<String> _included;
  late List<String> _excluded;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(sharedPrefsProvider);
    _included = [...FolderFilterPrefs.included(prefs)];
    _excluded = [...FolderFilterPrefs.excluded(prefs)];
  }

  Future<void> _save() async {
    final prefs = ref.read(sharedPrefsProvider);
    await FolderFilterPrefs._write(
        FolderFilterPrefs.includedKey, _included, prefs);
    await FolderFilterPrefs._write(
        FolderFilterPrefs.excludedKey, _excluded, prefs);
  }

  Future<void> _pick(bool include) async {
    final path = await FilePicker.platform.getDirectoryPath();
    if (path == null) return;
    if (!Directory(path).existsSync()) return;
    setState(() {
      final list = include ? _included : _excluded;
      if (!list.contains(path)) list.add(path);
    });
    await _save();
  }

  Future<void> _remove(bool include, String path) async {
    setState(() {
      (include ? _included : _excluded).remove(path);
    });
    await _save();
  }

  Future<void> _rescan() async {
    final src = ref.read(musicSourceProvider);
    if (src is LocalFileSource) {
      await src.listAll();
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rescanned library')),
      );
    }
  }

  Widget _section(String title, List<String> list, bool include) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(title,
                    style: Theme.of(context).textTheme.titleSmall),
              ),
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add folder'),
                onPressed: () => _pick(include),
              ),
            ],
          ),
        ),
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              include
                  ? 'When empty, the entire device is scanned.'
                  : 'Nothing excluded.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          for (final p in list)
            ListTile(
              leading: Icon(
                  include ? Icons.folder : Icons.folder_off_outlined),
              title: Text(p,
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => _remove(include, p),
              ),
            ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Music folders'),
        actions: [
          IconButton(
            tooltip: 'Rescan',
            icon: const Icon(Icons.refresh),
            onPressed: _rescan,
          ),
        ],
      ),
      body: ListView(
        children: [
          _section('Include only these folders', _included, true),
          const Divider(),
          _section('Exclude these folders', _excluded, false),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
