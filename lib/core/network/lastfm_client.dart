import 'package:dio/dio.dart';

/// Minimal Last.fm REST client used by the radio engine and search.
///
/// Register a free key at https://www.last.fm/api/account/create then either:
///   * Set it in Settings → Last.fm API key, or
///   * Pass at build time with `--dart-define=LASTFM_API_KEY=xxx`.
class LastfmClient {
  LastfmClient({this.apiKey, Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: 'https://ws.audioscrobbler.com/2.0/',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
            ));

  String? apiKey;
  final Dio _dio;

  bool get isConfigured => (apiKey ?? '').isNotEmpty;

  Future<List<LastfmTrack>> topTracksByTag(String tag, {int limit = 50}) async {
    if (!isConfigured) return const [];
    final r = await _dio.get('', queryParameters: {
      'method': 'tag.gettoptracks',
      'tag': tag,
      'api_key': apiKey,
      'format': 'json',
      'limit': limit,
    });
    final tracks = (r.data['tracks']?['track'] as List?) ?? const [];
    return tracks
        .cast<Map<String, dynamic>>()
        .map(LastfmTrack.fromJson)
        .toList(growable: false);
  }

  Future<List<LastfmTrack>> similarTracks(String artist, String title,
      {int limit = 50}) async {
    if (!isConfigured) return const [];
    final r = await _dio.get('', queryParameters: {
      'method': 'track.getsimilar',
      'artist': artist,
      'track': title,
      'api_key': apiKey,
      'format': 'json',
      'limit': limit,
    });
    final tracks = (r.data['similartracks']?['track'] as List?) ?? const [];
    return tracks
        .cast<Map<String, dynamic>>()
        .map(LastfmTrack.fromJson)
        .toList(growable: false);
  }

  Future<List<LastfmTrack>> topTracksGlobal({int limit = 50}) async {
    if (!isConfigured) return const [];
    final r = await _dio.get('', queryParameters: {
      'method': 'chart.gettoptracks',
      'api_key': apiKey,
      'format': 'json',
      'limit': limit,
    });
    final tracks = (r.data['tracks']?['track'] as List?) ?? const [];
    return tracks
        .cast<Map<String, dynamic>>()
        .map(LastfmTrack.fromJson)
        .toList(growable: false);
  }
}

class LastfmTrack {
  LastfmTrack({
    required this.title,
    required this.artist,
    required this.playcount,
    this.listeners = 0,
    this.matchScore,
  });

  final String title;
  final String artist;
  final int playcount;
  final int listeners;

  /// 0..1 similarity (only present for `track.getsimilar`).
  final double? matchScore;

  factory LastfmTrack.fromJson(Map<String, dynamic> j) => LastfmTrack(
        title: (j['name'] ?? '') as String,
        artist: (j['artist'] is Map
            ? (j['artist'] as Map)['name']
            : j['artist'] ?? '') as String,
        playcount: int.tryParse('${j['playcount'] ?? 0}') ?? 0,
        listeners: int.tryParse('${j['listeners'] ?? 0}') ?? 0,
        matchScore: double.tryParse('${j['match'] ?? ''}'),
      );

  String get key => '${artist.toLowerCase()}::${title.toLowerCase()}';
}
