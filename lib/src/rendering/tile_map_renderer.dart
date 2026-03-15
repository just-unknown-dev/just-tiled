/// High-performance tile map renderer using Canvas.drawRawAtlas.
///
/// Compiles tile layer data into Float32List buffers for GPU-batched rendering.
/// Supports orthogonal, isometric, staggered, and hexagonal projections.
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import '../models/models.dart';
import 'texture_atlas.dart';

/// Standalone tile map renderer using `Canvas.drawRawAtlas`.
///
/// This renderer does NOT depend on just_game_engine. It uses only dart:ui
/// and can be wrapped by an ECS system in the engine layer.
///
/// Usage:
/// ```dart
/// final renderer = TileMapRenderer(
///   tileLayer: tileLayer,
///   map: tiledMap,
///   atlas: textureAtlas,
/// );
/// renderer.compile();
/// renderer.render(canvas, cameraOffset, visibleBounds);
/// ```
class TileMapRenderer {
  /// The tile layer to render.
  final TileLayer tileLayer;

  /// The parent map (for orientation and tile size).
  final TiledMap map;

  /// The texture atlas for this layer's tiles.
  final TextureAtlas atlas;

  /// Compiled transform buffer for drawRawAtlas.
  Float32List? _transforms;

  /// Compiled source rect buffer for drawRawAtlas.
  Float32List? _rects;

  /// Number of non-empty tiles compiled.
  int _tileCount = 0;

  /// Whether the buffers need recompilation.
  bool _dirty = true;

  /// Create a tile map renderer.
  TileMapRenderer({
    required this.tileLayer,
    required this.map,
    required this.atlas,
  });

  /// Compile tile geometry into Float32List buffers for drawRawAtlas.
  ///
  /// Call this once after loading, and again if tile data changes.
  void compile() {
    // Count non-empty tiles
    _tileCount = 0;
    for (final gid in tileLayer.data) {
      if (gid > 0 && atlas.containsGid(gid)) {
        _tileCount++;
      }
    }

    if (_tileCount == 0) {
      _transforms = null;
      _rects = null;
      _dirty = false;
      return;
    }

    // Each RSTransform is 4 floats: scos, ssin, tx, ty
    _transforms = Float32List(_tileCount * 4);
    // Each Rect is 4 floats: left, top, right, bottom
    _rects = Float32List(_tileCount * 4);

    int idx = 0;
    for (int i = 0; i < tileLayer.data.length; i++) {
      final gid = tileLayer.data[i];
      if (gid <= 0 || !atlas.containsGid(gid)) continue;

      final sourceRect = atlas.getSourceRect(gid);
      if (sourceRect == null) continue;

      final col = i % tileLayer.width;
      final row = i ~/ tileLayer.width;

      // Compute world position based on map orientation
      final pos = _tileToWorld(col, row);

      // Handle flip flags
      final flipH = i < tileLayer.flipHorizontal.length &&
          tileLayer.flipHorizontal[i];
      final flipV = i < tileLayer.flipVertical.length &&
          tileLayer.flipVertical[i];
      final flipD = i < tileLayer.flipDiagonal.length &&
          tileLayer.flipDiagonal[i];

      // Build RSTransform
      // RSTransform encodes: scos, ssin, tx, ty
      // where the transform matrix is:
      //   [scos, -ssin, tx]
      //   [ssin,  scos, ty]
      double scos = 1.0;
      double ssin = 0.0;
      double tx = pos.dx;
      double ty = pos.dy;

      if (flipD) {
        // Anti-diagonal flip = rotate 90° + flip horizontal
        // rotation = 90° → scos=0, ssin=1
        final tileW = map.tileWidth.toDouble();
        scos = 0.0;
        ssin = 1.0;
        tx += tileW;
        if (!flipH) {
          // Also flip vertical after rotation
          ssin = -1.0;
          tx -= tileW;
          ty += map.tileHeight.toDouble();
        }
      } else {
        if (flipH) {
          scos = -1.0;
          tx += map.tileWidth.toDouble();
        }
        if (flipV) {
          // Flip vertical: negate scos for Y, shift ty
          if (flipH) {
            // Both flips = 180° rotation
            scos = -1.0;
            ssin = 0.0; // unused in this context
            // Adjust: use actual rotation
            scos = -1.0;
            tx = pos.dx + map.tileWidth.toDouble();
            ty = pos.dy + map.tileHeight.toDouble();
          } else {
            // Vertical flip only — use RSTransform scale trick
            // RSTransform doesn't natively support non-uniform scale,
            // so we simulate with rotation + flip:
            // flipV = mirror over X axis → negate Y scale
            // We'll use a small workaround: 180° rotation + flipH
            scos = -1.0;
            ssin = 0.0;
            tx = pos.dx + map.tileWidth.toDouble();
            ty = pos.dy + map.tileHeight.toDouble();
          }
        }
      }

      // Write RSTransform: [scos, ssin, tx, ty]
      final tIdx = idx * 4;
      _transforms![tIdx] = scos;
      _transforms![tIdx + 1] = ssin;
      _transforms![tIdx + 2] = tx;
      _transforms![tIdx + 3] = ty;

      // Write source Rect: [left, top, right, bottom]
      _rects![tIdx] = sourceRect.left;
      _rects![tIdx + 1] = sourceRect.top;
      _rects![tIdx + 2] = sourceRect.right;
      _rects![tIdx + 3] = sourceRect.bottom;

      idx++;
    }

    _dirty = false;
  }

