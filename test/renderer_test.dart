// The renderer, drawn for real: each test paints into an image and reads
// the pixels back, one letter per pixel.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:just_tiled/just_tiled.dart';

const _letters = {
  0xFFFF0000: 'R',
  0xFF00FF00: 'G',
  0xFF0000FF: 'B',
  0xFFFFFFFF: 'W',
  0xFFFFFF00: 'Y',
};

/// An image of [rows], a letter per pixel; `.` is transparent.
Future<ui.Image> _image(List<String> rows) {
  final byLetter = {for (final e in _letters.entries) e.value: e.key};
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
/// `.` for nothing, `?` for a colour not in [_letters].
Future<List<String>> _paint(
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
            return _letters[argb] ?? '?';
          }(),
      ].join(),
  ];
}

/// A layer of raw ids, flags included.
TileLayer _layer(
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
  data: [for (final raw in raws) TiledGid.idOf(raw)],
  rawData: Uint32List.fromList(raws),
);

Tileset _tileset(
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

TiledMap _map(
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

const _h = TiledGid.flipHorizontal;
const _v = TiledGid.flipVertical;
const _d = TiledGid.flipDiagonal;

void main() {
  test(
    'every flip and turn, side by side in one layer, draws as in Tiled',
    () async {
      final atlas = TextureAtlas(
        image: await _image(['RG', 'BW']),
        tileset: _tileset(2, 2, 1),
      );
      // Diagonal first, then horizontal, then vertical.
      final layer = _layer(8, 1, [
        for (final flags in [
          0,
          _h,
          _v,
          _h | _v,
          _d,
          _d | _h,
          _d | _v,
          _d | _h | _v,
        ])
          TiledGid.compose(1, flags),
      ]);
      final renderer = TileMapRenderer(
        tileLayer: layer,
        map: _map(8, 1),
        atlas: atlas,
      );

      final rows = await _paint(
        16,
        2,
        (c) => renderer.render(c, ui.Offset.zero, null),
      );

      //            none H   V   HV  D   DH  DV  DHV
      expect(rows, ['RGGRBWWBRBBRGWWG', 'BWWBRGGRGWWGRBBR']);
      atlas.dispose();
    },
  );

  test(
    'a tile taller than the grid stands on its cell, moved by the tile offset',
    () async {
      final atlas = TextureAtlas(
        image: await _image(['RR', 'GG', 'BB', 'WW']),
        tileset: _tileset(2, 4, 1, tileOffset: const ui.Offset(1, 0)),
      );
      // Two rows of 2-pixel cells; the tile is in the lower one.
      final renderer = TileMapRenderer(
        tileLayer: _layer(1, 2, [0, 1]),
        map: _map(1, 2),
        atlas: atlas,
      );

      final rows = await _paint(
        4,
        4,
        (c) => renderer.render(c, ui.Offset.zero, null),
      );

      expect(rows, ['.RR.', '.GG.', '.BB.', '.WW.']);
      expect(renderer.worldBounds, const ui.Rect.fromLTWH(1, 0, 2, 4));
      atlas.dispose();
    },
  );

  test('an isometric map draws where Tiled does', () async {
    final atlas = TextureAtlas(
      image: await _image(['RRRRGGGG', 'RRRRGGGG']),
      tileset: _tileset(4, 2, 2),
    );
    // (1, 0) holds tile 1, (0, 1) tile 2: the diamond's right and left.
    final renderer = TileMapRenderer(
      tileLayer: _layer(2, 2, [0, 1, 2, 0]),
      map: _map(2, 2, tileWidth: 4, orientation: MapOrientation.isometric),
      atlas: atlas,
    );

    final rows = await _paint(
      8,
      4,
      (c) => renderer.render(c, ui.Offset.zero, null),
    );

    expect(rows, ['........', 'GGGGRRRR', 'GGGGRRRR', '........']);
    expect(renderer.worldBounds, const ui.Rect.fromLTRB(0, 1, 8, 3));
    atlas.dispose();
  });

  test('an infinite map draws its chunks, negative cells included', () async {
    final atlas = TextureAtlas(
      image: await _image(['RRGG', 'RRGG']),
      tileset: _tileset(2, 2, 2),
    );
    final layer = TileLayer(
      id: 1,
      width: 0,
      height: 0,
      data: const [],
      chunks: [
        TileChunk(
          x: -1,
          y: 0,
          width: 2,
          height: 1,
          data: Uint32List.fromList([1, 2]),
        ),
      ],
    );
    final renderer = TileMapRenderer(
      tileLayer: layer,
      map: _map(0, 0, infinite: true),
      atlas: atlas,
    );

    final rows = await _paint(4, 2, (c) {
      c.translate(2, 0);
      renderer.render(c, ui.Offset.zero, null);
    });

    expect(rows, ['RRGG', 'RRGG']);
    expect(renderer.tileCount, 2);
    expect(renderer.worldBounds, const ui.Rect.fromLTRB(-2, 0, 2, 2));
    atlas.dispose();
  });

  group('culling', () {
    late TextureAtlas atlas;
    setUp(() async {
      atlas = TextureAtlas(
        image: await _image(['RRGGBBWW', 'RRGGBBWW']),
        tileset: _tileset(2, 2, 4),
      );
    });
    tearDown(() => atlas.dispose());

    test('draws only the tiles in view', () async {
      final renderer = TileMapRenderer(
        tileLayer: _layer(3, 1, [1, 2, 3]),
        map: _map(3, 1),
        atlas: atlas,
      );
      Future<List<String>> view(ui.Rect visible) =>
          _paint(6, 2, (c) => renderer.render(c, ui.Offset.zero, visible));

      expect(await view(const ui.Rect.fromLTWH(2.5, 0, 1, 2)), [
        '..GG..',
        '..GG..',
      ]);
      expect(await view(const ui.Rect.fromLTWH(-10, -10, 100, 100)), [
        'RRGGBB',
        'RRGGBB',
      ]);
      expect(await view(const ui.Rect.fromLTWH(20, 0, 5, 5)), [
        '......',
        '......',
      ]);
    });

    test('keeps a layer offset, and a tall tile reaching into view', () async {
      final tall = TextureAtlas(
        image: await _image(['RR', 'GG', 'BB', 'WW']),
        tileset: _tileset(2, 4, 1),
      );
      final renderer = TileMapRenderer(
        tileLayer: _layer(1, 3, [0, 0, 1], offsetX: 1),
        map: _map(1, 3),
        atlas: tall,
      );

      // The tile's cell is the bottom row; the view sees only the middle
      // one, which the tile reaches up into.
      final rows = await _paint(
        3,
        6,
        (c) => renderer.render(
          c,
          ui.Offset.zero,
          const ui.Rect.fromLTWH(0, 2, 3, 1.5),
        ),
      );

      expect(rows, ['...', '...', '.RR', '.GG', '.BB', '.WW']);
      tall.dispose();
    });

    test('tints and fades culled tiles as it does whole layers', () async {
      final renderer = TileMapRenderer(
        tileLayer: _layer(3, 1, [4, 4, 4], tint: const ui.Color(0xFFFFFF00)),
        map: _map(3, 1),
        atlas: atlas,
      );

      expect(
        await _paint(6, 2, (c) => renderer.render(c, ui.Offset.zero, null)),
        ['YYYYYY', 'YYYYYY'],
      );
      expect(
        await _paint(
          6,
          2,
          (c) => renderer.render(
            c,
            ui.Offset.zero,
            const ui.Rect.fromLTWH(2.5, 0, 1, 2),
          ),
        ),
        ['..YY..', '..YY..'],
      );
    });

    test(
      'is the same picture as drawing everything, for every orientation',
      () async {
        for (final orientation in MapOrientation.values) {
          final map = TiledMap(
            width: 6,
            height: 6,
            tileWidth: 2,
            tileHeight: 2,
            orientation: orientation,
            hexSideLength: orientation == MapOrientation.hexagonal ? 1 : null,
          );
          final renderer = TileMapRenderer(
            tileLayer: _layer(6, 6, [for (var i = 0; i < 36; i++) 1 + i % 4]),
            map: map,
            atlas: atlas,
          );
          const window = ui.Rect.fromLTWH(3, 2, 5, 4);
          final culled = await _paint(16, 16, (c) {
            c.clipRect(window);
            renderer.render(c, ui.Offset.zero, window);
          });
          final whole = await _paint(16, 16, (c) {
            c.clipRect(window);
            renderer.render(c, ui.Offset.zero, null);
          });
          expect(culled, whole, reason: orientation.name);
        }
      },
    );
  });

  test('tiles overlap in the render order of an orthogonal map', () async {
    final atlas = TextureAtlas(
      image: await _image(['RRRRGGGG', 'RRRRGGGG']),
      tileset: _tileset(4, 2, 2),
    );
    Future<List<String>> draw(RenderOrder order) {
      // Tiles twice the grid's width: each covers half of the next cell.
      final renderer = TileMapRenderer(
        tileLayer: _layer(2, 1, [1, 2]),
        map: _map(2, 1, renderOrder: order),
        atlas: atlas,
      );
      return _paint(6, 1, (c) => renderer.render(c, ui.Offset.zero, null));
    }

    expect(await draw(RenderOrder.rightDown), ['RRGGGG']);
    expect(await draw(RenderOrder.leftDown), ['RRRRGG']);
    atlas.dispose();
  });

  group('TextureAtlas.mirroredImage', () {
    test('puts the mirror beside an image no wider than tall', () async {
      final atlas = TextureAtlas(
        image: await _image(['RG', 'BW']),
        tileset: _tileset(2, 2, 1),
      );
      final mirrored = atlas.mirroredImage;

      expect([mirrored.width, mirrored.height], [4, 2]);
      expect(
        atlas.getMirroredSourceRect(1),
        const ui.Rect.fromLTRB(2, 0, 4, 2),
      );
      expect(
        await _paint(
          4,
          2,
          (c) => c.drawImage(mirrored, ui.Offset.zero, ui.Paint()),
        ),
        ['RGGR', 'BWWB'],
      );
      atlas.dispose();
      expect(mirrored.debugDisposed, isTrue);
    });

    test(
      'puts the mirror below a wide image, and flips draw from it',
      () async {
        final atlas = TextureAtlas(
          image: await _image(['RGBW', 'RGBW']),
          tileset: _tileset(2, 2, 2),
        );

        expect([atlas.mirroredImage.width, atlas.mirroredImage.height], [4, 4]);
        expect(
          atlas.getMirroredSourceRect(2),
          const ui.Rect.fromLTRB(0, 2, 2, 4),
        );

        final renderer = TileMapRenderer(
          tileLayer: _layer(2, 1, [TiledGid.compose(2, _h), 1]),
          map: _map(2, 1),
          atlas: atlas,
        );
        expect(
          await _paint(4, 2, (c) => renderer.render(c, ui.Offset.zero, null)),
          ['WBRG', 'WBRG'],
        );
        atlas.dispose();
      },
    );
  });
}
