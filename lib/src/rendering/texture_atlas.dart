/// Texture atlas for mapping tile GIDs to source rectangles.
library;

import 'dart:ui' as ui;

import '../models/models.dart';

/// Maps global tile IDs (GIDs) to source rectangles within a tileset image.
///
/// For multi-tileset maps, create one [TextureAtlas] per tileset image.
class TextureAtlas {
  /// The tileset image.
  final ui.Image image;

  /// The tileset metadata.
  final Tileset tileset;

  /// Cached source rectangles keyed by global tile ID.
  final Map<int, ui.Rect> _sourceRects = {};

  /// Create a texture atlas for the given [tileset] and its loaded [image].
  TextureAtlas({required this.image, required this.tileset}) {
    _precomputeRects();
  }

  /// Pre-compute all source rectangles for this tileset.
  void _precomputeRects() {
    for (int localId = 0; localId < tileset.tileCount; localId++) {
      final gid = tileset.firstGid + localId;
      _sourceRects[gid] = tileset.getSourceRect(localId);
    }
  }

  /// Get the source rectangle for a global tile ID.
  ///
  /// Returns null if the GID doesn't belong to this tileset.
  ui.Rect? getSourceRect(int gid) {
    if (gid < tileset.firstGid ||
        gid >= tileset.firstGid + tileset.tileCount) {
      return null;
    }
    return _sourceRects[gid];
  }

  /// Whether this atlas contains the given GID.
  bool containsGid(int gid) =>
      gid >= tileset.firstGid && gid < tileset.firstGid + tileset.tileCount;

  /// The image width.
  int get imageWidth => image.width;

  /// The image height.
  int get imageHeight => image.height;

  /// Dispose the image resource.
  void dispose() {
    image.dispose();
  }
}

/// Collection of texture atlases for a complete map.
///
/// Handles multi-tileset maps by routing GIDs to the correct atlas.
class TextureAtlasCollection {
  /// All atlases, ordered by firstGid (descending for binary search).
  final List<TextureAtlas> _atlases;

  /// Create a collection from a list of atlases.
  TextureAtlasCollection(List<TextureAtlas> atlases)
      : _atlases = List.from(atlases)
          ..sort((a, b) => b.tileset.firstGid.compareTo(a.tileset.firstGid));

  /// Public read-only access to the atlas list.
  List<TextureAtlas> get atlases => List.unmodifiable(_atlases);

  /// Whether this collection has any atlases.
  bool get isEmpty => _atlases.isEmpty;

  /// Whether this collection has atlases.
  bool get isNotEmpty => _atlases.isNotEmpty;

  /// Find the atlas and source rect for a given GID.
  ///
  /// Returns null if no atlas contains this GID.
  ({TextureAtlas atlas, ui.Rect sourceRect})? lookup(int gid) {
    for (final atlas in _atlases) {
      final rect = atlas.getSourceRect(gid);
      if (rect != null) {
        return (atlas: atlas, sourceRect: rect);
      }
    }
    return null;
  }

  /// Dispose all atlas images.
  void dispose() {
    for (final atlas in _atlases) {
      atlas.dispose();
    }
  }
}