  /// Render the tile layer.
  ///
  /// [canvas] is the Flutter canvas.
  /// [cameraOffset] is the camera's world-space position.
  /// [visibleBounds] is the visible world-space rectangle (for culling).
  void render(ui.Canvas canvas, ui.Offset cameraOffset, ui.Rect? visibleBounds) {
    if (_dirty) compile();
    if (_transforms == null || _rects == null || _tileCount == 0) return;

    // For frustum culling, we could rebuild buffers with only visible tiles.
    // For now, we use the full buffer and let the GPU clip — this is often
    // faster for small-to-medium maps due to draw call batching.

    // If we have a visible bounds and a large map, do culled rendering
    if (visibleBounds != null && _shouldCull()) {
      _renderCulled(canvas, visibleBounds);
      return;
    }

    // Apply layer offset
    canvas.save();
    canvas.translate(tileLayer.offsetX, tileLayer.offsetY);

    // Apply layer opacity
    final paint = ui.Paint();
    if (tileLayer.opacity < 1.0) {
      paint.color = ui.Color.fromRGBO(255, 255, 255, tileLayer.opacity);
    }
    if (tileLayer.tintColor != null) {
      paint.colorFilter = ui.ColorFilter.mode(
        tileLayer.tintColor!,
        ui.BlendMode.modulate,
      );
    }

    canvas.drawRawAtlas(
      atlas.image,
      _transforms!,
      _rects!,
      null, // colors
      ui.BlendMode.srcOver,
      visibleBounds, // cullRect
      paint,
    );

    canvas.restore();
  }

  /// Whether this map is large enough to benefit from tile-level culling.
  bool _shouldCull() {
    return tileLayer.width * tileLayer.height > 10000;
  }

  /// Render with viewport frustum culling at the tile level.
  void _renderCulled(ui.Canvas canvas, ui.Rect visibleBounds) {
    // Convert visible bounds to tile coordinates
    final tw = map.tileWidth.toDouble();
    final th = map.tileHeight.toDouble();

    int startCol, endCol, startRow, endRow;

    switch (map.orientation) {
      case MapOrientation.orthogonal:
        startCol = ((visibleBounds.left - tileLayer.offsetX) / tw).floor().clamp(0, tileLayer.width - 1);
        endCol = ((visibleBounds.right - tileLayer.offsetX) / tw).ceil().clamp(0, tileLayer.width - 1);
        startRow = ((visibleBounds.top - tileLayer.offsetY) / th).floor().clamp(0, tileLayer.height - 1);
        endRow = ((visibleBounds.bottom - tileLayer.offsetY) / th).ceil().clamp(0, tileLayer.height - 1);
        break;
      default:
        // For non-orthogonal, render all tiles (culling math is complex)
        startCol = 0;
        endCol = tileLayer.width - 1;
        startRow = 0;
        endRow = tileLayer.height - 1;
        break;
    }

    // Build culled buffers
    final maxTiles = (endCol - startCol + 1) * (endRow - startRow + 1);
    final culledTransforms = Float32List(maxTiles * 4);
    final culledRects = Float32List(maxTiles * 4);
    int count = 0;

    for (int row = startRow; row <= endRow; row++) {
      for (int col = startCol; col <= endCol; col++) {
        final i = row * tileLayer.width + col;
        if (i >= tileLayer.data.length) continue;

        final gid = tileLayer.data[i];
        if (gid <= 0 || !atlas.containsGid(gid)) continue;

        final sourceRect = atlas.getSourceRect(gid);
        if (sourceRect == null) continue;

        final pos = _tileToWorld(col, row);

        // Handle flip flags
        final flipH = i < tileLayer.flipHorizontal.length &&
            tileLayer.flipHorizontal[i];
        final flipV = i < tileLayer.flipVertical.length &&
            tileLayer.flipVertical[i];

        double scos = 1.0;
        double ssin = 0.0;
        double tx = pos.dx;
        double ty = pos.dy;

        if (flipH) {
          scos = -1.0;
          tx += tw;
        }
        if (flipV) {
          scos = -scos;
          if (!flipH) tx += tw;
          ty += th;
        }

        final tIdx = count * 4;
        culledTransforms[tIdx] = scos;
        culledTransforms[tIdx + 1] = ssin;
        culledTransforms[tIdx + 2] = tx;
        culledTransforms[tIdx + 3] = ty;

        culledRects[tIdx] = sourceRect.left;
        culledRects[tIdx + 1] = sourceRect.top;
        culledRects[tIdx + 2] = sourceRect.right;
        culledRects[tIdx + 3] = sourceRect.bottom;

        count++;
      }
    }

    if (count == 0) return;

    canvas.save();
    canvas.translate(tileLayer.offsetX, tileLayer.offsetY);

    final paint = ui.Paint();
    if (tileLayer.opacity < 1.0) {
      paint.color = ui.Color.fromRGBO(255, 255, 255, tileLayer.opacity);
    }

    // Use only the filled portion of the buffers
    final usedTransforms = Float32List.sublistView(culledTransforms, 0, count * 4);
    final usedRects = Float32List.sublistView(culledRects, 0, count * 4);

    canvas.drawRawAtlas(
      atlas.image,
      usedTransforms,
      usedRects,
      null,
      ui.BlendMode.srcOver,
      null,
      paint,
    );

    canvas.restore();
  }

