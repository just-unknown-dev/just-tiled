/// Tiled tileset model.
library;

import 'dart:ui';

import 'enums.dart';
import 'tile.dart';
import 'tiled_object.dart';
import 'wang.dart';

/// How tile objects of an isometric tileset are laid out in Tiled's
/// tileset view — the `<grid>` element.
class TilesetGrid {
  /// A grid of [width] by [height] pixel cells.
  const TilesetGrid({
    this.orientation = MapOrientation.orthogonal,
    this.width = 0,
    this.height = 0,
  });

  /// `orthogonal` or `isometric`.
  final MapOrientation orientation;

  /// Cell width in pixels.
  final int width;

  /// Cell height in pixels.
  final int height;
}

/// Which ways a Wang brush may turn this tileset's tiles to find a match.
class TilesetTransformations {
  /// Transformations, all off unless given.
  const TilesetTransformations({
    this.hflip = false,
    this.vflip = false,
    this.rotate = false,
    this.preferUntransformed = false,
  });

  /// Tiles may be mirrored left to right.
  final bool hflip;

  /// Tiles may be mirrored top to bottom.
  final bool vflip;

  /// Tiles may be turned in 90° steps.
  final bool rotate;

  /// Tiles as drawn are preferred over transformed ones.
  final bool preferUntransformed;

  /// Whether any setting is on.
  bool get any => hflip || vflip || rotate || preferUntransformed;
}

/// A tileset definition.
///
/// Tilesets contain the image and tile metadata for a set of tiles.
/// They may be embedded in the TMX file or referenced externally via TSX.
class Tileset {
  /// First global tile ID for this tileset.
  final int firstGid;

  /// Tileset name.
  final String name;

  /// The tileset's class (Tiled 1.9+).
  final String className;

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

  /// Which point of a tile object's image sits on the object's position.
  final ObjectAlignment objectAlignment;

  /// Whether tiles draw at their own size or the map's grid size.
  final TileRenderSize tileRenderSize;

  /// How a tile drawn at the grid size fills its cell.
  final FillMode fillMode;

  /// Tiled's tileset-view grid, when the file has one.
  final TilesetGrid? grid;

  /// Which ways a Wang brush may turn tiles.
  final TilesetTransformations transformations;

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

  /// Terrain definitions.
  final List<WangSet> wangSets;

  /// Custom properties.
  final TiledProperties properties;

  /// External TSX source file (null if embedded).
  final String? source;

  /// A tileset whose tiles are numbered from [firstGid] in the map.
  const Tileset({
    required this.firstGid,
    this.name = '',
    this.className = '',
    this.tileWidth = 0,
    this.tileHeight = 0,
    this.spacing = 0,
    this.margin = 0,
    this.tileCount = 0,
    this.columns = 0,
    this.tileOffset = Offset.zero,
    this.objectAlignment = ObjectAlignment.unspecified,
    this.tileRenderSize = TileRenderSize.tile,
    this.fillMode = FillMode.stretch,
    this.grid,
    this.transformations = const TilesetTransformations(),
    this.imageSource,
    this.imageWidth,
    this.imageHeight,
    this.transparentColor,
    this.tiles = const {},
    this.wangSets = const [],
    this.source,
    TiledProperties? properties,
  }) : properties = properties ?? const TiledProperties();

  /// Whether every tile has an image of its own rather than a cut of one
  /// sheet.
  bool get isImageCollection => imageSource == null && columns == 0;

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
