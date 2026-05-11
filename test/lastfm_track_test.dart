import 'package:flutter_test/flutter_test.dart';
import 'package:gaayana/core/network/lastfm_client.dart';

void main() {
  group('LastfmTrack', () {
    test('parses standard top-tracks shape', () {
      final t = LastfmTrack.fromJson({
        'name': 'Yesterday',
        'artist': {'name': 'The Beatles'},
        'playcount': '12345',
        'listeners': '6789',
      });
      expect(t.title, 'Yesterday');
      expect(t.artist, 'The Beatles');
      expect(t.playcount, 12345);
      expect(t.listeners, 6789);
      expect(t.matchScore, isNull);
    });

    test('parses similar-tracks shape with match score', () {
      final t = LastfmTrack.fromJson({
        'name': 'Hey Jude',
        'artist': 'The Beatles',
        'playcount': 0,
        'match': '0.85',
      });
      expect(t.artist, 'The Beatles');
      expect(t.matchScore, closeTo(0.85, 1e-9));
    });

    test('falls back gracefully on missing fields', () {
      final t = LastfmTrack.fromJson(<String, dynamic>{});
      expect(t.title, '');
      expect(t.artist, '');
      expect(t.playcount, 0);
      expect(t.listeners, 0);
      expect(t.matchScore, isNull);
    });

    test('key is lowercase artist::title', () {
      final t = LastfmTrack(
        title: 'Bohemian RHAPSODY',
        artist: 'Queen',
        playcount: 0,
      );
      expect(t.key, 'queen::bohemian rhapsody');
    });
  });
}
