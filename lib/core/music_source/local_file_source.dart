import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';

import '../db/app_database.dart';
import '../models.dart';
import 'music_source.dart';

/// First [MusicSource] implementation: scans the device music library and
/// supports manual import of audio files via the system file picker.
///
/// 100% legal, 100% offline-capable. This is the default source until a
/// streaming provider is configured.
class LocalFileSource extends MusicSource {
  LocalFileSource(this._db);
  final AppDatabase _db;
  final OnAudioQuery _query = OnAudioQuery();

  @override
  String get id => 'local';

  @override
  String get displayName => 'On this device';

  @override
  bool get isOnline => false;

  /// Request the appropriate permission for the platform and SDK level.
  Future<bool> ensurePermission() async {
    if (Platform.isAndroid) {
      // Android 13+ uses READ_MEDIA_AUDIO; older uses storage.
      final audio = await Permission.audio.request();
      if (audio.isGranted) return true;
      final storage = await Permission.storage.request();
      return storage.isGranted;
    } else if (Platform.isIOS) {
      final media = await Permission.mediaLibrary.request();
      return media.isGranted;
    }
    return true;
  }

  @override
  Future<List<Track>> listAll() async {
    if (!await ensurePermission()) return [];
    final songs = await _query.querySongs(
      sortType: SongSortType.TITLE,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );

    final tracks = <Track>[];
    for (final s in songs) {
      // Skip ringtones, alarms, and very short clips.
      if ((s.duration ?? 0) < 20 * 1000) continue;
      if (s.isMusic == false) continue;
      tracks.add(_fromSongModel(s));
    }
    await _db.upsertTracks(tracks);
    return tracks;
  }

  Track _fromSongModel(SongModel s) {
    // Album art is fetched lazily via OnAudioQuery.queryArtwork(id) — we store
    // a sentinel URI that the UI layer recognises.
    return Track(
      id: s.id.toString(),
      sourceId: id,
      title: s.title,
      artist: s.artist ?? 'Unknown artist',
      album: s.album ?? 'Unknown album',
      durationMs: s.duration ?? 0,
      uri: s.uri ?? s.data,
      albumArtUri: 'audioquery://${s.id}',
      genre: s.genre,
      year: int.tryParse(s.composer ?? ''),
      trackNumber: s.track,
    );
  }

  @override
  Future<Track?> resolve(String trackId) async {
    return _db.trackByGlobalId('$id::$trackId');
  }

  @override
  Future<List<Track>> search(String query) => _db.search(query);

  /// User-initiated import — adds files outside the system-indexed media store.
  Future<List<Track>> pickAndImport() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
    );
    if (result == null) return [];

    final tracks = <Track>[];
    for (final f in result.files) {
      if (f.path == null) continue;
      final filename = f.name;
      tracks.add(Track(
        id: 'import_${filename.hashCode}_${f.size}',
        sourceId: id,
        title: filename.replaceAll(RegExp(r'\.[^.]+$'), ''),
        artist: 'Imported',
        album: 'Imported',
        durationMs: 0, // resolved on first play by just_audio
        uri: 'file://${f.path}',
      ));
    }
    await _db.upsertTracks(tracks);
    return tracks;
  }
}
