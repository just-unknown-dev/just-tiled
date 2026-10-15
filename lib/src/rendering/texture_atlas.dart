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

  /// [image] and its mirror image, made on first use.
  ui.Image? _mirrored;

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
    if (gid < tileset.firstGid || gid >= tileset.firstGid + tileset.tileCount) {
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

  /// Whether [mirroredImage] puts the mirror below [image] rather than
  /// beside it: below for an image wider than it is tall, so the result
  /// grows along its shorter side.
  bool get _mirrorBelow => image.width > image.height;

  /// [image] with a copy of it, mirrored left to right, beside it (or below
  /// it, for an image wider than it is tall). Made on first use and owned
  /// by this atlas.
  ///
  /// `Canvas.drawRawAtlas` can rotate a tile but not mirror it, so
  /// `TileMapRenderer` draws a layer with mirrored tiles from this image:
  /// every Tiled flip is a turn of the tile or of its mirror.
  ui.Image get mirroredImage {
    final existing = _mirrored;
    if (existing != null) return existing;
    final w = image.width.toDouble();
    final h = image.height.toDouble();
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final paint = ui.Paint()..filterQuality = ui.FilterQuality.none;
    canvas.drawImage(image, ui.Offset.zero, paint);
    if (_mirrorBelow) {
      canvas.translate(w, h);
    } else {
      canvas.translate(2 * w, 0);
    }
    canvas.scale(-1, 1);
    canvas.drawImage(image, ui.Offset.zero, paint);
    final picture = recorder.endRecording();
    final mirrored = picture.toImageSync(
      _mirrorBelow ? image.width : image.width * 2,
      _mirrorBelow ? image.height * 2 : image.height,
    );
    picture.dispose();
    return _mirrored = mirrored;
  }

  /// The source rectangle of [gid]'s mirror image within [mirroredImage],
  /// or null if the GID doesn't belong to this tileset.
  ui.Rect? getMirroredSourceRect(int gid) {
    final rect = getSourceRect(gid);
    if (rect == null) return null;
    final w = image.width.toDouble();
    if (_mirrorBelow) {
      final h = image.height.toDouble();
      return ui.Rect.fromLTRB(
        w - rect.right,
        rect.top + h,
        w - rect.left,
        rect.bottom + h,
      );
    }
    return ui.Rect.fromLTRB(
      2 * w - rect.right,
      rect.top,
      2 * w - rect.left,
      rect.bottom,
    );
  }

  /// Dispose the image resources: [image], and [mirroredImage] if made.
  void dispose() {
    image.dispose();
    _mirrored?.dispose();
    _mirrored = null;
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
