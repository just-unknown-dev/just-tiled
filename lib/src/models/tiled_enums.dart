/// Enumerations for the Tiled Map Editor format.
library;

/// Map orientation type.
enum MapOrientation {
  /// A grid of rectangles.
  orthogonal,

  /// A grid of diamonds, seen at an angle.
  isometric,

  /// Diamonds in rows (or columns) that shift every other row by half a
  /// tile.
  staggered,

  /// Hexagons, shifted every other row or column like [staggered].
  hexagonal;

  /// The orientation named [value] in a map file; [orthogonal] for any
  /// other value.
  static MapOrientation fromString(String value) {
    return MapOrientation.values.firstWhere(
      (e) => e.name == value,
      orElse: () => MapOrientation.orthogonal,
    );
  }
}

/// Tile render order.
enum RenderOrder {
  /// Rows top to bottom, each left to right. Tiled's default.
  rightDown('right-down'),

  /// Rows bottom to top, each left to right.
  rightUp('right-up'),

  /// Rows top to bottom, each right to left.
  leftDown('left-down'),

  /// Rows bottom to top, each right to left.
  leftUp('left-up');

  /// How map files write this render order.
  final String tmxValue;

  const RenderOrder(this.tmxValue);

  /// The render order map files write as [value]; [rightDown] for any other
  /// value.
  static RenderOrder fromString(String value) {
    return RenderOrder.values.firstWhere(
      (e) => e.tmxValue == value,
      orElse: () => RenderOrder.rightDown,
    );
  }
}

/// Stagger axis for staggered / hexagonal maps.
enum StaggerAxis {
  /// Every other column is shifted down.
  x,

  /// Every other row is shifted right. Tiled's default.
  y;

  /// The axis named [value] in a map file; [y] for any other value.
  static StaggerAxis fromString(String value) {
    return StaggerAxis.values.firstWhere(
      (e) => e.name == value,
      orElse: () => StaggerAxis.y,
    );
  }
}

/// Stagger index for staggered / hexagonal maps.
enum StaggerIndex {
  /// The even rows or columns are shifted.
  even,

  /// The odd rows or columns are shifted. Tiled's default.
  odd;

  /// The index named [value] in a map file; [odd] for any other value.
  static StaggerIndex fromString(String value) {
    return StaggerIndex.values.firstWhere(
      (e) => e.name == value,
      orElse: () => StaggerIndex.odd,
    );
  }
}

/// Object draw order within an object group.
enum DrawOrder {
  /// Objects lower on the map draw over those above them.
  topDown('topdown'),

  /// Objects draw in the order they are listed.
  index_('index');

  /// The TMX attribute string used to represent this draw order in `.tmx` files.
  final String tmxValue;

  const DrawOrder(this.tmxValue);

  /// Parses a TMX `draworder` attribute [value] into a [DrawOrder].
  ///
  /// Defaults to [DrawOrder.topDown] for any unrecognised value.
  static DrawOrder fromString(String value) {
    return DrawOrder.values.firstWhere(
      (e) => e.tmxValue == value,
      orElse: () => DrawOrder.topDown,
    );
  }
}

/// Which point of a tile object's image sits on the object's position.
enum ObjectAlignment {
  /// Not set: bottom-left on orthogonal maps, bottom-centre on isometric
  /// ones.
  unspecified,

  /// The top-left corner.
  topleft,

  /// The middle of the top edge.
  top,

  /// The top-right corner.
  topright,

  /// The middle of the left edge.
  left,

  /// The centre.
  center,

  /// The middle of the right edge.
  right,

  /// The bottom-left corner.
  bottomleft,

  /// The middle of the bottom edge.
  bottom,

  /// The bottom-right corner.
  bottomright;

  /// The alignment named [value] in a tileset file; [unspecified] for any
  /// other value, or none.
  static ObjectAlignment fromString(String? value) => ObjectAlignment.values
      .firstWhere((e) => e.name == value, orElse: () => unspecified);
}

/// Whether a tileset's tiles draw at their own size or the map's grid size.
enum TileRenderSize {
  /// Each tile at the size of its image. Tiled's default.
  tile,

  /// Each tile scaled to the map's grid cell, as [FillMode] says.
  grid;

  /// The size named [value] in a tileset file; [tile] for any other value,
  /// or none.
  static TileRenderSize fromString(String? value) => TileRenderSize.values
      .firstWhere((e) => e.name == value, orElse: () => tile);
}

/// How a tile drawn at the grid size fills its cell.
enum FillMode {
  /// Stretched to fill the cell. Tiled's default.
  stretch('stretch'),

  /// Scaled to fit inside the cell, keeping its proportions.
  preserveAspectFit('preserve-aspect-fit');

  /// How tileset files write this fill mode.
  final String tmxValue;

  const FillMode(this.tmxValue);

  /// The fill mode tileset files write as [value]; [stretch] for any other
  /// value, or none.
  static FillMode fromString(String? value) => FillMode.values.firstWhere(
    (e) => e.tmxValue == value,
    orElse: () => stretch,
  );
}

/// How a tile layer's `data` element stores its tiles.
enum LayerEncoding {
  /// Little-endian 32-bit ids in base64, perhaps compressed.
  base64,

  /// Comma-separated numbers.
  csv,

  /// A `tile` element per tile (deprecated by Tiled).
  xml;

  /// The encoding named [value] in a map file; [xml], which has no name,
  /// for none or any other value.
  static LayerEncoding fromString(String? value) {
    if (value == null) return LayerEncoding.xml;
    return LayerEncoding.values.firstWhere(
      (e) => e.name == value,
      orElse: () => LayerEncoding.xml,
    );
  }
}

/// How base64 tile data in a layer's `data` element is compressed.
enum LayerCompression {
  /// Not compressed.
  none,

  /// gzip.
  gzip,

  /// zlib. Tiled's default.
  zlib,

  /// Zstandard.
  zstd;

  /// The compression named [value] in a map file; [none] for none or any
  /// other value.
  static LayerCompression fromString(String? value) {
    if (value == null || value.isEmpty) return LayerCompression.none;
    return LayerCompression.values.firstWhere(
      (e) => e.name == value,
      orElse: () => LayerCompression.none,
    );
  }
}
