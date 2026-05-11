import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:rxdart/rxdart.dart';

import '../../core/db/app_database.dart';
import '../../core/models.dart';
import '../../core/music_source/music_source.dart';

enum DownloadStatus { queued, running, paused, complete, failed }

class DownloadTask {
  DownloadTask(this.track, {this.status = DownloadStatus.queued, this.progress = 0});
  final Track track;
  DownloadStatus status;
  double progress;
  CancelToken? cancelToken;
}

/// Download manager — requirement #5/#6.
///
/// Backed by `dio` (works on Android + iOS, no background-task surprises).
/// For very-long iOS downloads consider migrating to `flutter_downloader`'s
/// background isolate; here we keep it simple and reliable.
class DownloadManager {
  DownloadManager(this._db, this._dio);
  final AppDatabase _db;
  final Dio _dio;

  final BehaviorSubject<Map<String, DownloadTask>> _tasks =
      BehaviorSubject<Map<String, DownloadTask>>.seeded(const {});

  Stream<Map<String, DownloadTask>> get tasks => _tasks.stream;

  Future<void> enqueue(MusicSource source, Track track) async {
    final existing = await _db.downloadedPath(track.globalId);
    if (existing != null && File(existing).existsSync()) return;

    final url = await source.downloadUrl(track);
    if (url == null) return; // source forbids downloads

    final task = DownloadTask(track, status: DownloadStatus.running)
      ..cancelToken = CancelToken();
    _tasks.add({..._tasks.value, track.globalId: task});

    try {
      final dir = await getApplicationDocumentsDirectory();
      final musicDir = Directory(p.join(dir.path, 'music'));
      if (!musicDir.existsSync()) musicDir.createSync(recursive: true);
      final safe = '${track.artist}-${track.title}'
          .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final localPath = p.join(musicDir.path, '${track.globalId.hashCode}_$safe.audio');

      // Local-file source: just copy.
      if (url.startsWith('file://') || url.startsWith('/')) {
        final src = File(url.replaceFirst('file://', ''));
        await src.copy(localPath);
        task
          ..status = DownloadStatus.complete
          ..progress = 1.0;
      } else {
        await _dio.download(
          url,
          localPath,
          cancelToken: task.cancelToken,
          onReceiveProgress: (got, total) {
            if (total <= 0) return;
            task.progress = got / total;
            _tasks.add({..._tasks.value, track.globalId: task});
          },
        );
        task
          ..status = DownloadStatus.complete
          ..progress = 1.0;
      }

      final size = File(localPath).lengthSync();
      await _db.recordDownload(track.globalId, localPath, size);
    } catch (_) {
      task.status = DownloadStatus.failed;
    } finally {
      _tasks.add({..._tasks.value, track.globalId: task});
    }
  }

  void cancel(String globalId) {
    final t = _tasks.value[globalId];
    t?.cancelToken?.cancel('cancelled');
  }

  Future<bool> isDownloaded(String globalId) async =>
      (await _db.downloadedPath(globalId)) != null;
}
