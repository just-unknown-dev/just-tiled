/// Tiled layer models.
library;

import 'dart:typed_data';
import 'dart:ui';

import 'enums.dart';
import 'gid.dart';
import 'tiled_object.dart';

/// Base class for all layer types.
abstract class Layer {
  /// Unique layer ID.
  final int id;

  /// Layer name.
  final String name;

  /// The layer's class (Tiled 1.9+; `type` before that).
  final String className;

  /// Whether the layer is visible.
  final bool visible;

  /// Whether the layer is locked against editing in Tiled.
  final bool locked;

  /// Layer opacity (0.0–1.0).
  final double opacity;

  /// Horizontal offset in pixels.
  final double offsetX;

  /// Vertical offset in pixels.
  final double offsetY;

  /// Tint color applied to the layer.
  final Color? tintColor;

  /// Parallax scrolling factor (horizontal).
  final double parallaxX;

  /// Parallax scrolling factor (vertical).
  final double parallaxY;

  /// Custom properties.
  final TiledProperties properties;

  const Layer({
    required this.id,
    this.name = '',
    this.className = '',
    this.visible = true,
    this.locked = false,
    this.opacity = 1.0,
    this.offsetX = 0,
    this.offsetY = 0,
    this.tintColor,
    this.parallaxX = 1.0,
    this.parallaxY = 1.0,
    TiledProperties? properties,
  }) : properties = properties ?? const TiledProperties();
}

/// A rectangle of an infinite map's tile layer.
class TileChunk {
  const TileChunk({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.data,
  });

  /// Top-left cell of the chunk, in tiles. May be negative.
  final int x;
  final int y;

  /// Size in tiles — 16×16 unless the map says otherwise.
  final int width;
  final int height;

  /// Raw global ids, flags included, row by row.
  final Uint32List data;
}

/// A tile layer containing a grid of tile GIDs.
///
/// A finite layer holds its tiles in [data] (ids without flags) plus the
/// three flip lists, and in [rawData] (ids with their flags) when parsed or
/// built with it. An infinite map's layer holds [chunks] instead; [data] is
/// then empty.
class TileLayer extends Layer {
  /// Layer width in tiles.
  final int width;

  /// Layer height in tiles.
  final int height;

  /// Decoded tile data (global IDs with flip flags stripped).
  final List<int> data;

  /// Horizontal flip flags per tile (indexed same as [data]).
  final List<bool> flipHorizontal;

  /// Vertical flip flags per tile.
  final List<bool> flipVertical;

  /// Anti-diagonal flip flags per tile.
  final List<bool> flipDiagonal;

  /// Raw global ids with every flag, including the hexagonal 120° one,
  /// indexed like [data]. Null when the layer was built from [data] alone.
  final Uint32List? rawData;

  /// An infinite map's tiles; empty for a finite layer.
  final List<TileChunk> chunks;

  /// Encoding used in the TMX source.
  final LayerEncoding encoding;

  /// Compression used in the TMX source.
  final LayerCompression compression;

  const TileLayer({
    required super.id,
    super.name,
    super.className,
    super.visible,
    super.locked,
    super.opacity,
    super.offsetX,
    super.offsetY,
    super.tintColor,
    super.parallaxX,
    super.parallaxY,
    super.properties,
    required this.width,
    required this.height,
    required this.data,
    this.flipHorizontal = const [],
    this.flipVertical = const [],
    this.flipDiagonal = const [],
    this.rawData,
    this.chunks = const [],
    this.encoding = LayerEncoding.csv,
    this.compression = LayerCompression.none,
  });

  /// Whether the tiles are in [chunks] rather than [data].
  bool get isChunked => chunks.isNotEmpty;

  /// The raw global id (flags included) at [index] of a finite layer.
  int rawGidAt(int index) {
    final raw = rawData;
    if (raw != null) return raw[index];
    var flags = 0;
    if (index < flipHorizontal.length && flipHorizontal[index]) {
      flags |= TiledGid.flipHorizontal;
    }
    if (index < flipVertical.length && flipVertical[index]) {
      flags |= TiledGid.flipVertical;
    }
    if (index < flipDiagonal.length && flipDiagonal[index]) {
      flags |= TiledGid.flipDiagonal;
    }
    return TiledGid.compose(data[index], flags);
  }

  /// Every raw global id of a finite layer, row by row.
  Uint32List get rawGids =>
      rawData ?? Uint32List.fromList([for (var i = 0; i < data.length; i++) rawGidAt(i)]);
}

/// An object group layer containing map objects.
class ObjectGroup extends Layer {
  /// Draw order for objects.
  final DrawOrder drawOrder;

  /// Layer color for the editor.
  final Color? color;

  /// Objects within this group.
  final List<TiledObject> objects;

  const ObjectGroup({
    required super.id,
    super.name,
    super.className,
    super.visible,
    super.locked,
    super.opacity,
    super.offsetX,
    super.offsetY,
    super.tintColor,
    super.parallaxX,
    super.parallaxY,
    super.properties,
    this.drawOrder = DrawOrder.topDown,
    this.color,
    this.objects = const [],
  });
}

/// An image layer.
class ImageLayer extends Layer {
  /// Image source path.
  final String? imageSource;

  /// Transparent color key.
  final Color? transparentColor;

  /// Image size in pixels, when the file says.
  final int? imageWidth;
  final int? imageHeight;

  /// Whether the image repeats across the map horizontally / vertically.
  final bool repeatX;
  final bool repeatY;

  /// Creates an image layer.
  const ImageLayer({
    required super.id,
    super.name,
    super.className,
    super.visible,
    super.locked,
    super.opacity,
    super.offsetX,
    super.offsetY,
    super.tintColor,
    super.parallaxX,
    super.parallaxY,
    super.properties,
    this.imageSource,
    this.transparentColor,
    this.imageWidth,
    this.imageHeight,
    this.repeatX = false,
    this.repeatY = false,
  });
}

/// A group layer containing child layers.
class GroupLayer extends Layer {
  /// Child layers.
  final List<Layer> layers;

  /// Creates a group layer with optional [layers] as children.
  const GroupLayer({
    required super.id,
    super.name,
    super.className,
    super.visible,
    super.locked,
    super.opacity,
    super.offsetX,
    super.offsetY,
    super.tintColor,
    super.parallaxX,
    super.parallaxY,
    super.properties,
    this.layers = const [],
  });
}
