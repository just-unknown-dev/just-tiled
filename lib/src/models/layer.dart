/// Tiled layer models.
library;

import 'dart:ui';

import 'enums.dart';
import 'tiled_object.dart';

/// Base class for all layer types.
abstract class Layer {
  /// Unique layer ID.
  final int id;

  /// Layer name.
  final String name;

  /// Whether the layer is visible.
  final bool visible;

  /// Layer opacity (0.0–1.0).
  final double opacity;

  /// Horizontal offset in pixels.
  final double offsetX;

  /// Vertical offset in pixels.
  final double offsetY;

  /// Tint color applied to the layer.
  final Color? tintColor;

  /// Parallax scrolling factor (horizontal).
  final double parallelX;

  /// Parallax scrolling factor (vertical).
  final double parallelY;

  /// Custom properties.
  final TiledProperties properties;

  const Layer({
    required this.id,
    this.name = '',
    this.visible = true,
    this.opacity = 1.0,
    this.offsetX = 0,
    this.offsetY = 0,
    this.tintColor,
    this.parallelX = 1.0,
    this.parallelY = 1.0,
    TiledProperties? properties,
  }) : properties = properties ?? const TiledProperties();
}

/// A tile layer containing a grid of tile GIDs.
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

  /// Encoding used in the TMX source.
  final LayerEncoding encoding;

  /// Compression used in the TMX source.
  final LayerCompression compression;

  const TileLayer({
    required super.id,
    super.name,
    super.visible,
    super.opacity,
    super.offsetX,
    super.offsetY,
    super.tintColor,
    super.parallelX,
    super.parallelY,
    super.properties,
    required this.width,
    required this.height,
    required this.data,
    this.flipHorizontal = const [],
    this.flipVertical = const [],
    this.flipDiagonal = const [],
    this.encoding = LayerEncoding.csv,
    this.compression = LayerCompression.none,
  });
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
    super.visible,
    super.opacity,
    super.offsetX,
    super.offsetY,
    super.tintColor,
    super.parallelX,
    super.parallelY,
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

  /// Creates an image layer.
  const ImageLayer({
    required super.id,
    super.name,
    super.visible,
    super.opacity,
    super.offsetX,
    super.offsetY,
    super.tintColor,
    super.parallelX,
    super.parallelY,
    super.properties,
    this.imageSource,
    this.transparentColor,
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
    super.visible,
    super.opacity,
    super.offsetX,
    super.offsetY,
    super.tintColor,
    super.parallelX,
    super.parallelY,
    super.properties,
    this.layers = const [],
  });
}
