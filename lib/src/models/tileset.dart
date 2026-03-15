/// Tiled tileset model.
library;

import 'dart:ui';

import 'tile.dart';
import 'tiled_object.dart';

/// A tileset definition.
///
/// Tilesets contain the image and tile metadata for a set of tiles.
/// They may be embedded in the TMX file or referenced externally via TSX.
class Tileset {
  /// First global tile ID for this tileset.
  final int firstGid;

  /// Tileset name.
  final String name;

  /// Width of individual tiles in pixels.
  final int tileWidth;

  /// Height of individual tiles in pixels.
  final int tileHeight;

  /// Spacing between tiles in the source image (pixels).
  final int spacing;

  /// Margin around tiles in the source image (pixels).
  final int margin;

  /// Total number of tiles in this tileset.
  final int tileCount;

  /// Number of columns in the source image.
  final int columns;

  /// Tile drawing offset.
  final Offset tileOffset;

  /// Source image path.
  final String? imageSource;

  /// Source image width in pixels.
  final int? imageWidth;

  /// Source image height in pixels.
  final int? imageHeight;

  /// Transparent color key for the image.
  final Color? transparentColor;

  /// Per-tile data (keyed by local tile ID).
  final Map<int, Tile> tiles;

  /// Custom properties.
  final TiledProperties properties;

  /// External TSX source file (null if embedded).
  final String? source;

  const Tileset({
    required this.firstGid,
    this.name = '',
    this.tileWidth = 0,
    this.tileHeight = 0,
    this.spacing = 0,
    this.margin = 0,
    this.tileCount = 0,
    this.columns = 0,
    this.tileOffset = Offset.zero,
    this.imageSource,
    this.imageWidth,
    this.imageHeight,
    this.transparentColor,
    this.tiles = const {},
    this.source,
    TiledProperties? properties,
  }) : properties = properties ?? const TiledProperties();

  /// Get the source rectangle for a local tile ID within the tileset image.
  Rect getSourceRect(int localId) {
    if (columns <= 0) return Rect.zero;
    final col = localId % columns;
    final row = localId ~/ columns;
    return Rect.fromLTWH(
      margin + col * (tileWidth + spacing).toDouble(),
      margin + row * (tileHeight + spacing).toDouble(),
      tileWidth.toDouble(),
      tileHeight.toDouble(),
    );
  }
}
