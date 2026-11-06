import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_tiled/just_tiled.dart';

void main() {
  group('Tileset.getSourceRect', () {
    late Tileset ts;

    setUp(() {
      ts = const Tileset(
        firstGid: 1,
        name: 'test',
        tileWidth: 16,
        tileHeight: 16,
        columns: 4,
        tileCount: 8,
        spacing: 2,
        margin: 1,
      );
    });

    test('first tile (localId=0)', () {
      final r = ts.getSourceRect(0);
      // margin + col * (tileW + spacing) = 1 + 0 * 18 = 1
      expect(r.left, equals(1.0));
      expect(r.top, equals(1.0));
      expect(r.right, equals(17.0));
      expect(r.bottom, equals(17.0));
    });

    test('second tile in first row (localId=1)', () {
      final r = ts.getSourceRect(1);
      expect(r.left, equals(1.0 + 18.0)); // 19
      expect(r.top, equals(1.0));
    });

    test('first tile in second row (localId=4)', () {
      final r = ts.getSourceRect(4);
      expect(r.left, equals(1.0));
      expect(r.top, equals(1.0 + 18.0)); // 19
    });

    test('returns Rect.zero when columns=0', () {
      const empty = Tileset(firstGid: 1, columns: 0, tileCount: 4);
      expect(empty.getSourceRect(0), equals(Rect.zero));
    });
  });
}
