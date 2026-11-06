import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_deflate/just_deflate.dart';
import 'package:just_tiled/just_tiled.dart';

const _minimalOrthogonalTmx = '''<?xml version="1.0" encoding="UTF-8"?>
<map version="1.10" tiledversion="1.10.2" orientation="orthogonal"
     renderorder="right-down" width="3" height="2"
     tilewidth="32" tileheight="32" infinite="0"
     nextlayerid="3" nextobjectid="5">
 <properties>
  <property name="level" type="int" value="1"/>
  <property name="theme" value="desert"/>
  <property name="gravity" type="float" value="9.8"/>
  <property name="active" type="bool" value="true"/>
 </properties>
 <tileset firstgid="1" name="ground" tilewidth="32" tileheight="32"
          tilecount="4" columns="2" spacing="2" margin="1">
  <image source="ground.png" width="68" height="68"/>
 </tileset>
 <layer id="1" name="Ground" width="3" height="2">
  <data encoding="csv">
1,2,3,
4,0,1
</data>
 </layer>
 <objectgroup id="2" name="Triggers" draworder="topdown" color="#ff0000">
  <object id="1" name="spawn" type="SpawnPoint" x="16" y="16"
          width="32" height="32"/>
  <object id="2" name="zone" x="64" y="32">
   <ellipse/>
  </object>
  <object id="3" name="corner" x="0" y="0">
   <point/>
  </object>
  <object id="4" name="region" x="10" y="10">
   <polygon points="0,0 32,0 32,32 0,32"/>
  </object>
 </objectgroup>
</map>''';

const _isometricTmx = '''<?xml version="1.0" encoding="UTF-8"?>
<map version="1.10" orientation="isometric" renderorder="right-down"
     width="4" height="4" tilewidth="64" tileheight="32" infinite="0"
     nextlayerid="2" nextobjectid="1">
 <tileset firstgid="1" name="iso" tilewidth="64" tileheight="32"
          tilecount="2" columns="2">
  <image source="iso.png" width="128" height="32"/>
 </tileset>
 <layer id="1" name="Base" width="4" height="4">
  <data encoding="csv">1,2,1,2,2,1,2,1,1,2,1,2,2,1,2,1</data>
 </layer>
</map>''';

/// A 2 x 2 layer of ids 1 to 4, base64 and zlib-compressed.
String _base64ZlibTmx() {
  final bytes = Uint8List(16);
  for (var i = 0; i < 4; i++) {
    bytes[i * 4] = i + 1;
  }
  final b64 = base64Encode(const ZlibCodec().encode(bytes));
  return '''<?xml version="1.0" encoding="UTF-8"?>
<map version="1.10" orientation="orthogonal" renderorder="right-down"
     width="2" height="2" tilewidth="16" tileheight="16" infinite="0"
     nextlayerid="2" nextobjectid="1">
 <tileset firstgid="1" name="t" tilewidth="16" tileheight="16"
          tilecount="4" columns="2">
  <image source="t.png" width="32" height="32"/>
 </tileset>
 <layer id="1" name="L" width="2" height="2">
  <data encoding="base64" compression="zlib">$b64</data>
 </layer>
</map>''';
}

/// A 1-row layer of tile 1 under every combination of the three flips,
/// written as Tiled once wrote them: signed 32-bit numbers.
String _flipFlagTmx() {
  const h = 0x80000000, v = 0x40000000, d = 0x20000000;
  final gids = [1, 1 | h, 1 | v, 1 | h | v, 1 | d, 1 | d | h, 1 | d | v];
  final csv = [
    for (final g in [...gids, 1 | d | h | v])
      g > 0x7FFFFFFF ? g - 0x100000000 : g,
  ].join(',');
  return '''<?xml version="1.0" encoding="UTF-8"?>
<map version="1.10" orientation="orthogonal" renderorder="right-down"
     width="8" height="1" tilewidth="16" tileheight="16" infinite="0"
     nextlayerid="2" nextobjectid="1">
 <tileset firstgid="1" name="t" tilewidth="16" tileheight="16"
          tilecount="1" columns="1">
  <image source="t.png" width="16" height="16"/>
 </tileset>
 <layer id="1" name="L" width="8" height="1">
  <data encoding="csv">$csv</data>
 </layer>
</map>''';
}

