import 'package:flutter_test/flutter_test.dart';
import 'package:gaayana/core/network/lrclib_client.dart';

void main() {
  group('parseLrc', () {
    test('parses simple synced lyric lines', () {
      const lrc = '''
[00:01.00]First line
[00:05.50]Second line
[01:00.10]Third line
''';
      final lines = parseLrc(lrc);
      expect(lines, hasLength(3));
      expect(lines[0].time, const Duration(seconds: 1));
      expect(lines[0].text, 'First line');
      expect(lines[1].time, const Duration(seconds: 5, milliseconds: 500));
      expect(lines[2].time, const Duration(minutes: 1, milliseconds: 100));
    });

    test('handles missing centiseconds', () {
      const lrc = '[00:10]No centi';
      final lines = parseLrc(lrc);
      expect(lines.single.time, const Duration(seconds: 10));
      expect(lines.single.text, 'No centi');
    });

    test('sorts out-of-order timestamps', () {
      const lrc = '[01:00.00]Late\n[00:30.00]Mid\n[00:01.00]Early';
      final lines = parseLrc(lrc);
      expect(lines.map((l) => l.text).toList(),
          <String>['Early', 'Mid', 'Late']);
    });

    test('ignores tag-only lines like [ar:Artist]', () {
      const lrc = '[ar:Artist]\n[ti:Title]\n[00:01.00]Real lyric';
      final lines = parseLrc(lrc);
      expect(lines, hasLength(1));
      expect(lines.single.text, 'Real lyric');
    });

    test('returns empty list for empty input', () {
      expect(parseLrc(''), isEmpty);
    });

    test('trims whitespace around lyric text', () {
      const lrc = '[00:01.00]   spaced out   ';
      expect(parseLrc(lrc).single.text, 'spaced out');
    });

    test('supports multi-line LRC with CRLF line endings', () {
      const lrc = '[00:01.00]A\r\n[00:02.00]B\r\n[00:03.00]C';
      final lines = parseLrc(lrc);
      expect(lines.map((l) => l.text), <String>['A', 'B', 'C']);
    });
  });
}
