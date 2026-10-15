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
/// One renderer draws one tile layer's tiles from one [TextureAtlas]: a
/// layer that uses several tilesets needs one renderer per atlas. Tiles are
/// placed as Tiled places them — a tile's bottom-left corner on its cell's
/// bottom-left corner, moved by the tileset's [Tileset.tileOffset] — with
/// every flip and 90° turn, in the map's render order (orthogonal maps;
/// other orientations draw right-down). Finite and infinite (chunked) layers
/// are drawn alike.
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

  /// RSTransforms (scos, ssin, tx, ty) of the compiled tiles, in draw order.
  Float32List _transforms = Float32List(0);

  /// Source rects (left, top, right, bottom) of the compiled tiles.
  Float32List _rects = Float32List(0);

  /// Number of tiles compiled.
  int _count = 0;

  /// Whether any tile is drawn from the atlas's mirrored image.
  bool _mirrored = false;

  /// The compiled rows in draw order: each row's sort key, and where its
  /// tiles start in the buffers ([_rowStarts] has one entry more).
  Int32List _rowKeys = Int32List(0);
  Int32List _rowStarts = Int32List(1);

  /// Each compiled tile's column sort key, ascending within a row.
  Int32List _colKeys = Int32List(0);

  /// Everything the tiles cover, in layer space (before the layer offset).
  ui.Rect _bounds = ui.Rect.zero;

  /// How far a tile reaches past its cell on each side, at most: tiles
  /// larger than the grid, and tile offsets. Culling widens by this much.
  double _reachLeft = 0;
  double _reachTop = 0;
  double _reachRight = 0;
  double _reachBottom = 0;

  /// Buffers the visible tiles are gathered into when culling, kept between
  /// frames.
  Float32List _visibleTransforms = Float32List(0);
  Float32List _visibleRects = Float32List(0);

  ui.Paint _paint = ui.Paint();

  /// Whether the buffers need recompilation.
  bool _dirty = true;

  /// Create a tile map renderer.
  TileMapRenderer({
    required this.tileLayer,
    required this.map,
    required this.atlas,
  });

  /// Number of tiles compiled: the layer's cells that hold one of the
  /// atlas's tiles.
  int get tileCount {
    if (_dirty) compile();
    return _count;
  }

  /// Compile tile geometry into Float32List buffers for drawRawAtlas.
  ///
  /// Call this once after loading, and again if tile data changes.
  void compile() {
    _dirty = false;
    final cells = _cellsInDrawOrder();
    final n = cells.length ~/ 3;

    _count = n;
    _transforms = Float32List(n * 4);
    _rects = Float32List(n * 4);
    _colKeys = Int32List(n);
    _mirrored = false;
    _reachLeft = _reachTop = _reachRight = _reachBottom = 0;
    _paint = _layerPaint();

    final up = _drawsUp;
    final left = _drawsLeft;
    final gridW = map.tileWidth.toDouble();
    final gridH = map.tileHeight.toDouble();
    final offset = atlas.tileset.tileOffset;
    final rowKeys = <int>[];
    final rowStarts = <int>[];
    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;

    for (var k = 0; k < n; k++) {
      final col = cells[k * 3];
      final row = cells[k * 3 + 1];
      final raw = cells[k * 3 + 2];
      final id = TiledGid.idOf(raw);
      final d = TiledGid.isFlippedDiagonally(raw);
      final h = TiledGid.isFlippedHorizontally(raw);
      final v = TiledGid.isFlippedVertically(raw);

      // Every Tiled flip is a turn of the tile or of its mirror image.
      // Flags apply diagonal first, then horizontal, then vertical: D+H is
      // a quarter turn clockwise, D+V one anticlockwise, H+V a half turn.
      final mirror = h ^ v ^ d;
      if (mirror) _mirrored = true;
      final src = mirror
          ? atlas.getMirroredSourceRect(id)!
          : atlas.getSourceRect(id)!;
      final w = src.width;
      final ht = src.height;
      final boxW = d ? ht : w;
      final boxH = d ? w : ht;

      final cell = _cellOrigin(col, row);
      final x = cell.dx + offset.dx;
      final y = cell.dy + gridH + offset.dy - boxH;

      double scos;
      double ssin;
      double tx;
      double ty;
      if (!d) {
        if (v) {
          // Half turn.
          scos = -1;
          ssin = 0;
          tx = x + w;
          ty = y + ht;
        } else {
          scos = 1;
          ssin = 0;
          tx = x;
          ty = y;
        }
      } else if (h) {
        // Quarter turn clockwise.
        scos = 0;
        ssin = 1;
        tx = x + ht;
        ty = y;
      } else {
        // Quarter turn anticlockwise.
        scos = 0;
        ssin = -1;
        tx = x;
        ty = y + w;
      }

      final i = k * 4;
      _transforms[i] = scos;
      _transforms[i + 1] = ssin;
      _transforms[i + 2] = tx;
      _transforms[i + 3] = ty;
      _rects[i] = src.left;
      _rects[i + 1] = src.top;
      _rects[i + 2] = src.right;
      _rects[i + 3] = src.bottom;

      final rowKey = up ? -row : row;
      if (rowKeys.isEmpty || rowKeys.last != rowKey) {
        rowKeys.add(rowKey);
        rowStarts.add(k);
      }
      _colKeys[k] = left ? -col : col;

      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (x + boxW > maxX) maxX = x + boxW;
      if (y + boxH > maxY) maxY = y + boxH;
      if (cell.dx - x > _reachLeft) _reachLeft = cell.dx - x;
      if (cell.dy - y > _reachTop) _reachTop = cell.dy - y;
      if (x + boxW - cell.dx - gridW > _reachRight) {
        _reachRight = x + boxW - cell.dx - gridW;
      }
      if (y + boxH - cell.dy - gridH > _reachBottom) {
        _reachBottom = y + boxH - cell.dy - gridH;
      }
    }

    rowStarts.add(n);
    _rowKeys = Int32List.fromList(rowKeys);
    _rowStarts = Int32List.fromList(rowStarts);
    _bounds = n == 0 ? ui.Rect.zero : ui.Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// The map's render order applies to orthogonal maps; Tiled draws the
  /// other orientations right-down.
  RenderOrder get _order => map.orientation == MapOrientation.orthogonal
      ? map.renderOrder
      : RenderOrder.rightDown;

  bool get _drawsUp =>
      _order == RenderOrder.rightUp || _order == RenderOrder.leftUp;

  bool get _drawsLeft =>
      _order == RenderOrder.leftDown || _order == RenderOrder.leftUp;

  /// The layer's cells holding one of the atlas's tiles, in draw order, as
  /// column, row, raw id triples.
  List<int> _cellsInDrawOrder() {
    final up = _drawsUp;
    final left = _drawsLeft;
    final out = <int>[];

    if (tileLayer.isChunked) {
      final found = <(int, int, int)>[];
      for (final chunk in tileLayer.chunks) {
        if (chunk.width <= 0) continue;
        for (var i = 0; i < chunk.data.length; i++) {
          final raw = chunk.data[i];
          final id = TiledGid.idOf(raw);
          if (id == 0 || !_drawable(id)) continue;
          found.add((
            chunk.x + i % chunk.width,
            chunk.y + i ~/ chunk.width,
            raw,
          ));
        }
      }
      found.sort((a, b) {
        final byRow = up ? b.$2.compareTo(a.$2) : a.$2.compareTo(b.$2);
        if (byRow != 0) return byRow;
        return left ? b.$1.compareTo(a.$1) : a.$1.compareTo(b.$1);
      });
      for (final (col, row, raw) in found) {
        out
          ..add(col)
          ..add(row)
          ..add(raw);
      }
      return out;
    }

    final width = tileLayer.width;
    final height = tileLayer.height;
    final length = tileLayer.data.length;
    if (width <= 0) return out;
    for (var r = 0; r < height; r++) {
      final row = up ? height - 1 - r : r;
      for (var c = 0; c < width; c++) {
        final col = left ? width - 1 - c : c;
        final index = row * width + col;
        if (index >= length) continue;
        final id = tileLayer.data[index];
        if (id <= 0 || !_drawable(id)) continue;
        out
          ..add(col)
          ..add(row)
          ..add(tileLayer.rawGidAt(index));
      }
    }
    return out;
  }

  /// Whether the atlas holds [id] with an image to draw.
  bool _drawable(int id) {
    if (!atlas.containsGid(id)) return false;
    final rect = atlas.getSourceRect(id);
    return rect != null && !rect.isEmpty;
  }

  ui.Paint _layerPaint() {
    final paint = ui.Paint();
    if (tileLayer.opacity < 1.0) {
      paint.color = ui.Color.fromRGBO(
        255,
        255,
        255,
        tileLayer.opacity.clamp(0.0, 1.0),
      );
    }
    final tint = tileLayer.tintColor;
    if (tint != null) {
      paint.colorFilter = ui.ColorFilter.mode(tint, ui.BlendMode.modulate);
    }
    return paint;
  }

  /// Render the tile layer.
  ///
  /// [canvas] is the Flutter canvas, already translated to the camera:
  /// `render` moves it only by the layer's offset. [cameraOffset] is not
  /// used. [visibleBounds] is the visible world-space rectangle; tiles
  /// outside it are skipped. Pass null to draw every tile.
  ///
  /// Draws with one `drawRawAtlas` call, in the map's render order.
  void render(
    ui.Canvas canvas,
    ui.Offset cameraOffset,
    ui.Rect? visibleBounds,
  ) {
    if (_dirty) compile();
    if (_count == 0) return;

    final image = _mirrored ? atlas.mirroredImage : atlas.image;
    final layerOffset = ui.Offset(tileLayer.offsetX, tileLayer.offsetY);

    Float32List transforms = _transforms;
    Float32List rects = _rects;
    ui.Rect? cullRect = _bounds;
    if (visibleBounds != null) {
      final visible = _gatherVisible(visibleBounds.shift(-layerOffset));
      if (visible == 0) return;
      if (visible < _count) {
        transforms = Float32List.sublistView(
          _visibleTransforms,
          0,
          visible * 4,
        );
        rects = Float32List.sublistView(_visibleRects, 0, visible * 4);
        cullRect = null;
      }
    }

    canvas.save();
    canvas.translate(layerOffset.dx, layerOffset.dy);
    canvas.drawRawAtlas(image, transforms, rects, null, null, cullRect, _paint);
    canvas.restore();
  }

  /// Gathers the tiles that may show inside [view] (layer space) into the
  /// visible buffers, in draw order, and returns how many there are. Returns
  /// [_count], gathering nothing, when every tile may show.
  int _gatherVisible(ui.Rect view) {
    final reach = ui.Rect.fromLTRB(
      view.left - _reachRight,
      view.top - _reachBottom,
      view.right + _reachLeft,
      view.bottom + _reachTop,
    );
    if (!reach.overlaps(_bounds)) return 0;
    if (reach.left <= _bounds.left &&
        reach.top <= _bounds.top &&
        reach.right >= _bounds.right &&
        reach.bottom >= _bounds.bottom) {
      return _count;
    }
    final range = _cellRange(reach);
    if (range == null) return _count;
    var (c0, c1, r0, r1) = range;
    if (_drawsUp) (r0, r1) = (-r1, -r0);
    if (_drawsLeft) (c0, c1) = (-c1, -c0);

    // First count, then copy, so the buffers grow at most once.
    var visible = 0;
    for (var pass = 0; pass < 2; pass++) {
      if (pass == 1) {
        if (visible == 0) return 0;
        if (visible == _count) return _count;
        if (_visibleTransforms.length < visible * 4) {
          final size = visible * 4 * 3 ~/ 2;
          _visibleTransforms = Float32List(size);
          _visibleRects = Float32List(size);
        }
      }
      var copied = 0;
      for (
        var row = _lowerBound(_rowKeys, 0, _rowKeys.length, r0);
        row < _rowKeys.length && _rowKeys[row] <= r1;
        row++
      ) {
        final start = _rowStarts[row];
        final end = _rowStarts[row + 1];
        final from = _lowerBound(_colKeys, start, end, c0);
        final to = _lowerBound(_colKeys, from, end, c1 + 1);
        if (from >= to) continue;
        if (pass == 0) {
          visible += to - from;
        } else {
          _visibleTransforms.setRange(
            copied * 4,
            (copied + to - from) * 4,
            _transforms,
            from * 4,
          );
          _visibleRects.setRange(
            copied * 4,
            (copied + to - from) * 4,
            _rects,
            from * 4,
          );
          copied += to - from;
        }
      }
    }
    return visible;
  }

  /// The first index in [start, end) of the ascending [keys] whose key is
  /// at least [key]; [end] if none is.
  static int _lowerBound(Int32List keys, int start, int end, int key) {
    var lo = start;
    var hi = end;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (keys[mid] < key) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  /// The columns and rows (first column, last column, first row, last row)
  /// whose cells may overlap [area] (layer space), or null when they can't
  /// be worked out and every tile should be drawn.
  (int, int, int, int)? _cellRange(ui.Rect area) {
    final tw = map.tileWidth.toDouble();
    final th = map.tileHeight.toDouble();
    if (tw <= 0 || th <= 0 || !area.isFinite) return null;

    switch (map.orientation) {
      case MapOrientation.orthogonal:
        return (
          (area.left / tw).floor(),
          (area.right / tw).floor(),
          (area.top / th).floor(),
          (area.bottom / th).floor(),
        );

      case MapOrientation.isometric:
        // A cell's diamond spans c - r ± 1 half-widths across and
        // c + r to c + r + 2 half-heights down.
        final originX = map.height * tw / 2;
        final across0 = ((area.left - originX) / (tw / 2)).floor() - 1;
        final across1 = ((area.right - originX) / (tw / 2)).ceil() + 1;
        final down0 = (area.top / (th / 2)).floor() - 2;
        final down1 = (area.bottom / (th / 2)).ceil();
        return (
          ((down0 + across0) / 2).floor(),
          ((down1 + across1) / 2).ceil(),
          ((down0 - across1) / 2).floor(),
          ((down1 - across0) / 2).ceil(),
        );

      case MapOrientation.staggered:
      case MapOrientation.hexagonal:
        final side = map.orientation == MapOrientation.hexagonal
            ? (map.hexSideLength ?? 0).toDouble()
            : 0.0;
        final staggerX = map.staggerAxis == StaggerAxis.x;
        final stepX = staggerX ? (tw + side) / 2 : tw;
        final stepY = staggerX ? th : (th + side) / 2;
        if (stepX <= 0 || stepY <= 0) return null;
        // A cell is tw by th, moved up to half a cell by the stagger.
        return (
          ((area.left - tw * 1.5) / stepX).floor(),
          (area.right / stepX).floor(),
          ((area.top - th * 1.5) / stepY).floor(),
          (area.bottom / stepY).floor(),
        );
    }
  }

  /// The top-left corner of cell ([col], [row])'s grid rectangle, which is
  /// the map's tile size, in layer space.
  ui.Offset _cellOrigin(int col, int row) {
    final tw = map.tileWidth.toDouble();
    final th = map.tileHeight.toDouble();

    switch (map.orientation) {
      case MapOrientation.orthogonal:
        return ui.Offset(col * tw, row * th);

      case MapOrientation.isometric:
        final originX = map.height * tw / 2;
        return ui.Offset(
          (col - row - 1) * tw / 2 + originX,
          (col + row) * th / 2,
        );

      case MapOrientation.staggered:
      case MapOrientation.hexagonal:
        final side = map.orientation == MapOrientation.hexagonal
            ? (map.hexSideLength ?? 0).toDouble()
            : 0.0;
        final staggerEven = map.staggerIndex == StaggerIndex.even;
        if (map.staggerAxis == StaggerAxis.x) {
          final staggered = (col & 1 == 1) != staggerEven;
          return ui.Offset(
            col * (tw + side) / 2,
            row * th + (staggered ? th / 2 : 0),
          );
        }
        final staggered = (row & 1 == 1) != staggerEven;
        return ui.Offset(
          col * tw + (staggered ? tw / 2 : 0),
          row * (th + side) / 2,
        );
    }
  }

  /// Get the world-space bounding box of the tile layer: everything its
  /// tiles cover, moved by the layer offset. A renderer with no tiles to
  /// draw gives the layer's grid instead (the offset alone for a chunked
  /// layer).
  ui.Rect get worldBounds {
    if (_dirty) compile();
    final offset = ui.Offset(tileLayer.offsetX, tileLayer.offsetY);
    if (_count > 0) return _bounds.shift(offset);
    if (tileLayer.isChunked) return offset & ui.Size.zero;

    final tw = map.tileWidth.toDouble();
    final th = map.tileHeight.toDouble();
    final w = tileLayer.width;
    final h = tileLayer.height;
    switch (map.orientation) {
      case MapOrientation.orthogonal:
        return ui.Rect.fromLTWH(offset.dx, offset.dy, w * tw, h * th);
      case MapOrientation.isometric:
        return ui.Rect.fromLTWH(
          offset.dx,
          offset.dy,
          (w + h) * tw / 2,
          (w + h) * th / 2,
        );
      case MapOrientation.staggered:
      case MapOrientation.hexagonal:
        return ui.Rect.fromLTWH(offset.dx, offset.dy, w * tw + tw, h * th + th);
    }
  }

  /// Mark buffers as needing recompilation.
  void invalidate() {
    _dirty = true;
  }

  /// Dispose the underlying [TextureAtlas] image resource.
  ///
  /// Call this when the renderer is no longer needed to release the GPU
  /// texture held by [atlas]. Renderers that share an atlas must not call
  /// it: dispose the atlas itself, once.
  void dispose() {
    atlas.dispose();
  }
}
