import 'package:flutter_test/flutter_test.dart';
import 'package:just_tiled/just_tiled.dart';

void main() {
  group('MapOrientation', () {
    test('parses known values', () {
      expect(
        MapOrientation.fromString('orthogonal'),
        equals(MapOrientation.orthogonal),
      );
      expect(
        MapOrientation.fromString('isometric'),
        equals(MapOrientation.isometric),
      );
      expect(
        MapOrientation.fromString('staggered'),
        equals(MapOrientation.staggered),
      );
      expect(
        MapOrientation.fromString('hexagonal'),
        equals(MapOrientation.hexagonal),
      );
    });

    test('falls back to orthogonal for unknown', () {
      expect(
        MapOrientation.fromString('unknown'),
        equals(MapOrientation.orthogonal),
      );
    });
  });

  group('RenderOrder', () {
    test('parses from TMX string', () {
      expect(
        RenderOrder.fromString('right-down'),
        equals(RenderOrder.rightDown),
      );
      expect(RenderOrder.fromString('left-up'), equals(RenderOrder.leftUp));
    });

    test('falls back to rightDown for unknown', () {
      expect(RenderOrder.fromString('???'), equals(RenderOrder.rightDown));
    });
  });
}
