// SpatialHashGrid at its edges: items inserted twice, items and queries the
// size of the world, bounds that aren't finite.

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_tiled/just_tiled.dart';

void main() {
  test('inserting an item again moves it, leaving nothing behind', () {
    final grid = SpatialHashGrid<String>(cellSize: 10)
      ..insert('a', const Rect.fromLTWH(0, 0, 5, 5))
      ..insert('a', const Rect.fromLTWH(100, 100, 5, 5));

    expect(grid.query(const Rect.fromLTWH(0, 0, 5, 5)), isEmpty);
    expect(grid.query(const Rect.fromLTWH(100, 100, 5, 5)), {'a'});
    expect(grid.itemCount, 1);

    grid.remove('a');
    expect(grid.query(const Rect.fromLTWH(100, 100, 5, 5)), isEmpty);
    expect(grid.cellCount, 0);
  });

  test('a query the size of the world finds what it overlaps, at once', () {
    final grid = SpatialHashGrid<int>(cellSize: 1);
    for (var i = 0; i < 100; i++) {
      grid.insert(i, Rect.fromLTWH(i * 10.0, 0, 1, 1));
    }

    expect(grid.query(Rect.largest), hasLength(100));
    expect(
      grid.query(const Rect.fromLTRB(-1e300, -1e300, 1e300, 1e300)),
      hasLength(100),
    );
    expect(
      grid.query(const Rect.fromLTRB(double.negativeInfinity, -1, 25, 2)),
      {0, 1, 2},
    );
  });

  test('an item the size of the world is found and removed like any', () {
    final grid = SpatialHashGrid<String>(cellSize: 1)
      ..insert('world', const Rect.fromLTRB(-1e9, -1e9, 1e9, 1e9))
      ..insert('dot', const Rect.fromLTWH(5, 5, 1, 1));

    expect(grid.query(const Rect.fromLTWH(5, 5, 1, 1)), {'world', 'dot'});
    expect(grid.queryPoint(const Offset(-500, 300)), {'world'});
    expect(grid.queryRadius(const Offset(1e6, 1e6), 1), {'world'});
    expect(grid.itemCount, 2);

    expect(grid.remove('world'), isTrue);
    expect(grid.query(const Rect.fromLTWH(5, 5, 1, 1)), {'dot'});
    grid.clear();
    expect(grid.isEmpty, isTrue);
  });

  test('bounds that are not finite are refused', () {
    final grid = SpatialHashGrid<String>();
    expect(
      () => grid.insert('x', const Rect.fromLTRB(0, 0, double.infinity, 1)),
      throwsArgumentError,
    );
    expect(
      () => grid.insert('x', const Rect.fromLTRB(double.nan, 0, 1, 1)),
      throwsArgumentError,
    );
    expect(grid.isEmpty, isTrue);
  });
}
