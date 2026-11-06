// Tile data holds exactly its layer's or chunk's tiles, whatever the
// encoding, and compressed data can't unpack past them.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_deflate/just_deflate.dart';
import 'package:just_tiled/just_tiled.dart';
import 'package:just_zstd/just_zstd.dart';

final _formatError = throwsA(isA<FormatException>());

/// [ids] ones, packed as [compression] packs them, in base64.
String _packed(int ids, String compression) {
  final bytes = TiledGid.toBytes(List.filled(ids, 1));
  return base64Encode(switch (compression) {
    'zlib' => const ZlibCodec().encode(bytes),
    'gzip' => const GzipCodec().encode(bytes),
    'zstd' => const ZstdEncoder().encode(bytes),
    _ => bytes,
  });
}

/// A 2 x 2 layer (four ids) whose data is [data] in [encoding].
String _tmx(String data, {String encoding = 'base64', String? compression}) =>
    '<?xml version="1.0" encoding="UTF-8"?>\n'
    '<map version="1.10" orientation="orthogonal" width="2" height="2"'
    ' tilewidth="16" tileheight="16" infinite="0">\n'
    ' <layer id="1" name="L" width="2" height="2">\n'
    '  <data encoding="$encoding"'
    '${compression == null ? '' : ' compression="$compression"'}>'
    '$data</data>\n'
    ' </layer>\n'
    '</map>\n';

/// The same layer as TMJ, its data [data] (a list, or base64 text).
String _tmj(Object data, {String? compression}) => jsonEncode({
  'type': 'map',
  'width': 2,
  'height': 2,
  'tilewidth': 16,
  'tileheight': 16,
  'layers': [
    {
      'type': 'tilelayer',
      'id': 1,
      'name': 'L',
      'width': 2,
      'height': 2,
      if (data is String) 'encoding': 'base64',
      'compression': ?compression,
      'data': data,
    },
  ],
  'tilesets': <Object>[],
});

Future<List<int>> _tiles(Future<TiledMap> map) async =>
    (await map).tileLayers.single.gids;

void main() {
  group('compressed data may not unpack past its layer', () {
    for (final compression in ['zlib', 'gzip', 'zstd']) {
      test(
        '$compression: exactly the layer reads, one id more is refused',
        () async {
          expect(
            await _tiles(
              TmxParser.parse(
                _tmx(_packed(4, compression), compression: compression),
              ),
            ),
            [1, 1, 1, 1],
          );
          expect(
            TmxParser.parse(
              _tmx(_packed(5, compression), compression: compression),
            ),
            _formatError,
          );
          expect(
            await _tiles(
              TmjParser.parse(
                _tmj(_packed(4, compression), compression: compression),
              ),
            ),
            [1, 1, 1, 1],
          );
          expect(
            TmjParser.parse(
              _tmj(_packed(5, compression), compression: compression),
            ),
            _formatError,
          );
        },
      );
    }

    test('Zstandard RLE blocks, 4 bytes for 128 KiB each, are refused at '
        'the layer size', () async {
      // No content size, a 128 KiB window, then 200 RLE blocks: 806 bytes
      // that would unpack to 26 MB, for a layer of 16 bytes.
      const block = 1 << 1 | 131072 << 3;
      final bomb = base64Encode([
        0x28, 0xB5, 0x2F, 0xFD, 0x00, 0x38, //
        for (var i = 0; i < 200; i++) ...[
          (block | (i == 199 ? 1 : 0)) & 0xFF,
          (block >> 8) & 0xFF,
          block >> 16,
          0x41,
        ],
      ]);
      expect(
        TmxParser.parse(_tmx(bomb, compression: 'zstd')),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('more than 16 bytes'),
          ),
        ),
      );
    });
  });

  group('data that does not hold its layer is refused', () {
    test('CSV, one tile short or one over', () async {
      expect(await _tiles(TmxParser.parse(_tmx('1,2,3,4', encoding: 'csv'))), [
        1,
        2,
        3,
        4,
      ]);
      expect(TmxParser.parse(_tmx('1,2,3', encoding: 'csv')), _formatError);
      expect(TmxParser.parse(_tmx('1,2,3,4,5', encoding: 'csv')), _formatError);
    });

    test('XML tiles', () {
      final tmx = _tmx(
        '<tile gid="1"/><tile/><tile gid="2"/>',
      ).replaceFirst(' encoding="base64"', '');
      expect(TmxParser.parse(tmx), _formatError);
    });

    test('uncompressed base64, short or not whole ids', () {
      expect(TmxParser.parse(_tmx(_packed(3, 'none'))), _formatError);
      expect(
        TmxParser.parse(_tmx(base64Encode(List.filled(15, 1)))),
        _formatError,
      );
    });

    test('TMJ number arrays', () async {
      expect(await _tiles(TmjParser.parse(_tmj([1, 0, 0, 2]))), [1, 0, 0, 2]);
      expect(TmjParser.parse(_tmj([1, 0, 0])), _formatError);
    });

    test('a chunk of an infinite map', () {
      const tmx = '''<?xml version="1.0" encoding="UTF-8"?>
<map version="1.10" orientation="orthogonal" width="2" height="2" tilewidth="16" tileheight="16" infinite="1">
 <layer id="1" name="L" width="2" height="2">
  <data encoding="csv"><chunk x="0" y="0" width="2" height="2">1,2,3</chunk></data>
 </layer>
</map>''';
      expect(TmxParser.parse(tmx), _formatError);
    });
  });

  test('a finite layer without data is empty, an infinite one has no '
      'chunks', () async {
    const finite = '''<?xml version="1.0" encoding="UTF-8"?>
<map version="1.10" orientation="orthogonal" width="3" height="2" tilewidth="16" tileheight="16" infinite="0">
 <layer id="1" name="L" width="3" height="2"/>
</map>''';
    expect(await _tiles(TmxParser.parse(finite)), List.filled(6, 0));

    // As Tiled saves an empty layer of an infinite map: no chunks.
    final infinite = finite
        .replaceFirst('infinite="0"', 'infinite="1"')
        .replaceFirst(
          'height="2"/>',
          'height="2">\n  <data encoding="csv"/>\n </layer>',
        );
    final layer = (await TmxParser.parse(infinite)).tileLayers.single;
    expect(layer.gids, isEmpty);
    expect(layer.chunks, isEmpty);

    final tmj = await TmjParser.parse(
      jsonEncode({
        'type': 'map',
        'infinite': true,
        'layers': [
          {'type': 'tilelayer', 'width': 3, 'height': 2, 'chunks': []},
        ],
      }),
    );
    expect(tmj.tileLayers.single.gids, isEmpty);
  });
}
