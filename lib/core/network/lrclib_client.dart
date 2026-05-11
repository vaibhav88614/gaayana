import 'package:dio/dio.dart';

/// LRCLIB — free, community-maintained synced-lyrics service.
/// https://lrclib.net/docs
class LrclibClient {
  LrclibClient({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: 'https://lrclib.net/api/',
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 10),
              headers: const {
                'User-Agent':
                    'Gaayana/0.1 (https://github.com/vaibhav88614/gaayana)',
              },
            ));
  final Dio _dio;

  /// Returns (syncedLyrics, plainLyrics). Either may be null.
  ///
  /// Tries the exact-match `/get` first; if that 404s (very common for local
  /// files where metadata is rough), falls back to the fuzzier `/search`.
  Future<({String? synced, String? plain})> fetch({
    required String trackName,
    required String artistName,
    String? albumName,
    int? durationSeconds,
  }) async {
    final exact = await _tryGet(
      trackName: trackName,
      artistName: artistName,
      albumName: albumName,
      durationSeconds: durationSeconds,
    );
    if (exact.synced != null || exact.plain != null) return exact;
    return _trySearch(trackName: trackName, artistName: artistName);
  }

  Future<({String? synced, String? plain})> _tryGet({
    required String trackName,
    required String artistName,
    String? albumName,
    int? durationSeconds,
  }) async {
    try {
      final r = await _dio.get('get', queryParameters: {
        'track_name': trackName,
        'artist_name': artistName,
        if (albumName != null && albumName.isNotEmpty) 'album_name': albumName,
        if (durationSeconds != null && durationSeconds > 0)
          'duration': durationSeconds,
      });
      final data = r.data as Map<String, dynamic>;
      return (
        synced: data['syncedLyrics'] as String?,
        plain: data['plainLyrics'] as String?,
      );
    } on DioException {
      return (synced: null, plain: null);
    }
  }

  Future<({String? synced, String? plain})> _trySearch({
    required String trackName,
    required String artistName,
  }) async {
    try {
      final r = await _dio.get('search', queryParameters: {
        'track_name': trackName,
        if (artistName.isNotEmpty) 'artist_name': artistName,
      });
      final list = r.data as List<dynamic>;
      if (list.isEmpty) return (synced: null, plain: null);
      final first = list.first as Map<String, dynamic>;
      return (
        synced: first['syncedLyrics'] as String?,
        plain: first['plainLyrics'] as String?,
      );
    } on DioException {
      return (synced: null, plain: null);
    }
  }
}

/// One synced lyric line: `[mm:ss.xx] text`.
class LyricLine {
  const LyricLine(this.time, this.text);
  final Duration time;
  final String text;
}

/// Parse an LRC string into a sorted list of [LyricLine]s.
List<LyricLine> parseLrc(String lrc) {
  final out = <LyricLine>[];
  final re = RegExp(r'\[(\d+):(\d+)(?:\.(\d+))?\]([^\n\r]*)');
  for (final m in re.allMatches(lrc)) {
    final minutes = int.parse(m.group(1)!);
    final seconds = int.parse(m.group(2)!);
    final hundredths = int.tryParse(m.group(3) ?? '0') ?? 0;
    final text = (m.group(4) ?? '').trim();
    out.add(LyricLine(
      Duration(
          minutes: minutes,
          seconds: seconds,
          milliseconds: hundredths * 10),
      text,
    ));
  }
  out.sort((a, b) => a.time.compareTo(b.time));
  return out;
}