void main() {
  test('parses root map attributes', () async {
    final map = await TmxParser.parse(_minimalOrthogonalTmx);

    expect(map.width, equals(3));
    expect(map.height, equals(2));
    expect(map.tileWidth, equals(32));
    expect(map.tileHeight, equals(32));
    expect(map.orientation, equals(MapOrientation.orthogonal));
    expect(map.renderOrder, equals(RenderOrder.rightDown));
    expect(map.infinite, isFalse);
    expect(map.pixelWidth, equals(96));
    expect(map.pixelHeight, equals(64));
  });

  test('parses custom map properties', () async {
    final map = await TmxParser.parse(_minimalOrthogonalTmx);

    expect(map.properties.getInt('level'), equals(1));
    expect(map.properties.getString('theme'), equals('desert'));
    expect(map.properties.getDouble('gravity'), closeTo(9.8, 0.001));
    expect(map.properties.getBool('active'), isTrue);
  });

  test('parses tileset', () async {
    final map = await TmxParser.parse(_minimalOrthogonalTmx);

    expect(map.tilesets, hasLength(1));
    final ts = map.tilesets.first;
    expect(ts.firstGid, equals(1));
    expect(ts.name, equals('ground'));
    expect(ts.columns, equals(2));
    expect(ts.spacing, equals(2));
    expect(ts.margin, equals(1));
    expect(ts.imageSource, equals('ground.png'));
  });

  test('parses CSV tile layer', () async {
    final map = await TmxParser.parse(_minimalOrthogonalTmx);

    expect(map.tileLayers, hasLength(1));
    final layer = map.tileLayers.first;
    expect(layer.name, equals('Ground'));
    expect(layer.width, equals(3));
    expect(layer.height, equals(2));
    expect(layer.gids, equals([1, 2, 3, 4, 0, 1]));
  });

  test('parses object group', () async {
    final map = await TmxParser.parse(_minimalOrthogonalTmx);

    expect(map.objectGroups, hasLength(1));
    final group = map.objectGroups.first;
    expect(group.objects, hasLength(4));

    final spawn = group.objects[0];
    expect(spawn.name, equals('spawn'));
    expect(spawn.type, equals('SpawnPoint'));
    expect(spawn.x, equals(16.0));
    expect(spawn.y, equals(16.0));

    expect(group.objects[1].isEllipse, isTrue);
    expect(group.objects[2].isPoint, isTrue);
    expect(group.objects[3].polygon, hasLength(4));
  });

  test('parses isometric map orientation', () async {
    final map = await TmxParser.parse(_isometricTmx);
    expect(map.orientation, equals(MapOrientation.isometric));
    expect(map.tileWidth, equals(64));
  });

  test('parses base64 + zlib compressed layer', () async {
    final map = await TmxParser.parse(_base64ZlibTmx());

    final layer = map.tileLayers.first;
    expect(layer.gids, equals([1, 2, 3, 4]));
    expect(layer.encoding, equals(LayerEncoding.base64));
    expect(layer.compression, equals(LayerCompression.zlib));
  });

  test('throws FormatException for non-map root element', () async {
    expect(() => TmxParser.parse('<notmap/>'), throwsA(isA<FormatException>()));
  });

  test('keeps every flip combination in the raw ids, signed or not', () async {
    final layer = (await TmxParser.parse(_flipFlagTmx())).tileLayers.single;
    const h = TiledGid.flipHorizontal;
    const v = TiledGid.flipVertical;
    const d = TiledGid.flipDiagonal;

    expect(layer.gids, [
      1, h | 1, v | 1, h | v | 1, //
      d | 1, d | h | 1, d | v | 1, d | h | v | 1,
    ]);
    for (var i = 0; i < 8; i++) {
      expect(layer.idAt(i), 1);
    }
  });

  test("a Wang id in Tiled's old hex form still reads", () {
    final ts = TmxParser.parseTileset('''<?xml version="1.0" encoding="UTF-8"?>
<tileset name="t" tilewidth="16" tileheight="16" tilecount="2" columns="2">
 <wangsets>
  <wangset name="w" type="corner" tile="-1">
   <wangcolor name="a" color="#ff0000" tile="-1" probability="1"/>
   <wangtile tileid="0" wangid="0x10101010"/>
   <wangtile tileid="1" wangid="1,2,3,4,5,6,7,8"/>
  </wangset>
 </wangsets>
</tileset>''');
    final tiles = ts.wangSets.single.wangTiles;

    expect(tiles[0], [0, 1, 0, 1, 0, 1, 0, 1]);
    expect(tiles[1], [1, 2, 3, 4, 5, 6, 7, 8]);
  });
}
