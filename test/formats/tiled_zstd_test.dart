// Maps Tiled saves with "Base64 (Zstandard compressed)" tile layers load,
// read from the files Tiled 1.11.2 itself wrote (a script made the same
// layers in Tiled and saved them, TMX and TMJ, finite and infinite). 0.4.1
// refused every one: its Zstandard decoder read only uncompressed blocks.

import 'package:flutter_test/flutter_test.dart';
import 'package:just_tiled/just_tiled.dart';

import '../test_files.dart';

/// The raw id the script put at ([x], [y]) of a [w] x [h] layer: tile ids
/// by rows and columns with some scattered, every eleventh cell mirrored.
/// Tiled's own CSV copies of the maps hold exactly these.
int _tileAt(int x, int y, int w, int h) {
  final i = y * w + x;
  final r = (i * 7919 + 17) % 65521;
  var id = y < h ~/ 3 ? 0 : 1 + ((x >> 3) + (y >> 2)) % 4;
  if (r % 16 == 0) id = 20 + (r >> 4) % 10;
  if (id == 0) return 0;
  return i % 11 == 0 ? TiledGid.compose(id, TiledGid.flipHorizontal) : id;
}

List<int> _layer(int w, int h) => [
  for (var y = 0; y < h; y++)
    for (var x = 0; x < w; x++) _tileAt(x, y, w, h),
];

void main() {
  test('40 x 30, TMX', () async {
    final map = await TmxParser.parse(fixture('zstd_40x30.tmx'));
    final layer = map.tileLayers.single;

    expect(layer.compression, LayerCompression.zstd);
    expect(layer.gids, _layer(40, 30));
  });

  test('40 x 30, TMJ', () async {
    final map = await TmjParser.parse(fixture('zstd_40x30.tmj'));
    expect(map.tileLayers.single.gids, _layer(40, 30));
  });

  test('256 x 160: a layer of two Zstandard blocks', () async {
    final map = await TmxParser.parse(fixture('zstd_256x160.tmx'));
    expect(map.tileLayers.single.gids, _layer(256, 160));
  });

  for (final name in ['zstd_infinite_40x30.tmx', 'zstd_infinite_40x30.tmj']) {
    test('an infinite map, each chunk its own frame: $name', () async {
      final map = name.endsWith('.tmj')
          ? await TmjParser.parse(fixture(name))
          : await TmxParser.parse(fixture(name));
      final layer = map.tileLayers.single;

      // The script drew the 40 x 30 layer from (-20, -7).
      expect(layer.chunks, hasLength(12));
      var tiles = 0;
      for (final chunk in layer.chunks) {
        for (var i = 0; i < chunk.gids.length; i++) {
          final x = chunk.x + i % chunk.width + 20;
          final y = chunk.y + i ~/ chunk.width + 7;
          final inside = x >= 0 && x < 40 && y >= 0 && y < 30;
          expect(chunk.gids[i], inside ? _tileAt(x, y, 40, 30) : 0);
          if (chunk.gids[i] != 0) tiles++;
        }
      }
      expect(tiles, _layer(40, 30).where((g) => g != 0).length);
    });
  }

  test('a layer the zstd library compressed at level 19 reads right', () async {
    // 40 x 30 ids: tile 1 + i % 7, mirrored when i % 13 is 0.
    const data =
        'KLUv/WDAEa0BAMICBgvgrQYAgOru7u6dAu+9997h9jp9Lo8bAg6gMHr/39BzOVHx1tOh'
        'OlyH9bAe1hQ2vt4p';
    const tmx =
        '''<?xml version="1.0" encoding="UTF-8"?>
<map version="1.10" orientation="orthogonal" width="40" height="30" tilewidth="16" tileheight="16">
 <layer id="1" name="L" width="40" height="30">
  <data encoding="base64" compression="zstd">$data</data>
 </layer>
</map>''';
    final layer = (await TmxParser.parse(tmx)).tileLayers.single;

    expect(layer.gids, [
      for (var i = 0; i < 1200; i++)
        i % 13 == 0
            ? TiledGid.compose(1 + i % 7, TiledGid.flipHorizontal)
            : 1 + i % 7,
    ]);
  });
}
