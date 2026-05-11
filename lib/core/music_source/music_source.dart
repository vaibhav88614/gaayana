import 'dart:async';

import '../models.dart';

/// Pluggable music origin. Swap implementations (local files, Jamendo,
/// Subsonic, etc.) without touching the UI.
abstract class MusicSource {
  String get id;
  String get displayName;

  /// Whether this source requires an internet connection to play.
  bool get isOnline;

  /// Scan / refresh the catalog and return all known tracks.
  /// Local sources read from disk; remote sources may paginate.
  Future<List<Track>> listAll();

  /// Resolve a track id to a fully-described [Track] with playable [Track.uri].
  Future<Track?> resolve(String trackId);

  /// Search the source (some sources may just delegate to local DB).
  Future<List<Track>> search(String query);

  /// Streaming URL for a track. For local sources this is the same as
  /// [Track.uri]; for remote sources it may be a short-lived signed URL.
  Future<String> streamUrl(Track track) async => track.uri;

  /// If supported, returns a downloadable URL (often == streamUrl).
  /// Returns null when the source forbids downloads.
  Future<String?> downloadUrl(Track track) async => track.uri;
}
