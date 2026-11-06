// The renderer, drawn for real: each test paints into an image and reads
// the pixels back, one letter per pixel.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:just_tiled/just_tiled.dart';

import 'painting.dart';

void main() {
  test(
    'every flip and turn, side by side in one layer, draws as in Tiled',
    () async {
      final atlas = TextureAtlas(
        image: await letterImage(['RG', 'BW']),
        tileset: stripTileset(2, 2, 1),
      );
      // Diagonal first, then horizontal, then vertical.
      final layer = rawLayer(8, 1, [
        for (final flags in [0, h, v, h | v, d, d | h, d | v, d | h | v])
          TiledGid.compose(1, flags),
      ]);
      final renderer = TileMapRenderer(
        tileLayer: layer,
        map: smallMap(8, 1),
        atlas: atlas,
      );

      final rows = await painted(16, 2, (c) => renderer.render(c, null));

      //            none H   V   HV  D   DH  DV  DHV
      expect(rows, ['RGGRBWWBRBBRGWWG', 'BWWBRGGRGWWGRBBR']);
      atlas.dispose();
    },
  );

  test(
    'a tile taller than the grid stands on its cell, moved by the tile offset',
    () async {
      final atlas = TextureAtlas(
        image: await letterImage(['RR', 'GG', 'BB', 'WW']),
        tileset: stripTileset(2, 4, 1, tileOffset: const ui.Offset(1, 0)),
      );
      // Two rows of 2-pixel cells; the tile is in the lower one.
      final renderer = TileMapRenderer(
        tileLayer: rawLayer(1, 2, [0, 1]),
        map: smallMap(1, 2),
        atlas: atlas,
      );

      final rows = await painted(4, 4, (c) => renderer.render(c, null));

      expect(rows, ['.RR.', '.GG.', '.BB.', '.WW.']);
      expect(renderer.worldBounds, const ui.Rect.fromLTWH(1, 0, 2, 4));
      atlas.dispose();
    },
  );

  test('an isometric map draws where Tiled does', () async {
    final atlas = TextureAtlas(
      image: await letterImage(['RRRRGGGG', 'RRRRGGGG']),
      tileset: stripTileset(4, 2, 2),
    );
    // (1, 0) holds tile 1, (0, 1) tile 2: the diamond's right and left.
    final renderer = TileMapRenderer(
      tileLayer: rawLayer(2, 2, [0, 1, 2, 0]),
      map: smallMap(2, 2, tileWidth: 4, orientation: MapOrientation.isometric),
      atlas: atlas,
    );

    final rows = await painted(8, 4, (c) => renderer.render(c, null));

    expect(rows, ['........', 'GGGGRRRR', 'GGGGRRRR', '........']);
    expect(renderer.worldBounds, const ui.Rect.fromLTRB(0, 1, 8, 3));
    atlas.dispose();
  });

  test('an infinite map draws its chunks, negative cells included', () async {
    final atlas = TextureAtlas(
      image: await letterImage(['RRGG', 'RRGG']),
      tileset: stripTileset(2, 2, 2),
    );
    final layer = TileLayer(
      id: 1,
      width: 0,
      height: 0,
      chunks: [
        TileChunk(
          x: -1,
          y: 0,
          width: 2,
          height: 1,
          gids: Uint32List.fromList([1, 2]),
        ),
      ],
    );
    final renderer = TileMapRenderer(
      tileLayer: layer,
      map: smallMap(0, 0, infinite: true),
      atlas: atlas,
    );

    final rows = await painted(4, 2, (c) {
      c.translate(2, 0);
      renderer.render(c, null);
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
        image: await letterImage(['RRGGBBWW', 'RRGGBBWW']),
        tileset: stripTileset(2, 2, 4),
      );
    });
    tearDown(() => atlas.dispose());

    test('draws only the tiles in view', () async {
      final renderer = TileMapRenderer(
        tileLayer: rawLayer(3, 1, [1, 2, 3]),
        map: smallMap(3, 1),
        atlas: atlas,
      );
      Future<List<String>> view(ui.Rect visible) =>
          painted(6, 2, (c) => renderer.render(c, visible));

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
        image: await letterImage(['RR', 'GG', 'BB', 'WW']),
        tileset: stripTileset(2, 4, 1),
      );
      final renderer = TileMapRenderer(
        tileLayer: rawLayer(1, 3, [0, 0, 1], offsetX: 1),
        map: smallMap(1, 3),
        atlas: tall,
      );

      // The tile's cell is the bottom row; the view sees only the middle
      // one, which the tile reaches up into.
      final rows = await painted(
        3,
        6,
        (c) => renderer.render(c, const ui.Rect.fromLTWH(0, 2, 3, 1.5)),
      );

      expect(rows, ['...', '...', '.RR', '.GG', '.BB', '.WW']);
      tall.dispose();
    });

    test('tints and fades culled tiles as it does whole layers', () async {
      final renderer = TileMapRenderer(
        tileLayer: rawLayer(3, 1, [4, 4, 4], tint: const ui.Color(0xFFFFFF00)),
        map: smallMap(3, 1),
        atlas: atlas,
      );

      expect(await painted(6, 2, (c) => renderer.render(c, null)), [
        'YYYYYY',
        'YYYYYY',
      ]);
      expect(
        await painted(
          6,
          2,
          (c) => renderer.render(c, const ui.Rect.fromLTWH(2.5, 0, 1, 2)),
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
            tileLayer: rawLayer(6, 6, [for (var i = 0; i < 36; i++) 1 + i % 4]),
            map: map,
            atlas: atlas,
          );
          const window = ui.Rect.fromLTWH(3, 2, 5, 4);
          final culled = await painted(16, 16, (c) {
            c.clipRect(window);
            renderer.render(c, window);
          });
          final whole = await painted(16, 16, (c) {
            c.clipRect(window);
            renderer.render(c, null);
          });
          expect(culled, whole, reason: orientation.name);
        }
      },
    );
  });

  test('tiles overlap in the render order of an orthogonal map', () async {
    final atlas = TextureAtlas(
      image: await letterImage(['RRRRGGGG', 'RRRRGGGG']),
      tileset: stripTileset(4, 2, 2),
    );
    Future<List<String>> draw(RenderOrder order) {
      // Tiles twice the grid's width: each covers half of the next cell.
      final renderer = TileMapRenderer(
        tileLayer: rawLayer(2, 1, [1, 2]),
        map: smallMap(2, 1, renderOrder: order),
        atlas: atlas,
      );
      return painted(6, 1, (c) => renderer.render(c, null));
    }

    expect(await draw(RenderOrder.rightDown), ['RRGGGG']);
    expect(await draw(RenderOrder.leftDown), ['RRRRGG']);
    atlas.dispose();
  });

  test(
    'tiles changed in place draw once the renderer is invalidated',
    () async {
      final atlas = TextureAtlas(
        image: await letterImage(['RRGG', 'RRGG']),
        tileset: stripTileset(2, 2, 2),
      );
      final tiles = rawLayer(2, 1, [1, 0]);
      final renderer = TileMapRenderer(
        tileLayer: tiles,
        map: smallMap(2, 1),
        atlas: atlas,
      );
      Future<List<String>> draw() =>
          painted(4, 1, (c) => renderer.render(c, null));

      expect(await draw(), ['RR..']);
      tiles.gids[1] = TiledGid.compose(2, h);
      expect(await draw(), ['RR..'], reason: 'compiled before the change');
      renderer.invalidate();
      expect(await draw(), ['RRGG']);
      expect(renderer.tileCount, 2);
      atlas.dispose();
    },
  );
}
