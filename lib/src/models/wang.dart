/// Wang sets: Tiled's terrain definitions.
library;

import 'dart:ui';

import 'tiled_object.dart';

/// What a Wang set matches tiles by.
enum WangSetType {
  /// The four corners of a tile.
  corner,

  /// The four edges of a tile.
  edge,

  /// Corners and edges together.
  mixed;

  static WangSetType fromString(String? value) => WangSetType.values
      .firstWhere((e) => e.name == value, orElse: () => WangSetType.corner);
}

/// One terrain of a Wang set: grass, water, a road.
class WangColor {
  const WangColor({
    this.name = '',
    this.className = '',
    this.color = const Color(0xFFFF0000),
    this.tile = -1,
    this.probability = 1.0,
    TiledProperties? properties,
  }) : properties = properties ?? const TiledProperties();

  final String name;
  final String className;

  /// How the editor shows it.
  final Color color;

  /// A tile that stands for it, or -1.
  final int tile;

  /// How often a brush picks tiles of this colour, relative to the others.
  final double probability;

  final TiledProperties properties;
}

/// A set of terrains and which corners or edges of which tiles carry them.
///
/// A Wang id has eight slots, clockwise from the top: top, top-right,
/// right, bottom-right, bottom, bottom-left, left, top-left. Edge slots are
/// the even ones, corner slots the odd ones. Each slot holds a colour index
/// (1-based), or 0 for "none".
class WangSet {
  const WangSet({
    this.name = '',
    this.className = '',
    this.type = WangSetType.corner,
    this.tile = -1,
    this.colors = const [],
    this.wangTiles = const {},
    TiledProperties? properties,
  }) : properties = properties ?? const TiledProperties();

  final String name;
  final String className;
  final WangSetType type;

  /// A tile that stands for the set, or -1.
  final int tile;

  /// The terrains, colour 1 first.
  final List<WangColor> colors;

  /// The Wang id of each tile that has one, by local tile id: eight slots.
  final Map<int, List<int>> wangTiles;

  final TiledProperties properties;
}
