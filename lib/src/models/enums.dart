/// Enumerations for the Tiled Map Editor format.
library;

/// Map orientation type.
enum MapOrientation {
  orthogonal,
  isometric,
  staggered,
  hexagonal;

  static MapOrientation fromString(String value) {
    return MapOrientation.values.firstWhere(
      (e) => e.name == value,
      orElse: () => MapOrientation.orthogonal,
    );
  }
}

/// Tile render order.
enum RenderOrder {
  rightDown('right-down'),
  rightUp('right-up'),
  leftDown('left-down'),
  leftUp('left-up');

  final String tmxValue;
  const RenderOrder(this.tmxValue);

  static RenderOrder fromString(String value) {
    return RenderOrder.values.firstWhere(
      (e) => e.tmxValue == value,
      orElse: () => RenderOrder.rightDown,
    );
  }
}

/// Stagger axis for staggered / hexagonal maps.
enum StaggerAxis {
  x,
  y;

  static StaggerAxis fromString(String value) {
    return StaggerAxis.values.firstWhere(
      (e) => e.name == value,
      orElse: () => StaggerAxis.y,
    );
  }
}

/// Stagger index for staggered / hexagonal maps.
enum StaggerIndex {
  even,
  odd;

  static StaggerIndex fromString(String value) {
    return StaggerIndex.values.firstWhere(
      (e) => e.name == value,
      orElse: () => StaggerIndex.odd,
    );
  }
}

/// Object draw order within an object group.
enum DrawOrder {
  topDown('topdown'),
  index_('index');

  final String tmxValue;
  const DrawOrder(this.tmxValue);

  static DrawOrder fromString(String value) {
    return DrawOrder.values.firstWhere(
      (e) => e.tmxValue == value,
      orElse: () => DrawOrder.topDown,
    );
  }
}

/// Tile data encoding in <data> element.
enum LayerEncoding {
  base64,
  csv,
  xml;

  static LayerEncoding fromString(String? value) {
    if (value == null) return LayerEncoding.xml;
    return LayerEncoding.values.firstWhere(
      (e) => e.name == value,
      orElse: () => LayerEncoding.xml,
    );
  }
}

/// Tile data compression in <data> element.
enum LayerCompression {
  none,
  gzip,
  zlib,
  zstd;

  static LayerCompression fromString(String? value) {
    if (value == null || value.isEmpty) return LayerCompression.none;
    return LayerCompression.values.firstWhere(
      (e) => e.name == value,
      orElse: () => LayerCompression.none,
    );
  }
}
