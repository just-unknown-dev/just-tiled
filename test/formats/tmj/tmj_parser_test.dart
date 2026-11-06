// The TMJ reader: what it reads, and broken files throwing
// FormatException, never a TypeError.

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_tiled/just_tiled.dart';

import '../../test_files.dart';

final _formatError = throwsA(isA<FormatException>());

void main() {
  test('reads data, objects, properties and the embedded tileset', () async {
    final map = await TmjParser.parse(fixture('ortho.tmj'));
    expect(map.tileLayers.single.gids, [
      1, 2, 3, 4, 5, 6, 7, 8, 0x40000001, 0, 0, 2, //
    ]);
    final objects = map.objectGroups.single.objects;
    expect(objects[0].isPoint, isTrue);
    expect(objects[1].polygon![1], const Offset(16, -16));
    expect(map.properties['tint'], const Color(0xFF336699));
    expect(map.properties.typeOf('lives'), 'int');
    final ts = map.tilesets.single;
    expect([for (final f in ts.tiles[2]!.animation) f.tileId], [2, 3]);
    expect(ts.wangSets.single.wangTiles[0], [0, 1, 0, 1, 0, 1, 0, 1]);
  });

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
    expect(
      TmxParser.parse(tmx, fileProvider: MemoryFiles({'t.tsj': '[]'})),
      _formatError,
    );
  });
}
