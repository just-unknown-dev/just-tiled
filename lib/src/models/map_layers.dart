/// Tiled layer models.
library;

import 'dart:typed_data';
import 'dart:ui';

import 'tiled_enums.dart';
import 'tiled_gid.dart';
import 'tiled_object.dart';
import 'tiled_properties.dart';

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

  /// The settings every layer has; [id] is unique within the map.
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
  /// A chunk of [width] by [height] tiles whose top-left cell is ([x],
  /// [y]).
  const TileChunk({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.gids,
  });

  /// Column of the chunk's top-left cell, in tiles. May be negative.
  final int x;

  /// Row of the chunk's top-left cell, in tiles. May be negative.
  final int y;

  /// Width in tiles — 16 unless the map says otherwise.
  final int width;

  /// Height in tiles — 16 unless the map says otherwise.
  final int height;

  /// Raw global ids, flags included (see [TiledGid]), row by row: [width]
  /// × [height] of them.
  final Uint32List gids;
}

/// A tile layer containing a grid of tile GIDs.
///
/// A finite layer holds its tiles in [gids]: raw global ids, every flag
/// kept, 4 bytes a cell. An infinite map's layer holds [chunks] instead;
/// [gids] is then empty.
class TileLayer extends Layer {
  /// Layer width in tiles.
  final int width;

  /// Layer height in tiles.
  final int height;

  /// A finite layer's tiles, row by row: [width] × [height] raw global ids,
  /// with every flag Tiled sets, the hexagonal 120° one included. Take them
  /// apart with [TiledGid], or use [idAt]. Empty for an infinite map's
  /// layer, whose tiles are in [chunks].
  ///
  /// The list may be changed in place; a renderer of the layer then needs
  /// its `invalidate()`.
  final Uint32List gids;

  /// An infinite map's tiles; empty for a finite layer.
  final List<TileChunk> chunks;

  /// Encoding used in the TMX source.
  final LayerEncoding encoding;

  /// Compression used in the TMX source.
  final LayerCompression compression;

  /// A layer of [width] by [height] cells: tiles in [gids], or, for an
  /// infinite map, in [chunks].
  TileLayer({
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
    Uint32List? gids,
    this.chunks = const [],
    this.encoding = LayerEncoding.csv,
    this.compression = LayerCompression.none,
  }) : gids = gids ?? Uint32List(0);

  /// Whether the tiles are in [chunks] rather than [gids].
  bool get isChunked => chunks.isNotEmpty;

  /// The global id at [index] of [gids], without its flags; 0 for an empty
  /// cell.
  int idAt(int index) => TiledGid.idOf(gids[index]);
}

/// An object group layer containing map objects.
class ObjectGroup extends Layer {
  /// Draw order for objects.
  final DrawOrder drawOrder;

  /// Layer color for the editor.
  final Color? color;

  /// Objects within this group.
  final List<TiledObject> objects;

  /// An object layer holding [objects].
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

  /// Image width in pixels, when the file says.
  final int? imageWidth;

  /// Image height in pixels, when the file says.
  final int? imageHeight;

  /// Whether the image repeats across the map horizontally.
  final bool repeatX;

  /// Whether the image repeats across the map vertically.
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
