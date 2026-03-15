/// Root Tiled map model.
library;

import 'dart:ui';

import 'enums.dart';
import 'layer.dart';
import 'tileset.dart';
import 'tiled_object.dart';

/// The root document representing a parsed TMX map.
class TiledMap {
  /// TMX format version.
  final String version;

  /// Tiled editor version that created the file.
  final String? tiledVersion;

  /// Map orientation.
  final MapOrientation orientation;

  /// Tile render order.
  final RenderOrder renderOrder;

  /// Map width in tiles.
  final int width;

  /// Map height in tiles.
  final int height;

  /// Tile width in pixels.
  final int tileWidth;

  /// Tile height in pixels.
  final int tileHeight;

  /// Whether this is an infinite map.
  final bool infinite;

  /// Background color.
  final Color? backgroundColor;

  /// Next available layer ID.
  final int? nextLayerId;

  /// Next available object ID.
  final int? nextObjectId;

  /// Stagger axis (for staggered/hexagonal maps).
  final StaggerAxis? staggerAxis;

  /// Stagger index (for staggered/hexagonal maps).
  final StaggerIndex? staggerIndex;

  /// Hex side length (for hexagonal maps, in pixels).
  final int? hexSideLength;

  /// Map tilesets.
  final List<Tileset> tilesets;

  /// Map layers (tile layers, object groups, image layers, group layers).
  final List<Layer> layers;

  /// Custom map properties.
  final TiledProperties properties;

  const TiledMap({
    this.version = '1.0',
    this.tiledVersion,
    this.orientation = MapOrientation.orthogonal,
    this.renderOrder = RenderOrder.rightDown,
    required this.width,
    required this.height,
    required this.tileWidth,
    required this.tileHeight,
    this.infinite = false,
    this.backgroundColor,
    this.nextLayerId,
    this.nextObjectId,
    this.staggerAxis,
    this.staggerIndex,
    this.hexSideLength,
    this.tilesets = const [],
    this.layers = const [],
    TiledProperties? properties,
  }) : properties = properties ?? const TiledProperties();

  /// Get all tile layers (recursive through group layers).
  List<TileLayer> get tileLayers => _collectLayers<TileLayer>(layers);

  /// Get all object groups (recursive through group layers).
  List<ObjectGroup> get objectGroups => _collectLayers<ObjectGroup>(layers);

  /// Get all image layers (recursive through group layers).
  List<ImageLayer> get imageLayers => _collectLayers<ImageLayer>(layers);

  /// Find the tileset that contains the given global tile ID.
  Tileset? findTilesetForGid(int gid) {
    if (gid <= 0) return null;
    Tileset? result;
    for (final ts in tilesets) {
      if (ts.firstGid <= gid) {
        if (result == null || ts.firstGid > result.firstGid) {
          result = ts;
        }
      }
    }
    return result;
  }

  /// Map pixel dimensions.
  int get pixelWidth => width * tileWidth;
  int get pixelHeight => height * tileHeight;

  List<T> _collectLayers<T extends Layer>(List<Layer> layers) {
    final result = <T>[];
    for (final layer in layers) {
      if (layer is T) result.add(layer);
      if (layer is GroupLayer) {
        result.addAll(_collectLayers<T>(layer.layers));
      }
    }
    return result;
  }
}
