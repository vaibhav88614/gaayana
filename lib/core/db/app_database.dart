import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models.dart';

/// Lightweight SQLite wrapper. We deliberately avoid Drift codegen so the
/// project compiles immediately after `flutter pub get` without `build_runner`.
class AppDatabase {
  AppDatabase._(this._db);
  final Database _db;

  static AppDatabase? _instance;
  static Future<AppDatabase> open() async {
    if (_instance != null) return _instance!;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'gaayana.db');
    final db = await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
    return _instance = AppDatabase._(db);
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE tracks(
        global_id TEXT PRIMARY KEY,
        source_id TEXT NOT NULL,
        local_id  TEXT NOT NULL,
        title     TEXT NOT NULL,
        artist    TEXT NOT NULL,
        album     TEXT NOT NULL,
        duration_ms INTEGER NOT NULL,
        uri       TEXT NOT NULL,
        album_art_uri TEXT,
        genre     TEXT,
        year      INTEGER,
        track_number INTEGER
      );
    ''');
    await db.execute('CREATE INDEX idx_tracks_artist ON tracks(artist);');
    await db.execute('CREATE INDEX idx_tracks_album  ON tracks(album);');
    await db.execute('CREATE INDEX idx_tracks_genre  ON tracks(genre);');

    await db.execute('''
      CREATE TABLE playlists(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        cover_uri TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
    ''');
    await db.execute('''
      CREATE TABLE playlist_tracks(
        playlist_id TEXT NOT NULL,
        track_global_id TEXT NOT NULL,
        position INTEGER NOT NULL,
        PRIMARY KEY (playlist_id, track_global_id),
        FOREIGN KEY (playlist_id) REFERENCES playlists(id) ON DELETE CASCADE
      );
    ''');
    await db.execute('''
      CREATE TABLE favorites(
        track_global_id TEXT PRIMARY KEY,
        added_at INTEGER NOT NULL
      );
    ''');
    await db.execute('''
      CREATE TABLE play_history(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        track_global_id TEXT NOT NULL,
        played_at INTEGER NOT NULL,
        completed INTEGER NOT NULL DEFAULT 0
      );
    ''');
    await db.execute('''
      CREATE TABLE play_counts(
        track_global_id TEXT PRIMARY KEY,
        count INTEGER NOT NULL DEFAULT 0,
        last_played_at INTEGER
      );
    ''');
    await db.execute('''
      CREATE TABLE downloads(
        track_global_id TEXT PRIMARY KEY,
        local_path TEXT NOT NULL,
        size_bytes INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL,
        downloaded_at INTEGER
      );
    ''');
    await db.execute('''
      CREATE TABLE search_history(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        query TEXT NOT NULL,
        searched_at INTEGER NOT NULL
      );
    ''');
  }

  // ---- Tracks ----------------------------------------------------------------

  Future<void> upsertTracks(Iterable<Track> tracks) async {
    final batch = _db.batch();
    for (final t in tracks) {
      batch.insert(
        'tracks',
        {
          'global_id': t.globalId,
          'source_id': t.sourceId,
          'local_id': t.id,
          'title': t.title,
          'artist': t.artist,
          'album': t.album,
          'duration_ms': t.durationMs,
          'uri': t.uri,
          'album_art_uri': t.albumArtUri,
          'genre': t.genre,
          'year': t.year,
          'track_number': t.trackNumber,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Track>> allTracks({String orderBy = 'title COLLATE NOCASE'}) async {
    final rows = await _db.query('tracks', orderBy: orderBy);
    return rows.map(_rowToTrack).toList();
  }

  Future<Track?> trackByGlobalId(String globalId) async {
    final rows =
        await _db.query('tracks', where: 'global_id = ?', whereArgs: [globalId]);
    if (rows.isEmpty) return null;
    return _rowToTrack(rows.first);
  }

  Future<List<Track>> search(String query, {int limit = 50}) async {
    final q = '%${query.toLowerCase()}%';
    final rows = await _db.rawQuery(
      '''SELECT * FROM tracks
         WHERE LOWER(title) LIKE ? OR LOWER(artist) LIKE ? OR LOWER(album) LIKE ?
         ORDER BY title COLLATE NOCASE
         LIMIT ?''',
      [q, q, q, limit],
    );
    return rows.map(_rowToTrack).toList();
  }

  Future<List<String>> allGenres() async {
    final rows = await _db.rawQuery(
        'SELECT DISTINCT genre FROM tracks WHERE genre IS NOT NULL ORDER BY genre');
    return rows.map((r) => r['genre'] as String).toList();
  }

  Future<List<String>> allArtists() async {
    final rows = await _db.rawQuery(
        'SELECT DISTINCT artist FROM tracks ORDER BY artist COLLATE NOCASE');
    return rows.map((r) => r['artist'] as String).toList();
  }

  Future<List<String>> allAlbums() async {
    final rows = await _db.rawQuery(
        'SELECT DISTINCT album FROM tracks ORDER BY album COLLATE NOCASE');
    return rows.map((r) => r['album'] as String).toList();
  }

  Future<List<Track>> tracksByGenre(String genre) async {
    final rows = await _db
        .query('tracks', where: 'genre = ?', whereArgs: [genre]);
    return rows.map(_rowToTrack).toList();
  }

  Track _rowToTrack(Map<String, Object?> r) => Track(
        id: r['local_id'] as String,
        sourceId: r['source_id'] as String,
        title: r['title'] as String,
        artist: r['artist'] as String,
        album: r['album'] as String,
        durationMs: r['duration_ms'] as int,
        uri: r['uri'] as String,
        albumArtUri: r['album_art_uri'] as String?,
        genre: r['genre'] as String?,
        year: r['year'] as int?,
        trackNumber: r['track_number'] as int?,
      );

  // ---- Favorites -------------------------------------------------------------

  Future<bool> isFavorite(String globalId) async {
    final rows = await _db.query('favorites',
        where: 'track_global_id = ?', whereArgs: [globalId], limit: 1);
    return rows.isNotEmpty;
  }

  Future<void> setFavorite(String globalId, bool value) async {
    if (value) {
      await _db.insert(
        'favorites',
        {
          'track_global_id': globalId,
          'added_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      await _db.delete('favorites',
          where: 'track_global_id = ?', whereArgs: [globalId]);
    }
  }

  Future<List<Track>> favoriteTracks() async {
    final rows = await _db.rawQuery('''
      SELECT t.* FROM tracks t
      INNER JOIN favorites f ON f.track_global_id = t.global_id
      ORDER BY f.added_at DESC
    ''');
    return rows.map(_rowToTrack).toList();
  }

  // ---- Playlists -------------------------------------------------------------

  Future<String> createPlaylist(String name, {String? coverUri}) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.insert('playlists', {
      'id': id,
      'name': name,
      'cover_uri': coverUri,
      'created_at': now,
      'updated_at': now,
    });
    return id;
  }

  Future<void> renamePlaylist(String id, String newName) async {
    await _db.update(
      'playlists',
      {
        'name': newName,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deletePlaylist(String id) async {
    await _db.delete('playlists', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Playlist>> allPlaylists() async {
    final rows = await _db.query('playlists', orderBy: 'updated_at DESC');
    final result = <Playlist>[];
    for (final r in rows) {
      final tracks = await _db.query(
        'playlist_tracks',
        where: 'playlist_id = ?',
        whereArgs: [r['id']],
        orderBy: 'position ASC',
      );
      result.add(Playlist(
        id: r['id'] as String,
        name: r['name'] as String,
        coverUri: r['cover_uri'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(r['updated_at'] as int),
        trackIds:
            tracks.map((e) => e['track_global_id'] as String).toList(growable: false),
      ));
    }
    return result;
  }

  Future<void> addToPlaylist(String playlistId, String trackGlobalId) async {
    final existing = await _db.query(
      'playlist_tracks',
      where: 'playlist_id = ?',
      whereArgs: [playlistId],
      orderBy: 'position DESC',
      limit: 1,
    );
    final pos = existing.isEmpty ? 0 : (existing.first['position'] as int) + 1;
    await _db.insert(
      'playlist_tracks',
      {
        'playlist_id': playlistId,
        'track_global_id': trackGlobalId,
        'position': pos,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    await _db.update(
      'playlists',
      {'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [playlistId],
    );
  }

  Future<void> removeFromPlaylist(String playlistId, String trackGlobalId) async {
    await _db.delete(
      'playlist_tracks',
      where: 'playlist_id = ? AND track_global_id = ?',
      whereArgs: [playlistId, trackGlobalId],
    );
  }

  Future<List<Track>> playlistTracks(String playlistId) async {
    final rows = await _db.rawQuery('''
      SELECT t.* FROM tracks t
      INNER JOIN playlist_tracks pt ON pt.track_global_id = t.global_id
      WHERE pt.playlist_id = ?
      ORDER BY pt.position ASC
    ''', [playlistId]);
    return rows.map(_rowToTrack).toList();
  }

  // ---- Play counts & history ------------------------------------------------

  Future<void> recordPlay(String globalId, {bool completed = false}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.insert('play_history', {
      'track_global_id': globalId,
      'played_at': now,
      'completed': completed ? 1 : 0,
    });
    await _db.rawInsert('''
      INSERT INTO play_counts(track_global_id, count, last_played_at)
      VALUES (?, 1, ?)
      ON CONFLICT(track_global_id) DO UPDATE SET
        count = count + 1,
        last_played_at = excluded.last_played_at
    ''', [globalId, now]);
  }

  Future<int> playCount(String globalId) async {
    final rows = await _db.query('play_counts',
        where: 'track_global_id = ?', whereArgs: [globalId]);
    return rows.isEmpty ? 0 : rows.first['count'] as int;
  }

  Future<Map<String, int>> allPlayCounts() async {
    final rows = await _db.query('play_counts');
    return {
      for (final r in rows) r['track_global_id'] as String: r['count'] as int,
    };
  }

  Future<List<Track>> recentlyPlayed({int limit = 50}) async {
    final rows = await _db.rawQuery('''
      SELECT t.*, MAX(h.played_at) as last_at FROM tracks t
      INNER JOIN play_history h ON h.track_global_id = t.global_id
      GROUP BY t.global_id
      ORDER BY last_at DESC
      LIMIT ?
    ''', [limit]);
    return rows.map(_rowToTrack).toList();
  }

  Future<List<Track>> mostPlayed({int limit = 50}) async {
    final rows = await _db.rawQuery('''
      SELECT t.*, p.count as cnt FROM tracks t
      INNER JOIN play_counts p ON p.track_global_id = t.global_id
      WHERE p.count > 0
      ORDER BY p.count DESC, p.last_played_at DESC
      LIMIT ?
    ''', [limit]);
    return rows.map(_rowToTrack).toList();
  }

  // ---- Downloads -------------------------------------------------------------

  Future<void> recordDownload(String globalId, String localPath, int sizeBytes) async {
    await _db.insert(
      'downloads',
      {
        'track_global_id': globalId,
        'local_path': localPath,
        'size_bytes': sizeBytes,
        'status': 'complete',
        'downloaded_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> downloadedPath(String globalId) async {
    final rows = await _db.query('downloads',
        where: 'track_global_id = ? AND status = ?',
        whereArgs: [globalId, 'complete'],
        limit: 1);
    if (rows.isEmpty) return null;
    return rows.first['local_path'] as String;
  }

  Future<List<Track>> downloadedTracks() async {
    final rows = await _db.rawQuery('''
      SELECT t.* FROM tracks t
      INNER JOIN downloads d ON d.track_global_id = t.global_id
      WHERE d.status = 'complete'
      ORDER BY d.downloaded_at DESC
    ''');
    return rows.map(_rowToTrack).toList();
  }

  // ---- Search history -------------------------------------------------------

  Future<void> recordSearch(String query) async {
    if (query.trim().isEmpty) return;
    await _db.insert('search_history', {
      'query': query.trim(),
      'searched_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<String>> recentSearches({int limit = 10}) async {
    final rows = await _db.rawQuery('''
      SELECT query, MAX(searched_at) as t FROM search_history
      GROUP BY query
      ORDER BY t DESC
      LIMIT ?
    ''', [limit]);
    return rows.map((r) => r['query'] as String).toList();
  }
}
