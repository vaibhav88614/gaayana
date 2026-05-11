import 'package:flutter_test/flutter_test.dart';
import 'package:gaayana/core/models.dart';

void main() {
  group('Track', () {
    Track sample({String id = '1', String sourceId = 'local'}) => Track(
          id: id,
          title: 'Bohemian Rhapsody',
          artist: 'Queen',
          album: 'A Night at the Opera',
          durationMs: 354000,
          uri: 'file:///music/bohemian.mp3',
          genre: 'Rock',
          year: 1975,
          trackNumber: 11,
          sourceId: sourceId,
        );

    test('globalId combines sourceId and id', () {
      final t = sample();
      expect(t.globalId, 'local::1');
    });

    test('equality is based on globalId, not field-by-field', () {
      final a = sample();
      final b = sample().copyWith(title: 'A different title');
      expect(a == b, isTrue);
      expect(a.hashCode, b.hashCode);
    });

    test('different sourceId or id breaks equality', () {
      expect(sample(id: '1') == sample(id: '2'), isFalse);
      expect(sample(sourceId: 'local') == sample(sourceId: 'remote'), isFalse);
    });

    test('toJson / fromJson round-trips', () {
      final t = sample();
      final json = t.toJson();
      final t2 = Track.fromJson(json);
      expect(t2.globalId, t.globalId);
      expect(t2.title, t.title);
      expect(t2.artist, t.artist);
      expect(t2.album, t.album);
      expect(t2.durationMs, t.durationMs);
      expect(t2.uri, t.uri);
      expect(t2.genre, 'Rock');
      expect(t2.year, 1975);
      expect(t2.trackNumber, 11);
    });

    test('fromJson defaults sourceId to "local" when missing', () {
      final json = sample().toJson()..remove('sourceId');
      expect(Track.fromJson(json).sourceId, 'local');
    });

    test('copyWith preserves identity fields', () {
      final original = sample();
      final modified = original.copyWith(
        title: 'New Title',
        artist: 'New Artist',
        album: 'New Album',
        albumArtUri: 'http://art',
        genre: 'Pop',
        uri: 'file:///new.mp3',
      );
      expect(modified.id, original.id);
      expect(modified.sourceId, original.sourceId);
      expect(modified.durationMs, original.durationMs);
      expect(modified.year, original.year);
      expect(modified.trackNumber, original.trackNumber);
      expect(modified.title, 'New Title');
      expect(modified.artist, 'New Artist');
      expect(modified.albumArtUri, 'http://art');
      expect(modified.genre, 'Pop');
    });
  });

  group('Playlist', () {
    test('copyWith updates fields and refreshes updatedAt', () async {
      final created = DateTime(2025, 1, 1);
      final original = Playlist(
        id: 'p1',
        name: 'Favorites',
        trackIds: const ['local::1', 'local::2'],
        createdAt: created,
        updatedAt: created,
      );
      final updated = original.copyWith(
        name: 'My Favs',
        trackIds: const ['local::1', 'local::2', 'local::3'],
      );
      expect(updated.id, 'p1');
      expect(updated.createdAt, created);
      expect(updated.name, 'My Favs');
      expect(updated.trackIds, hasLength(3));
      expect(updated.updatedAt, isNotNull);
      expect(updated.updatedAt!.isAfter(created), isTrue);
    });
  });

  group('OutputRoute', () {
    test('speaker constant has expected kind', () {
      expect(OutputRoute.speaker.kind, OutputRouteKind.speaker);
      expect(OutputRoute.speaker.deviceName, isNull);
    });

    test('all route kinds are distinct', () {
      expect(OutputRouteKind.values.toSet().length,
          OutputRouteKind.values.length);
    });
  });

  group('LoopMode', () {
    test('has off, one, all', () {
      expect(LoopMode.values, containsAll(<LoopMode>[
        LoopMode.off,
        LoopMode.one,
        LoopMode.all,
      ]));
      expect(LoopMode.values.length, 3);
    });
  });
}
