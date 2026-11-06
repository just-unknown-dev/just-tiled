import 'package:flutter_test/flutter_test.dart';
import 'package:just_tiled/just_tiled.dart';

const _twoTilesets = '''<?xml version="1.0" encoding="UTF-8"?>
<map version="1.10" orientation="orthogonal" width="1" height="1"
     tilewidth="16" tileheight="16" infinite="0">
 <tileset firstgid="1" name="a" tilewidth="16" tileheight="16"
          tilecount="4" columns="2"/>
 <tileset firstgid="5" name="b" tilewidth="16" tileheight="16"
          tilecount="4" columns="2"/>
</map>''';

void main() {
  test('tileLayers collects recursively through GroupLayer', () async {
    const tmx = '''<?xml version="1.0" encoding="UTF-8"?>
<map version="1.10" orientation="orthogonal" renderorder="right-down"
     width="2" height="2" tilewidth="16" tileheight="16" infinite="0"
     nextlayerid="4" nextobjectid="1">
 <tileset firstgid="1" name="t" tilewidth="16" tileheight="16"
          tilecount="1" columns="1">
  <image source="t.png" width="16" height="16"/>
 </tileset>
 <group id="1" name="g">
  <layer id="2" name="inner" width="2" height="2">
   <data encoding="csv">1,0,0,1</data>
  </layer>
 </group>
 <layer id="3" name="outer" width="2" height="2">
  <data encoding="csv">0,1,1,0</data>
 </layer>
</map>''';
    final map = await TmxParser.parse(tmx);
    expect(map.tileLayers, hasLength(2));
    expect(map.tileLayers.map((l) => l.name), containsAll(['inner', 'outer']));
  });

  test('findTilesetForGid returns the tileset holding the id', () async {
    final map = await TmxParser.parse(_twoTilesets);
    expect(map.findTilesetForGid(2)!.name, 'a');
    expect(map.findTilesetForGid(5)!.name, 'b');
    expect(map.findTilesetForGid(8)!.name, 'b');
  });

  test('findTilesetForGid returns null for gid 0', () async {
    final map = await TmxParser.parse(_twoTilesets);
    expect(map.findTilesetForGid(0), isNull);
  });
}
