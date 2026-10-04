// Reading and writing Tiled's files.
//
// The fixtures are written in exactly the form Tiled 1.10 saves: every map
// orientation, finite and infinite layers, all four data encodings, every
// flip combination, Wang sets of each kind, external TSX and TSJ tilesets.
// Each is read, checked, written back out in every format this package
// writes, and read again — and must come back unchanged.

import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_tiled/just_tiled.dart';

/// Reads external tilesets from the fixtures folder.
class _Files implements TsxProvider {
  _Files(this.base);
  final String base;

  @override
  Future<String> getTsx(String source) => File('$base/$source').readAsString();

  @override
  Future<String> getTemplate(String source) =>
      File('$base/$source').readAsString();
}

const _dir = 'test/fixtures';
final _files = _Files(_dir);

Future<TiledMap> _tmx(String name) =>
    TileMapParser.parse(File('$_dir/$name').readAsStringSync(),
        tsxProvider: _files);

/// Everything the models hold, in one comparable string — tilesets in
/// full even when the map refers to them by file.
String _canon(TiledMap map) => jsonEncode({
  'map': TmjWriter.toJson(map, tiledVersion: '-'),
  'tilesets': [for (final ts in map.tilesets) TmjWriter.tilesetToJson(ts)],
});

void main() {
  group('a finite orthogonal map', () {
    late TiledMap map;
    setUpAll(() async => map = await _tmx('ortho_finite.tmx'));

    test('keeps the map attributes Tiled 1.8+ added', () {
      expect(map.className, 'Level');
      expect(map.parallaxOriginX, 160);
      expect(map.parallaxOriginY, 90);
      expect(map.backgroundColor, const Color(0xFF203040));
      expect(map.nextLayerId, 7);
    });

    test('keeps each property with its declared type', () {
      final p = map.properties;
      expect(p['door'], 5);
      expect(p.typeOf('door'), 'object');
      expect(p['music'], 'music/level1.ogg');
      expect(p.typeOf('music'), 'file');
      expect(p['fog'], const Color(0x80112233));
      expect(p.typeOf('gravity'), 'float');
      expect(p['dark'], false);
      expect(p.typeOf('title'), 'string');
    });

    test('reads the whole tileset', () {
      final ts = map.tilesets.single;
      expect(ts.className, 'Outdoor');
      expect((ts.spacing, ts.margin, ts.columns), (1, 2, 4));
      expect(ts.tileOffset, const Offset(0, 4));
      expect(ts.transparentColor, const Color(0xFFFF00FF));
      expect(ts.transformations.hflip, isTrue);
      expect(ts.transformations.vflip, isFalse);
      expect(ts.transformations.rotate, isTrue);
      expect(ts.transformations.preferUntransformed, isTrue);
      expect(ts.tiles[0]!.type, 'Ground');
      expect(ts.tiles[0]!.probability, 0.5);
      expect(ts.tiles[0]!.objectGroup.single.width, 16);
      expect(ts.tiles[3]!.objectGroup.single.polygon, hasLength(3));
      expect([for (final f in ts.tiles[5]!.animation) f.duration], [120, 80]);

      final set = ts.wangSets.single;
      expect(set.type, WangSetType.corner);
      expect([for (final c in set.colors) c.name], ['grass', 'dirt']);
      expect(set.colors[1].probability, 0.5);
      expect(set.wangTiles[2], [0, 1, 0, 2, 0, 2, 0, 1]);
    });

    test('reads every flip combination, and the layer attributes', () {
      final layer = map.layers.first as TileLayer;
      expect(layer.className, 'Solid');
      expect(layer.locked, isTrue);
      expect(layer.opacity, 0.75);
      expect(layer.tintColor, const Color(0xFFCC8844));
      expect((layer.offsetX, layer.offsetY), (8.0, -4.0));
      expect((layer.parallaxX, layer.parallaxY), (0.5, 0.25));

      const h = TiledGid.flipHorizontal;
      const v = TiledGid.flipVertical;
      const d = TiledGid.flipDiagonal;
      expect(layer.rawData, [
        1, 2, 3, 4, //
        h | 1, v | 2, d | 3, h | v | 4,
        h | d | 1, v | d | 2, h | v | d | 3, 0,
      ]);
      expect(layer.data.sublist(4, 8), [1, 2, 3, 4]);
      expect(layer.flipDiagonal[6], isTrue);
    });

    test('reads every kind of object', () {
      final objects = (map.layers[1] as ObjectGroup).objects;
      expect(objects[0].isPoint, isTrue);
      expect(objects[0].type, 'PlayerSpawn');
      expect(objects[1].rotation, 15);
      expect(objects[1].properties['once'], true);
      expect(objects[2].isEllipse, isTrue);
      expect(objects[3].polygon, hasLength(3));
      expect(objects[4].visible, isFalse);
      expect(objects[4].polyline, hasLength(3));
      expect(objects[5].text, 'Hello');
      expect(objects[6].gid, TiledGid.flipHorizontal | 6);
    });

    test('reads base64 data, zlib and gzip compressed, inside a group', () {
      final group = map.layers[3] as GroupLayer;
      const expected = [1, 2, 3, 4, 5, 6, 7, 8, 0x40000001, 0, 0, 2];
      expect((group.layers[0] as TileLayer).rawData, expected);
      expect((group.layers[1] as TileLayer).rawData, expected);
      expect((group.layers[1] as TileLayer).visible, isFalse);
    });

    test('reads an image layer that repeats', () {
      final sky = map.layers[2] as ImageLayer;
      expect(sky.repeatX, isTrue);
      expect(sky.repeatY, isFalse);
      expect((sky.imageWidth, sky.imageHeight), (320, 180));
    });
  });

  test('the hexagonal 120° flag stays out of the id and in the raw data', () async {
    final map = await _tmx('hexagonal.tmx');
    final layer = map.tileLayers.single;

    expect(layer.rawData![1], TiledGid.rotateHex120 | 1);
    expect(layer.data[1], 1, reason: 'the flag is not part of the id');
    expect(TiledGid.isRotatedHex120(layer.rawData![2]), isTrue);
    expect(TiledGid.isFlippedHorizontally(layer.rawData![2]), isTrue);
    expect(layer.data[2], 2);
    expect(map.hexSideLength, 6);
    expect(map.staggerAxis, StaggerAxis.y);
    expect(map.staggerIndex, StaggerIndex.odd);
  });

  test('an infinite map is read chunk by chunk', () async {
    final map = await _tmx('infinite.tmx');
    final ground = map.tileLayers.first;

    expect(map.infinite, isTrue);
    expect(ground.isChunked, isTrue);
    expect(ground.data, isEmpty);
    final a = ground.chunks[0];
    final b = ground.chunks[1];
    expect((a.x, a.y, a.width, a.height), (-16, 0, 16, 16));
    expect(a.data[15], 1);
    expect(a.data[15 * 16], 2);
    expect(b.data[0], 3);
    expect(b.data[2 * 16 + 5], TiledGid.flipHorizontal | 4);
    expect(a.data.where((g) => g != 0), hasLength(2));

    final plain = map.tileLayers[1].chunks.single;
    expect((plain.x, plain.y, plain.width), (0, 16, 2));
    expect(plain.data, [3, 0, 0, 4]);
  });

  test('isometric and staggered maps keep their orientation', () async {
    final iso = await _tmx('isometric.tmx');
    expect(iso.orientation, MapOrientation.isometric);
    final ts = iso.tilesets.single;
    expect(ts.objectAlignment, ObjectAlignment.bottom);
    expect(ts.grid!.orientation, MapOrientation.isometric);
    expect(ts.tileOffset, const Offset(0, 8));

    final staggered = await _tmx('staggered.tmx');
    expect(staggered.orientation, MapOrientation.staggered);
    expect(staggered.staggerAxis, StaggerAxis.x);
    expect(staggered.staggerIndex, StaggerIndex.even);
  });

  test('external TSX and TSJ tilesets are read through the provider', () async {
    final map = await _tmx('external.tmx');
    final terrain = map.tilesets[0];
    final props = map.tilesets[1];

    expect(terrain.source, 'tilesets/terrain.tsx');
    expect(terrain.className, 'Ground');
    expect(terrain.objectAlignment, ObjectAlignment.bottom);
    expect(terrain.tileRenderSize, TileRenderSize.grid);
    expect(terrain.fillMode, FillMode.preserveAspectFit);
    expect(terrain.properties['biome'], 'forest');
    expect(terrain.tiles[2]!.type, 'Wall');
    expect([for (final s in terrain.wangSets) s.type], [
      WangSetType.edge,
      WangSetType.mixed,
    ]);
    expect(terrain.wangSets[1].colors[0].probability, 2);
    expect(terrain.wangSets[1].properties['note'], 'both');
    expect(terrain.wangSets[0].wangTiles[1], [0, 0, 1, 0, 0, 0, 1, 0]);

    expect(props.firstGid, 17);
    expect(props.name, 'props');
    expect(props.tiles[1]!.type, 'Spike');
    expect(props.tiles[1]!.probability, 0.25);
    expect(props.tiles[1]!.properties['damage'], 2);
  });

  test("a Wang id in Tiled's old hex form still reads", () {
    expect(TileMapParser.parseWangId('0x10101010'), [0, 1, 0, 1, 0, 1, 0, 1]);
    expect(TileMapParser.parseWangId('1,2,3,4,5,6,7,8'), [1, 2, 3, 4, 5, 6, 7, 8]);
  });

  group('written as TMX and read again, nothing is lost', () {
    for (final name in [
      'ortho_finite.tmx',
      'infinite.tmx',
      'hexagonal.tmx',
      'isometric.tmx',
      'staggered.tmx',
      'external.tmx',
    ]) {
      for (final encoding in TmxDataEncoding.values) {
        test('$name as ${encoding.name}', () async {
          final map = await _tmx(name);
          final written = TmxWriter.write(map, encoding: encoding);
          final again = await TileMapParser.parse(written, tsxProvider: _files);
          expect(_canon(again), _canon(map));
        });
      }
    }
  });

  test('the TMX a writer makes looks like the TMX Tiled makes', () async {
    final map = await _tmx('ortho_finite.tmx');
    final xml = TmxWriter.write(map);

    expect(xml, startsWith('<?xml version="1.0" encoding="UTF-8"?>'));
    expect(xml, contains('<map version="1.10"'));
    expect(xml, contains('<tile id="0" type="Ground" probability="0.5">'));
    expect(xml, contains('class="Solid"'));
    expect(xml, contains('locked="1"'));
    expect(xml, contains('<data encoding="csv">\n1,2,3,4,\n2147483649,'));
    expect(xml, contains('trans="ff00ff"'));
    expect(xml, contains('<wangtile tileid="2" wangid="0,1,0,2,0,2,0,1"/>'));
    expect(xml, contains('<property name="door" type="object" value="5"/>'));
  });

  test('a map that refers to a tileset by file refers to it again', () async {
    final map = await _tmx('external.tmx');
    final xml = TmxWriter.write(map);
    expect(xml, contains('<tileset firstgid="1" source="tilesets/terrain.tsx"/>'));
    expect(xml, contains('<tileset firstgid="17" source="tilesets/props.tsj"/>'));
  });

  test('a TSX tileset written and read again is the same tileset', () async {
    final text = File('$_dir/tilesets/terrain.tsx').readAsStringSync();
    final ts = TileMapParser.parseTileset(text);
    final again = TileMapParser.parseTileset(TsxWriter.write(ts));
    expect(
      jsonEncode(TmjWriter.tilesetToJson(again)),
      jsonEncode(TmjWriter.tilesetToJson(ts)),
    );
  });

  group('TMJ', () {
    test('reads data, objects, properties and the embedded tileset', () async {
      final map = await TmjParser.parse(
        File('$_dir/ortho.tmj').readAsStringSync(),
      );
      expect(map.tileLayers.single.rawData, [
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

    for (final zlib in [false, true]) {
      test('round trips${zlib ? ' compressed' : ''}', () async {
        final map = await TmjParser.parse(
          File('$_dir/ortho.tmj').readAsStringSync(),
        );
        final again = await TmjParser.parse(
          TmjWriter.write(map, base64Zlib: zlib),
        );
        expect(_canon(again), _canon(map));
      });
    }

    for (final name in ['ortho_finite.tmx', 'infinite.tmx', 'hexagonal.tmx']) {
      test('$name becomes TMJ and back without loss', () async {
        final map = await _tmx(name);
        final again = await TmjParser.parse(TmjWriter.write(map));
        expect(_canon(again), _canon(map));
      });
    }

    test('a TSJ tileset written and read again is the same tileset', () {
      final ts = TmjParser.parseTileset(
        File('$_dir/tilesets/props.tsj').readAsStringSync(),
      );
      final again = TmjParser.parseTileset(TmjWriter.writeTileset(ts));
      expect(
        jsonEncode(TmjWriter.tilesetToJson(again)),
        jsonEncode(TmjWriter.tilesetToJson(ts)),
      );
    });
  });

  test('raw ids are written unsigned and read back exactly', () {
    const ids = [0xF0000001, 0x0FFFFFFF, 0, 0x80000000];
    expect(TiledGid.fromBytes(TiledGid.toBytes(ids)), ids);
    expect(TiledGid.idOf(0xF0000001), 1);
    expect(TiledGid.flagsOf(0xF0000001), TiledGid.flagMask);
    expect(TiledGid.compose(7, TiledGid.flipVertical), 0x40000007);
  });
}
