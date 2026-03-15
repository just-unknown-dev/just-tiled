import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_tiled/just_tiled.dart';

void main() {
  group('TiledProperties', () {
    test('returns typed values', () {
      final props = TiledProperties({
        'name': 'test',
        'health': 100,
        'speed': 5.5,
        'active': true,
      });
      expect(props.getString('name'), equals('test'));
      expect(props.getInt('health'), equals(100));
      expect(props.getDouble('speed'), equals(5.5));
      expect(props.getBool('active'), isTrue);
    });

    test('returns null for missing keys', () {
      const props = TiledProperties();
      expect(props.getString('missing'), isNull);
      expect(props.getInt('missing'), isNull);
    });
  });

  group('MapOrientation', () {
    test('parses from string', () {
      expect(
        MapOrientation.fromString('orthogonal'),
        equals(MapOrientation.orthogonal),
      );
      expect(
        MapOrientation.fromString('isometric'),
        equals(MapOrientation.isometric),
      );
    });
  });

  group('SpatialHashGrid', () {
    test('insert and query items', () {
      final grid = SpatialHashGrid<String>(cellSize: 64);
      grid.insert('a', const Rect.fromLTWH(0, 0, 32, 32));
      grid.insert('b', const Rect.fromLTWH(100, 100, 32, 32));

      final results = grid.query(const Rect.fromLTWH(0, 0, 50, 50));
      expect(results, contains('a'));
      expect(results, isNot(contains('b')));
    });

    test('remove items', () {
      final grid = SpatialHashGrid<String>(cellSize: 64);
      grid.insert('a', const Rect.fromLTWH(0, 0, 32, 32));
      grid.remove('a');
      expect(grid.isEmpty, isTrue);
    });
  });
}
