// The TMJ writer: every data encoding the TMX writer has, read back the
// same.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_tiled/just_tiled.dart';

import '../../test_files.dart';

String _canon(TiledMap map) =>
    jsonEncode(TmjWriter.toJson(map, tiledVersion: '-'));

void main() {
  for (final encoding in TiledDataEncoding.values) {
    test('round trips with ${encoding.name} data', () async {
      final map = await TmjParser.parse(fixture('ortho.tmj'));
      final again = await TmjParser.parse(
        TmjWriter.write(map, encoding: encoding),
      );
      expect(_canon(again), _canon(map));
    });
  }

  test('writes the encoding and compression Tiled writes', () async {
    final map = await TmjParser.parse(fixture('ortho.tmj'));
    Map<String, dynamic> layer(TiledDataEncoding encoding) =>
        (TmjWriter.toJson(map, encoding: encoding)['layers'] as List)
            .whereType<Map<String, dynamic>>()
            .firstWhere((l) => l['type'] == 'tilelayer');

    expect(layer(TiledDataEncoding.csv)['data'], isA<List<int>>());
    expect(layer(TiledDataEncoding.csv), isNot(contains('encoding')));
    expect(layer(TiledDataEncoding.base64)['encoding'], 'base64');
    expect(layer(TiledDataEncoding.base64), isNot(contains('compression')));
    expect(layer(TiledDataEncoding.base64Zlib)['compression'], 'zlib');
    expect(layer(TiledDataEncoding.base64Gzip)['compression'], 'gzip');
  });

  test('a TSJ tileset written and read again is the same tileset', () {
    final ts = TmjParser.parseTileset(fixture('tilesets/props.tsj'));
    final again = TmjParser.parseTileset(TmjWriter.writeTileset(ts));
    expect(
      jsonEncode(TmjWriter.tilesetToJson(again)),
      jsonEncode(TmjWriter.tilesetToJson(ts)),
    );
  });
}
