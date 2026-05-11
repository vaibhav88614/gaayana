import '../../core/audio/audio_handler.dart';
import '../../core/db/app_database.dart';
import '../../core/models.dart';
import '../../core/network/lastfm_client.dart';

/// "Infinity play" — requirement #8.
///
/// Given a seed (genre or track), continuously enqueues more tracks ranked by
/// global popularity (Last.fm play counts) blended with the user's local play
/// counts (70 / 30 default).
///
/// Implementation note: Last.fm gives us `(artist, title)` pairs by playcount.
/// We resolve those to *local library tracks* by title+artist match. Tracks
/// the user does not have locally are skipped (until a streaming MusicSource
/// is plugged in — at which point this engine doesn't need to change).
class RadioEngine {
  RadioEngine({
    required this.db,
    required this.lastfm,
    required this.handler,
    this.globalWeight = 0.7,
    this.localWeight = 0.3,
  });

  final AppDatabase db;
  final LastfmClient lastfm;
  final GaayanaAudioHandler handler;
  final double globalWeight;
  final double localWeight;

  /// Tracks already enqueued in the current radio session — to avoid repeats.
  final Set<String> _seen = <String>{};

  /// Start radio seeded by genre. Picks an initial batch, plays the top track,
  /// and pre-queues the rest.
  Future<void> startGenreRadio(String genre) async {
    _seen.clear();
    final batch = await _genreBatch(genre);
    if (batch.isEmpty) return;
    await handler.setQueue(batch);
    await handler.play();
  }

  /// Start radio seeded by a single track (Last.fm `track.getsimilar`).
  Future<void> startTrackRadio(Track seed) async {
    _seen.clear();
    final batch = await _similarBatch(seed);
    if (batch.isEmpty) return;
    await handler.setQueue([seed, ...batch]);
    await handler.play();
  }

  /// Top-up the queue when it's running low. Call from a queue-watcher.
  Future<void> topUp(String genreOrSeedTitle, {bool seedIsGenre = true}) async {
    final batch = seedIsGenre
        ? await _genreBatch(genreOrSeedTitle, limit: 20)
        : <Track>[];
    if (batch.isNotEmpty) await handler.appendToQueue(batch);
  }

  Future<List<Track>> _genreBatch(String genre, {int limit = 40}) async {
    final remote = await lastfm.topTracksByTag(genre, limit: limit * 2);
    final localCounts = await db.allPlayCounts();
    return _rankAndResolve(remote, localCounts, limit);
  }

  Future<List<Track>> _similarBatch(Track seed, {int limit = 40}) async {
    final remote = await lastfm.similarTracks(seed.artist, seed.title,
        limit: limit * 2);
    final localCounts = await db.allPlayCounts();
    return _rankAndResolve(remote, localCounts, limit);
  }

  Future<List<Track>> _rankAndResolve(
    List<LastfmTrack> remote,
    Map<String, int> localCounts,
    int limit,
  ) async {
    if (remote.isEmpty) return [];

    // Normalise global popularity to [0,1].
    final maxPlay = remote
        .map((t) => t.playcount)
        .fold<int>(0, (a, b) => a > b ? a : b)
        .clamp(1, 1 << 31);
    final maxLocal = (localCounts.values.fold<int>(0, (a, b) => a > b ? a : b))
        .clamp(1, 1 << 31);

    // All local tracks indexed by (title|artist) → for matching.
    final library = await db.allTracks();
    final byKey = <String, Track>{
      for (final t in library)
        '${t.artist.toLowerCase()}::${t.title.toLowerCase()}': t,
    };

    final scored = <_Scored>[];
    for (final r in remote) {
      final match = byKey[r.key];
      if (match == null) continue;
      if (_seen.contains(match.globalId)) continue;

      final globalScore = r.playcount / maxPlay;
      final localScore = (localCounts[match.globalId] ?? 0) / maxLocal;
      final score = globalScore * globalWeight + localScore * localWeight;
      scored.add(_Scored(match, score));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    final picked = scored.take(limit).map((s) => s.track).toList();
    for (final p in picked) {
      _seen.add(p.globalId);
    }
    return picked;
  }
}

class _Scored {
  _Scored(this.track, this.score);
  final Track track;
  final double score;
}
