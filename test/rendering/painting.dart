// Drawing for real, for the rendering tests: paint into an image and read
// the pixels back, one letter per pixel.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:just_tiled/just_tiled.dart';

/// The colours the tests draw with, by letter.
const letters = {
  0xFFFF0000: 'R',
  0xFF00FF00: 'G',
  0xFF0000FF: 'B',
  0xFFFFFFFF: 'W',
  0xFFFFFF00: 'Y',
};

/// An image of [rows], a letter per pixel; `.` is transparent.
Future<ui.Image> letterImage(List<String> rows) {
  final byLetter = {for (final e in letters.entries) e.value: e.key};
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final paint = ui.Paint();
  for (var y = 0; y < rows.length; y++) {
    for (var x = 0; x < rows[y].length; x++) {
      final letter = rows[y][x];
      if (letter == '.') continue;
      paint.color = ui.Color(byLetter[letter]!);
      canvas.drawRect(
        ui.Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1),
        paint,
      );
    }
  }
  return recorder.endRecording().toImage(rows[0].length, rows.length);
}

/// What [draw] paints on a [width] × [height] canvas, as rows of letters:
/// `.` for nothing, `?` for a colour not in [letters].
Future<List<String>> painted(
  int width,
  int height,
  void Function(ui.Canvas canvas) draw,
) async {
  final recorder = ui.PictureRecorder();
  draw(ui.Canvas(recorder));
  final image = await recorder.endRecording().toImage(width, height);
  final bytes = (await image.toByteData(
    format: ui.ImageByteFormat.rawStraightRgba,
  ))!;
  return [
    for (var y = 0; y < height; y++)
      [
        for (var x = 0; x < width; x++)
          () {
            final o = (y * width + x) * 4;
            final a = bytes.getUint8(o + 3);
            if (a == 0) return '.';
            final argb =
                (a << 24 |
                        bytes.getUint8(o) << 16 |
                        bytes.getUint8(o + 1) << 8 |
                        bytes.getUint8(o + 2))
                    .toUnsigned(32);
            return letters[argb] ?? '?';
          }(),
      ].join(),
  ];
}

/// A layer of raw ids, flags included.
TileLayer rawLayer(
  int width,
  int height,
  List<int> raws, {
  double offsetX = 0,
  double offsetY = 0,
  double opacity = 1,
  ui.Color? tint,
}) => TileLayer(
  id: 1,
  width: width,
  height: height,
  offsetX: offsetX,
  offsetY: offsetY,
  opacity: opacity,
  tintColor: tint,
  gids: Uint32List.fromList(raws),
);

Tileset stripTileset(
  int tileWidth,
  int tileHeight,
  int count, {
  ui.Offset tileOffset = ui.Offset.zero,
}) => Tileset(
  firstGid: 1,
  tileWidth: tileWidth,
  tileHeight: tileHeight,
  tileCount: count,
  columns: count,
  tileOffset: tileOffset,
);

TiledMap smallMap(
  int width,
  int height, {
  int tileWidth = 2,
  int tileHeight = 2,
  MapOrientation orientation = MapOrientation.orthogonal,
  RenderOrder renderOrder = RenderOrder.rightDown,
  bool infinite = false,
}) => TiledMap(
  width: width,
  height: height,
  tileWidth: tileWidth,
  tileHeight: tileHeight,
  orientation: orientation,
  renderOrder: renderOrder,
  infinite: infinite,
);

/// The flip flags.
const h = TiledGid.flipHorizontal;
const v = TiledGid.flipVertical;
const d = TiledGid.flipDiagonal;
