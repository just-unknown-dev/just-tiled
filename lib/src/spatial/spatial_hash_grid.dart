/// Generic spatial hash grid for O(1) proximity lookups.
///
/// Subdivides 2D space into uniform cells and supports efficient
/// area queries and point queries.
library;

import 'dart:ui';

/// A generic spatial hash grid for fast 2D proximity lookups.
///
/// Usage:
/// ```dart
/// final grid = SpatialHashGrid<String>(cellSize: 64);
/// grid.insert('wall_1', Rect.fromLTWH(0, 0, 32, 128));
/// final nearby = grid.query(Rect.fromLTWH(10, 10, 50, 50));
/// // nearby contains 'wall_1'
/// ```
class SpatialHashGrid<T> {
  /// Size of each grid cell in world units.
  final double cellSize;

  /// Grid cells: hash → list of (item, bounds) pairs.
  final Map<int, List<_GridEntry<T>>> _cells = {};

  /// Reverse lookup: item → set of cell hashes it occupies.
  final Map<T, Set<int>> _itemCells = {};

  /// Create a spatial hash grid with the given [cellSize].
  SpatialHashGrid({this.cellSize = 64.0});

  /// Insert an item with its axis-aligned bounding box.
  void insert(T item, Rect bounds) {
    final cellKeys = _getCellKeys(bounds);
    _itemCells[item] = cellKeys;

    final entry = _GridEntry(item, bounds);
    for (final key in cellKeys) {
      _cells.putIfAbsent(key, () => []).add(entry);
    }
  }

  /// Remove an item from the grid.
  bool remove(T item) {
    final cellKeys = _itemCells.remove(item);
    if (cellKeys == null) return false;

    for (final key in cellKeys) {
      _cells[key]?.removeWhere((e) => e.item == item);
      if (_cells[key]?.isEmpty ?? false) {
        _cells.remove(key);
      }
    }
    return true;
  }

  /// Update an item's position (remove + re-insert).
  void update(T item, Rect newBounds) {
    remove(item);
    insert(item, newBounds);
  }

  /// Query all items whose bounds overlap [area].
  ///
  /// Returns a [Set] to avoid duplicates from items spanning multiple cells.
  Set<T> query(Rect area) {
    final result = <T>{};
    final cellKeys = _getCellKeys(area);

    for (final key in cellKeys) {
      final entries = _cells[key];
      if (entries == null) continue;
      for (final entry in entries) {
        if (entry.bounds.overlaps(area)) {
          result.add(entry.item);
        }
      }
    }

    return result;
  }

  /// Query all items at a specific point.
  Set<T> queryPoint(Offset point) {
    return query(Rect.fromCenter(center: point, width: 0.1, height: 0.1));
  }

  /// Query items within a circular radius.
  Set<T> queryRadius(Offset center, double radius) {
    final queryRect = Rect.fromCircle(center: center, radius: radius);
    final candidates = query(queryRect);

    // Filter to items actually within the circle
    final result = <T>{};
    final radiusSq = radius * radius;
    for (final item in candidates) {
      final cellKeys = _itemCells[item];
      if (cellKeys == null) continue;
      // Find the item's bounds from any cell
      for (final key in cellKeys) {
        final entries = _cells[key];
        if (entries == null) continue;
        for (final entry in entries) {
          if (entry.item == item) {
            // Check if bounds intersect circle
            final closestX = center.dx.clamp(entry.bounds.left, entry.bounds.right);
            final closestY = center.dy.clamp(entry.bounds.top, entry.bounds.bottom);
            final distSq = (closestX - center.dx) * (closestX - center.dx) +
                (closestY - center.dy) * (closestY - center.dy);
            if (distSq <= radiusSq) {
              result.add(item);
            }
            break;
          }
        }
        break;
      }
    }

    return result;
  }

  /// Clear all items from the grid.
  void clear() {
    _cells.clear();
    _itemCells.clear();
  }

  /// Number of items in the grid.
  int get itemCount => _itemCells.length;

  /// Number of occupied cells.
  int get cellCount => _cells.length;

  /// Whether the grid is empty.
  bool get isEmpty => _itemCells.isEmpty;

  /// Get the cell keys (hashes) that a rectangle overlaps.
  Set<int> _getCellKeys(Rect bounds) {
    final keys = <int>{};
    final minX = (bounds.left / cellSize).floor();
    final minY = (bounds.top / cellSize).floor();
    final maxX = (bounds.right / cellSize).floor();
    final maxY = (bounds.bottom / cellSize).floor();

    for (int x = minX; x <= maxX; x++) {
      for (int y = minY; y <= maxY; y++) {
        keys.add(_hash(x, y));
      }
    }
    return keys;
  }

  /// Hash function for grid coordinates using prime multiplication.
  int _hash(int x, int y) {
    return (x * 73856093) ^ ((y * 19349663) >> 1);
  }
}

/// Internal grid entry holding an item and its bounds.
class _GridEntry<T> {
  final T item;
  final Rect bounds;

  const _GridEntry(this.item, this.bounds);
}
