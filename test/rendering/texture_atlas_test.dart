// Texture atlases: the mirrored image flips draw from, and a map's
// atlases together.

import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:just_tiled/just_tiled.dart';

import 'painting.dart';

void main() {
  group('TextureAtlas.mirroredImage', () {
    test('puts the mirror beside an image no wider than tall', () async {
      final atlas = TextureAtlas(
        image: await letterImage(['RG', 'BW']),
        tileset: stripTileset(2, 2, 1),
      );
      final mirrored = atlas.mirroredImage;

      expect([mirrored.width, mirrored.height], [4, 2]);
      expect(
        atlas.getMirroredSourceRect(1),
        const ui.Rect.fromLTRB(2, 0, 4, 2),
      );
      expect(
        await painted(
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
          image: await letterImage(['RGBW', 'RGBW']),
          tileset: stripTileset(2, 2, 2),
        );

        expect([atlas.mirroredImage.width, atlas.mirroredImage.height], [4, 4]);
        expect(
          atlas.getMirroredSourceRect(2),
          const ui.Rect.fromLTRB(0, 2, 2, 4),
        );

        final renderer = TileMapRenderer(
          tileLayer: rawLayer(2, 1, [TiledGid.compose(2, h), 1]),
          map: smallMap(2, 1),
          atlas: atlas,
        );
        expect(await painted(4, 2, (c) => renderer.render(c, null)), [
          'WBRG',
          'WBRG',
        ]);
        atlas.dispose();
      },
    );
  });

  group('TextureAtlasCollection', () {
    test('finds the atlas holding a gid, and nothing for others', () async {
      final ground = TextureAtlas(
        image: await letterImage(['RRGG', 'RRGG']),
        tileset: stripTileset(2, 2, 2),
      );
      final props = TextureAtlas(
        image: await letterImage(['BBWW', 'BBWW']),
        tileset: Tileset(
          firstGid: 3,
          tileWidth: 2,
          tileHeight: 2,
          tileCount: 2,
          columns: 2,
        ),
      );
      final atlases = TextureAtlasCollection([ground, props]);

      expect(atlases.isNotEmpty, isTrue);
      expect(atlases.lookup(2)!.atlas, ground);
      expect(atlases.lookup(2)!.sourceRect, const ui.Rect.fromLTWH(2, 0, 2, 2));
      expect(atlases.lookup(3)!.atlas, props);
      expect(atlases.lookup(3)!.sourceRect, const ui.Rect.fromLTWH(0, 0, 2, 2));
      expect(atlases.lookup(0), isNull);
      expect(atlases.lookup(5), isNull);
      expect(TextureAtlasCollection(const []).isEmpty, isTrue);

      atlases.dispose();
    });

    test('dispose disposes every atlas image, mirrors included', () async {
      final a = TextureAtlas(
        image: await letterImage(['RG', 'BW']),
        tileset: stripTileset(2, 2, 1),
      );
      final b = TextureAtlas(
        image: await letterImage(['RG', 'BW']),
        tileset: Tileset(
          firstGid: 2,
          tileWidth: 2,
          tileHeight: 2,
          tileCount: 1,
          columns: 1,
        ),
      );
      final mirrored = b.mirroredImage;

      TextureAtlasCollection([a, b]).dispose();

      expect(a.image.debugDisposed, isTrue);
      expect(b.image.debugDisposed, isTrue);
      expect(mirrored.debugDisposed, isTrue);
    });
  });
}
