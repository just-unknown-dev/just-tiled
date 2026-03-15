/// Tiled tile and animation frame models.
library;

import 'tiled_object.dart';

/// A single animation frame for animated tiles.
class AnimationFrame {
  /// Local tile ID within the tileset.
  final int tileId;

  /// Duration of this frame in milliseconds.
  final int duration;

  const AnimationFrame({required this.tileId, required this.duration});
}

/// Per-tile data within a tileset.
///
/// Tiles may have custom properties, collision shapes, and animation frames.
class Tile {
  /// Local tile ID within the tileset.
  final int id;

  /// Custom type/class name.
  final String? type;

  /// Probability weight for random placement.
  final double probability;

  /// Tile-specific image source (overrides tileset image).
  final String? imageSource;

  /// Image width (if tile-specific image).
  final int? imageWidth;

  /// Image height (if tile-specific image).
  final int? imageHeight;

  /// Collision shapes defined on this tile.
  final List<TiledObject> objectGroup;

  /// Animation frames (empty if not animated).
  final List<AnimationFrame> animation;

  /// Custom properties.
  final TiledProperties properties;

  const Tile({
    required this.id,
    this.type,
    this.probability = 1.0,
    this.imageSource,
    this.imageWidth,
    this.imageHeight,
    this.objectGroup = const [],
    this.animation = const [],
    TiledProperties? properties,
  }) : properties = properties ?? const TiledProperties();
}