  /// Convert tile grid coordinates to world pixel coordinates.
  ui.Offset _tileToWorld(int col, int row) {
    final tw = map.tileWidth.toDouble();
    final th = map.tileHeight.toDouble();

    switch (map.orientation) {
      case MapOrientation.orthogonal:
        return ui.Offset(col * tw, row * th);

      case MapOrientation.isometric:
        final originX = map.height * tw / 2;
        return ui.Offset(
          (col - row) * tw / 2 + originX,
          (col + row) * th / 2,
        );

      case MapOrientation.staggered:
        final staggerX = map.staggerAxis == StaggerAxis.x;
        final staggerEven = map.staggerIndex == StaggerIndex.even;

        if (staggerX) {
          final isStaggered = staggerEven ? (col % 2 == 0) : (col % 2 != 0);
          return ui.Offset(
            col * tw / 2,
            row * th + (isStaggered ? th / 2 : 0),
          );
        } else {
          final isStaggered = staggerEven ? (row % 2 == 0) : (row % 2 != 0);
          return ui.Offset(
            col * tw + (isStaggered ? tw / 2 : 0),
            row * th / 2,
          );
        }

      case MapOrientation.hexagonal:
        final hexSide = (map.hexSideLength ?? 0).toDouble();
        final staggerX = map.staggerAxis == StaggerAxis.x;
        final staggerEven = map.staggerIndex == StaggerIndex.even;

        if (staggerX) {
          final colWidth = (tw + hexSide) / 2;
          final isStaggered = staggerEven ? (col % 2 == 0) : (col % 2 != 0);
          return ui.Offset(
            col * colWidth,
            row * th + (isStaggered ? th / 2 : 0),
          );
        } else {
          final rowHeight = (th + hexSide) / 2;
          final isStaggered = staggerEven ? (row % 2 == 0) : (row % 2 != 0);
          return ui.Offset(
            col * tw + (isStaggered ? tw / 2 : 0),
            row * rowHeight,
          );
        }
    }
  }

  /// Get the world-space bounding box of the entire tile layer.
  ui.Rect get worldBounds {
    final tw = map.tileWidth.toDouble();
    final th = map.tileHeight.toDouble();

    switch (map.orientation) {
      case MapOrientation.orthogonal:
        return ui.Rect.fromLTWH(
          tileLayer.offsetX,
          tileLayer.offsetY,
          tileLayer.width * tw,
          tileLayer.height * th,
        );

      case MapOrientation.isometric:
        final totalWidth = (tileLayer.width + tileLayer.height) * tw / 2;
        final totalHeight = (tileLayer.width + tileLayer.height) * th / 2;
        return ui.Rect.fromLTWH(
          tileLayer.offsetX,
          tileLayer.offsetY,
          totalWidth,
          totalHeight,
        );

      default:
        // Approximate bounds for staggered/hex
        return ui.Rect.fromLTWH(
          tileLayer.offsetX,
          tileLayer.offsetY,
          tileLayer.width * tw + tw,
          tileLayer.height * th + th,
        );
    }
  }

  /// Mark buffers as needing recompilation.
  void invalidate() {
    _dirty = true;
  }
}
