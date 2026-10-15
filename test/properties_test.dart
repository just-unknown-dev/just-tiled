// Custom properties of Tiled's custom types (Tiled 1.8+): enum properties
// keep their type's name, class properties their members — read from TMX
// and TMJ, and written back by every writer.

import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_tiled/just_tiled.dart';

const _tmx = '''<?xml version="1.0" encoding="UTF-8"?>
<map version="1.10" tiledversion="1.10.2" orientation="orthogonal" renderorder="right-down" width="1" height="1" tilewidth="16" tileheight="16" infinite="0" nextlayerid="2" nextobjectid="1">
 <properties>
  <property name="dir" propertytype="Direction" value="Left"/>
  <property name="speed" type="int" propertytype="Speed" value="2"/>
  <property name="stats" type="class" propertytype="Stats">
   <properties>
    <property name="hp" type="int" value="10"/>
    <property name="inner" type="class" propertytype="Inner">
     <properties>
      <property name="tint" type="color" value="#ff00ff00"/>
     </properties>
    </property>
   </properties>
  </property>
  <property name="defaults" type="class" propertytype="Stats"/>
 </properties>
 <layer id="1" name="L" width="1" height="1">
  <data encoding="csv">
0
</data>
 </layer>
</map>
''';

void _expectCustomTypes(TiledProperties p, {required bool colorsTyped}) {
  expect(p.getString('dir'), 'Left');
  expect(p.typeOf('dir'), 'string');
  expect(p.propertyTypeOf('dir'), 'Direction');
  expect(p.getInt('speed'), 2);
  expect(p.propertyTypeOf('speed'), 'Speed');

  expect(p.typeOf('stats'), 'class');
  expect(p.propertyTypeOf('stats'), 'Stats');
  final stats = p.getClass('stats')!;
  expect(stats.getInt('hp'), 10);
  final inner = stats.getClass('inner')!;
  if (colorsTyped) {
    expect(inner['tint'], const Color(0xFF00FF00));
    expect(stats.propertyTypeOf('inner'), 'Inner');
  } else {
    // TMJ gives a class's members as bare values.
    expect(inner['tint'], '#00ff00');
  }

  expect(p.getClass('defaults')!.isEmpty, isTrue);
  expect(p.propertyTypeOf('defaults'), 'Stats');
  expect(p.getClass('dir'), isNull);
}

void main() {
  test('TMX keeps custom types and class members', () async {
    final map = await TileMapParser.parse(_tmx);
    _expectCustomTypes(map.properties, colorsTyped: true);
  });

  test('TMX written and read again keeps them', () async {
    final written = TmxWriter.write(await TileMapParser.parse(_tmx));

    expect(written, contains('propertytype="Stats"'));
    // A class's members are pretty-printed, not run together.
    expect(
      written,
      contains('<property name="stats" type="class" propertytype="Stats">\n'),
    );

    final again = await TileMapParser.parse(written);
    _expectCustomTypes(again.properties, colorsTyped: true);
  });

  test('TMJ written and read again keeps them, members as values', () async {
    final written = TmjWriter.write(await TileMapParser.parse(_tmx));
    final stats = (jsonDecode(written)['properties'] as List).firstWhere(
      (p) => p['name'] == 'stats',
    );

    expect(stats, {
      'name': 'stats',
      'propertytype': 'Stats',
      'type': 'class',
      'value': {
        'hp': 10,
        'inner': {'tint': '#00ff00'},
      },
    });

    final again = await TmjParser.parse(written);
    _expectCustomTypes(again.properties, colorsTyped: false);
  });

  test('TMJ reads the form Tiled writes', () async {
    final map = await TmjParser.parse(
      jsonEncode({
        'type': 'map',
        'orientation': 'orthogonal',
        'width': 1,
        'height': 1,
        'tilewidth': 16,
        'tileheight': 16,
        'layers': <Object>[],
        'tilesets': <Object>[],
        'properties': [
          {
            'name': 'dir',
            'propertytype': 'Direction',
            'type': 'string',
            'value': 'Left',
          },
          {
            'name': 'stats',
            'propertytype': 'Stats',
            'type': 'class',
            'value': {
              'hp': 10,
              'inner': {'tint': '#ff00ff00'},
            },
          },
        ],
      }),
    );
    final p = map.properties;

    expect(p.propertyTypeOf('dir'), 'Direction');
    expect(p.getClass('stats')!.getInt('hp'), 10);
    expect(p.getClass('stats')!.typeOf('inner'), 'class');
    expect(p.getClass('stats')!.getClass('inner')!['tint'], '#ff00ff00');
  });
}
