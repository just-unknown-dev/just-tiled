// Broken files throw FormatException — never a TypeError — and compressed
// tile data can't unpack past its layer, Zstandard included.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_tiled/just_tiled.dart';

class _Text implements TsxProvider {
  _Text(this.text);
  final String text;

  @override
  Future<String> getTsx(String source) async => text;

  @override
  Future<String> getTemplate(String source) async => text;
}

final _formatError = throwsA(isA<FormatException>());

/// [ids] ones as a Zstandard frame holding one uncompressed block, a form
/// the Zstandard decoder reads.
String _zstd(int ids) {
  final data = TiledGid.toBytes(List.filled(ids, 1));
  return base64Encode([
    ...[0x28, 0xB5, 0x2F, 0xFD], // magic number
    0x20, data.length, // single segment, one-byte content size
    (1 | data.length << 3) & 0xFF, data.length >> 5, 0, // last block, raw
    ...data,
  ]);
}

void main() {
  group('TMJ that is not a map throws FormatException', () {
    for (final (what, json) in [
      ('not JSON', 'nope'),
      ('a list', '[]'),
      ('a tileset that is a number', '{"tilesets": [1]}'),
      (
        'a layer name that is a number',
        '{"layers": [{"type": "group", "name": 5}]}',
      ),
      (
        'tile data that is not numbers',
        '{"layers": [{"type": "tilelayer", "data": ["x"]}]}',
      ),
      (
        'an object list of strings',
        '{"layers": [{"type": "objectgroup", "objects": ["x"]}]}',
      ),
    ]) {
      test(what, () => expect(TmjParser.parse(json), _formatError));
    }
  });

  test('TSJ that is not a tileset throws FormatException', () {
    expect(() => TmjParser.parseTileset('"x"'), _formatError);
    expect(() => TmjParser.parseTileset('{"name": 3}'), _formatError);
    expect(
      () => TmjParser.parseTilesetJson({'tiles': 'x', 'image': 1}),
      _formatError,
    );
  });

  test('a TMX map whose TSJ tileset is broken throws FormatException', () {
    const tmx = '''<?xml version="1.0" encoding="UTF-8"?>
<map version="1.10" orientation="orthogonal" width="1" height="1" tilewidth="16" tileheight="16">
 <tileset firstgid="1" source="t.tsj"/>
</map>''';
    expect(TileMapParser.parse(tmx, tsxProvider: _Text('[]')), _formatError);
  });

  group('Zstandard data may not unpack past its layer', () {
    // A 2 x 2 layer: four ids.
    String tmx(int ids) =>
        '''<?xml version="1.0" encoding="UTF-8"?>
<map version="1.10" orientation="orthogonal" width="2" height="2" tilewidth="16" tileheight="16">
 <layer id="1" name="L" width="2" height="2">
  <data encoding="base64" compression="zstd">${_zstd(ids)}</data>
 </layer>
</map>''';

    String tmj(int ids) => jsonEncode({
      'type': 'map',
      'width': 2,
      'height': 2,
      'tilewidth': 16,
      'tileheight': 16,
      'layers': [
        {
          'type': 'tilelayer',
          'id': 1,
          'width': 2,
          'height': 2,
          'encoding': 'base64',
          'compression': 'zstd',
          'data': _zstd(ids),
        },
      ],
      'tilesets': <Object>[],
    });

    test('TMX: exactly the layer reads, one id more is refused', () async {
      final map = await TileMapParser.parse(tmx(4));
      expect((map.layers.single as TileLayer).data, [1, 1, 1, 1]);
      expect(TileMapParser.parse(tmx(5)), _formatError);
    });

    test('TMJ: exactly the layer reads, one id more is refused', () async {
      final map = await TmjParser.parse(tmj(4));
      expect((map.layers.single as TileLayer).data, [1, 1, 1, 1]);
      expect(TmjParser.parse(tmj(5)), _formatError);
    });
  });

  test(
    'Zstandard-compressed tiles are read right or refused, never misread',
    () async {
      // 40 x 30 ids, compressed by the zstd library (level 19), as Tiled
      // saves them: tile 1 + i % 7, mirrored when i % 13 is 0.
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
      final TiledMap map;
      try {
        map = await TileMapParser.parse(tmx);
      } on FormatException {
        // The decoder can't read compressed blocks yet: refused, not misread.
        return;
      }
      final layer = map.layers.single as TileLayer;
      expect(layer.data, [for (var i = 0; i < 1200; i++) 1 + i % 7]);
      expect(layer.flipHorizontal, [
        for (var i = 0; i < 1200; i++) i % 13 == 0,
      ]);
    },
  );
}
