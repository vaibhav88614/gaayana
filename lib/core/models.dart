/// Core domain models shared across features.
///
/// These are immutable value objects. They are intentionally framework-agnostic
/// so they can be returned by any [MusicSource] implementation (local files,
/// Jamendo, Subsonic, etc.) without leaking implementation details.
library;

import 'package:flutter/foundation.dart';

@immutable
class Track {
  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.durationMs,
    required this.uri,
    this.albumArtUri,
    this.genre,
    this.year,
    this.trackNumber,
    this.sourceId = 'local',
  });

  /// Stable id within a source (e.g. MediaStore _id for local files, or a hash).
  final String id;
  final String title;
  final String artist;
  final String album;
  final int durationMs;

  /// `file://...`, `content://...` or `https://...` — whatever `just_audio` can play.
  final String uri;
  final String? albumArtUri;
  final String? genre;
  final int? year;
  final int? trackNumber;

  /// Identifier of the [MusicSource] that produced this track.
  final String sourceId;

  String get globalId => '$sourceId::$id';

  Track copyWith({
    String? title,
    String? artist,
    String? album,
    String? albumArtUri,
    String? genre,
    String? uri,
  }) => Track(
        id: id,
        title: title ?? this.title,
        artist: artist ?? this.artist,
        album: album ?? this.album,
        durationMs: durationMs,
        uri: uri ?? this.uri,
        albumArtUri: albumArtUri ?? this.albumArtUri,
        genre: genre ?? this.genre,
        year: year,
        trackNumber: trackNumber,
        sourceId: sourceId,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'album': album,
        'durationMs': durationMs,
        'uri': uri,
        'albumArtUri': albumArtUri,
        'genre': genre,
        'year': year,
        'trackNumber': trackNumber,
        'sourceId': sourceId,
      };

  factory Track.fromJson(Map<String, dynamic> j) => Track(
        id: j['id'] as String,
        title: j['title'] as String,
        artist: j['artist'] as String,
        album: j['album'] as String,
        durationMs: j['durationMs'] as int,
        uri: j['uri'] as String,
        albumArtUri: j['albumArtUri'] as String?,
        genre: j['genre'] as String?,
        year: j['year'] as int?,
        trackNumber: j['trackNumber'] as int?,
        sourceId: (j['sourceId'] as String?) ?? 'local',
      );

  @override
  bool operator ==(Object other) =>
      other is Track && other.globalId == globalId;
  @override
  int get hashCode => globalId.hashCode;
}

@immutable
class Playlist {
  const Playlist({
    required this.id,
    required this.name,
    required this.trackIds,
    this.coverUri,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final List<String> trackIds; // Track.globalId
  final String? coverUri;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Playlist copyWith({String? name, List<String>? trackIds, String? coverUri}) =>
      Playlist(
        id: id,
        name: name ?? this.name,
        trackIds: trackIds ?? this.trackIds,
        coverUri: coverUri ?? this.coverUri,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}

/// Where audio is currently being routed.
enum OutputRouteKind { speaker, wired, bluetooth, cast, unknown }

@immutable
class OutputRoute {
  const OutputRoute({required this.kind, this.deviceName});
  final OutputRouteKind kind;
  final String? deviceName;

  static const speaker = OutputRoute(kind: OutputRouteKind.speaker);
}

/// Repeat / loop modes.
enum LoopMode {
  off,

  /// Single song on repeat (requirement #9a).
  one,

  /// Playlist loop (requirement #9b).
  all,
}
