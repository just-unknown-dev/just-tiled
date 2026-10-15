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
///
/// Items are told apart by `==`, so an item can be in the grid once.
class SpatialHashGrid<T> {
  /// Size of each grid cell in world units.
  final double cellSize;

  /// Grid cells: hash → list of (item, bounds) pairs.
  final Map<int, List<_GridEntry<T>>> _cells = {};

  /// Reverse lookup: item → set of cell hashes it occupies. Empty for an
  /// item kept in [_oversized].
  final Map<T, Set<int>> _itemCells = {};

  /// Bounds cache: item → AABB, used for O(1) queryRadius checks.
  final Map<T, Rect> _itemBounds = {};

  /// Items spanning more than [_maxCells] cells, checked by every query
  /// instead of being stored cell by cell.
  final Set<T> _oversized = {};

  /// The most cells an item is stored in.
  static const int _maxCells = 1024;

  /// Create a spatial hash grid with the given [cellSize].
  SpatialHashGrid({this.cellSize = 64.0})
    : assert(cellSize > 0, 'cellSize must be positive');

  /// Insert an item with its axis-aligned bounding box. An item already in
  /// the grid is moved to [bounds], as by [update].
  ///
  /// Throws an [ArgumentError] if [bounds] is not finite.
  void insert(T item, Rect bounds) {
    if (!bounds.isFinite) {
      throw ArgumentError.value(bounds, 'bounds', 'must be finite');
    }
    if (_itemCells.containsKey(item)) remove(item);
    _itemBounds[item] = bounds;

    if (_cellSpan(bounds) > _maxCells) {
      _itemCells[item] = const {};
      _oversized.add(item);
      return;
    }
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
    _itemBounds.remove(item);
    _oversized.remove(item);

    for (final key in cellKeys) {
      _cells[key]?.removeWhere((e) => e.item == item);
      if (_cells[key]?.isEmpty ?? false) {
        _cells.remove(key);
      }
    }
    return true;
  }

  /// Update an item's position (remove + re-insert).
  void update(T item, Rect newBounds) => insert(item, newBounds);

  /// Query all items whose bounds overlap [area].
  ///
  /// Returns a [Set] to avoid duplicates from items spanning multiple cells.
  /// An [area] spanning more cells than the grid has occupied ones — the
  /// whole world, say — checks every item instead.
  Set<T> query(Rect area) {
    final result = <T>{};
    if (!area.isFinite || _cellSpan(area) > _cells.length) {
      _itemBounds.forEach((item, bounds) {
        if (bounds.overlaps(area)) result.add(item);
      });
      return result;
    }

    for (final key in _getCellKeys(area)) {
      final entries = _cells[key];
      if (entries == null) continue;
      for (final entry in entries) {
        if (entry.bounds.overlaps(area)) {
          result.add(entry.item);
        }
      }
    }
    for (final item in _oversized) {
      if (_itemBounds[item]!.overlaps(area)) result.add(item);
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

    // Filter candidates using the cached bounds for O(1) per item.
    final result = <T>{};
    final radiusSq = radius * radius;
    for (final item in candidates) {
      final bounds = _itemBounds[item];
      if (bounds == null) continue;
      final closestX = center.dx.clamp(bounds.left, bounds.right);
      final closestY = center.dy.clamp(bounds.top, bounds.bottom);
      final distSq =
          (closestX - center.dx) * (closestX - center.dx) +
          (closestY - center.dy) * (closestY - center.dy);
      if (distSq <= radiusSq) {
        result.add(item);
      }
    }

    return result;
  }

  /// Clear all items from the grid.
  void clear() {
    _cells.clear();
    _itemCells.clear();
    _itemBounds.clear();
    _oversized.clear();
  }

  /// Number of items in the grid.
  int get itemCount => _itemCells.length;

  /// Number of occupied cells.
  int get cellCount => _cells.length;

  /// Whether the grid is empty.
  bool get isEmpty => _itemCells.isEmpty;

  /// How many cells the finite [area] spans, in doubles so a huge area
  /// can't overflow.
  double _cellSpan(Rect area) =>
      ((area.right / cellSize).floorToDouble() -
          (area.left / cellSize).floorToDouble() +
          1) *
      ((area.bottom / cellSize).floorToDouble() -
          (area.top / cellSize).floorToDouble() +
          1);

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
    return (x * 73856093) ^ (y * 19349663);
  }
}

/// Internal grid entry holding an item and its bounds.
class _GridEntry<T> {
  final T item;
  final Rect bounds;

  const _GridEntry(this.item, this.bounds);
}
