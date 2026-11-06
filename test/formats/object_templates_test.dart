// Objects placed from templates (TX or TJ files), in TMX and TMJ maps:
// what they inherit, their tile renumbered for the map, and what the
// writers give back, which must be only what the object sets itself.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_tiled/just_tiled.dart';

import '../test_files.dart';

const _props = '''<?xml version="1.0" encoding="UTF-8"?>
<tileset version="1.10" tiledversion="1.10.2" name="props" tilewidth="16" tileheight="16" tilecount="8" columns="4">
 <image source="props.png" width="64" height="32"/>
</tileset>
''';

/// A map in `maps/` with an embedded tileset of 10 tiles, then `props`
/// from `tilesets/` at first gid 11, and one object per [objects] entry.
String _tmx(List<String> objects) =>
    '''<?xml version="1.0" encoding="UTF-8"?>
<map version="1.10" tiledversion="1.10.2" orientation="orthogonal" renderorder="right-down" width="2" height="2" tilewidth="16" tileheight="16" infinite="0" nextlayerid="2" nextobjectid="9">
 <tileset firstgid="1" name="ground" tilewidth="16" tileheight="16" tilecount="10" columns="5">
  <image source="ground.png" width="80" height="32"/>
 </tileset>
 <tileset firstgid="11" source="../tilesets/props.tsx"/>
 <objectgroup id="1" name="Objects">
  ${objects.join('\n  ')}
 </objectgroup>
</map>
''';

/// The same map as TMJ, its objects [objects].
String _tmj(List<Map<String, Object?>> objects) => jsonEncode({
  'type': 'map',
  'orientation': 'orthogonal',
  'width': 2,
  'height': 2,
  'tilewidth': 16,
  'tileheight': 16,
  'infinite': false,
  'tilesets': [
    {
      'firstgid': 1,
      'name': 'ground',
      'tilewidth': 16,
      'tileheight': 16,
      'tilecount': 10,
      'columns': 5,
    },
    {'firstgid': 11, 'source': '../tilesets/props.tsx'},
  ],
  'layers': [
    {'type': 'objectgroup', 'id': 1, 'name': 'Objects', 'objects': objects},
  ],
});

/// A TX template whose tile object is tile [gid] of `props`, numbered from
/// first gid 1.
String _tx(String gid) =>
    '''<?xml version="1.0" encoding="UTF-8"?>
<template>
 <tileset firstgid="1" source="../tilesets/props.tsx"/>
 <object name="chest" type="Chest" gid="$gid" width="16" height="16">
  <properties>
   <property name="loot" type="string" propertytype="Loot" value="gold"/>
   <property name="locked" type="bool" value="true"/>
  </properties>
 </object>
</template>
''';

/// The same template as Tiled writes a TJ file.
String _tj(int gid) => jsonEncode({
  'object': {
    'gid': gid,
    'height': 16,
    'name': 'chest',
    'properties': [
      {
        'name': 'loot',
        'propertytype': 'Loot',
        'type': 'string',
        'value': 'gold',
      },
      {'name': 'locked', 'type': 'bool', 'value': true},
    ],
    'rotation': 0,
    'type': 'Chest',
    'visible': true,
    'width': 16,
  },
  'tileset': {'firstgid': 1, 'source': '../tilesets/props.tsx'},
  'type': 'template',
});

MemoryFiles _files(Map<String, String> templates) =>
    MemoryFiles({'../tilesets/props.tsx': _props, ...templates});

Future<List<TiledObject>> _objects(
  List<String> objects,
  Map<String, String> templates,
) async {
  final map = await TmxParser.parse(
    _tmx(objects),
    fileProvider: _files(templates),
  );
  return map.objectGroups.single.objects;
}

void main() {
  group('a TMX map', () {
    test("numbers a template's tile object gid for the map", () async {
      final objects = await _objects(
        ['<object id="1" template="../templates/chest.tx" x="5" y="6"/>'],
        {'../templates/chest.tx': _tx('3')},
      );
      final chest = objects.single;

      // Tile 3 of props, which the map puts at 11: 3 - 1 + 11.
      expect(chest.gid, 13);
      expect(chest.name, 'chest');
      expect(chest.type, 'Chest');
      expect(chest.x, 5);
      expect(chest.width, 16);
      expect(chest.templatePath, '../templates/chest.tx');
      expect(chest.template!.gid, 13);
    });

    test('keeps the flags of the gid', () async {
      final objects = await _objects(
        ['<object id="1" template="../templates/chest.tx"/>'],
        {
          '../templates/chest.tx': _tx(
            '${TiledGid.compose(3, TiledGid.flipHorizontal)}',
          ),
        },
      );

      expect(objects.single.gid, TiledGid.compose(13, TiledGid.flipHorizontal));
    });

    test("gives way to the object's own gid, which is the map's", () async {
      final objects = await _objects(
        ['<object id="1" template="../templates/chest.tx" gid="12"/>'],
        {'../templates/chest.tx': _tx('3')},
      );

      expect(objects.single.gid, 12);
    });

    test('keeps the gid when the map lacks the tileset', () async {
      final objects = await _objects(
        ['<object id="1" template="../templates/chest.tx"/>'],
        {
          '../templates/chest.tx': _tx(
            '3',
          ).replaceFirst('../tilesets/props.tsx', 'elsewhere.tsx'),
        },
      );

      expect(objects.single.gid, 3);
    });

    test('merges properties, custom types included', () async {
      final objects = await _objects(
        [
          '<object id="1" template="../templates/chest.tx">'
              '<properties>'
              '<property name="locked" type="bool" value="false"/>'
              '</properties></object>',
        ],
        {'../templates/chest.tx': _tx('3')},
      );
      final props = objects.single.properties;

      expect(props.getBool('locked'), isFalse);
      expect(props.getString('loot'), 'gold');
      expect(props.propertyTypeOf('loot'), 'Loot');
      expect(props.propertyTypeOf('locked'), isNull);
    });

    test('loads each template once, and reads TJ templates too', () async {
      final files = _files({
        '../templates/chest.tx': _tx('3'),
        '../templates/chest.tj': _tj(2),
      });
      final map = await TmxParser.parse(
        _tmx([
          '<object id="1" template="../templates/chest.tx"/>',
          '<object id="2" template="../templates/chest.tx" x="16"/>',
          '<object id="3" template="../templates/chest.tj"/>',
        ]),
        fileProvider: files,
      );
      final objects = map.objectGroups.single.objects;

      expect(files.asked, [
        '../tilesets/props.tsx',
        '../templates/chest.tx',
        '../templates/chest.tj',
      ]);
      expect([for (final o in objects) o.gid], [13, 13, 12]);
      expect(objects[2].properties.propertyTypeOf('loot'), 'Loot');
    });

    test("an object's own shape replaces the template's", () async {
      final objects = await _objects(
        [
          '<object id="1" template="../templates/zone.tx"/>',
          '<object id="2" template="../templates/zone.tx">'
              '<polygon points="0,0 8,0 8,8"/></object>',
        ],
        {
          '../templates/zone.tx':
              '<template><object name="zone" width="32" height="32">'
              '<ellipse/></object></template>',
        },
      );

      expect(objects[0].isEllipse, isTrue);
      expect(objects[1].isEllipse, isFalse);
      expect(objects[1].polygon, hasLength(3));
    });

    test('a template that cannot be loaded leaves the object its own '
        'values', () async {
      final objects = await _objects([
        '<object id="1" template="missing.tx" name="mine" x="3"/>',
      ], const {});

      expect(objects.single.name, 'mine');
      expect(objects.single.x, 3);
      expect(objects.single.template, isNull);
      expect(objects.single.templatePath, 'missing.tx');
    });
  });

  group('a TMJ map', () {
    test('takes what its objects leave out from their templates', () async {
      // As Tiled writes a placed template: id, template and position only.
      final map = await TmjParser.parse(
        _tmj([
          {'id': 1, 'template': '../templates/chest.tj', 'x': 5, 'y': 6},
          {'id': 2, 'template': '../templates/chest.tx', 'x': 7, 'y': 8},
        ]),
        fileProvider: _files({
          '../templates/chest.tj': _tj(3),
          '../templates/chest.tx': _tx('3'),
        }),
      );

      for (final chest in map.objectGroups.single.objects) {
        expect(chest.type, 'Chest');
        expect(chest.name, 'chest');
        expect(chest.gid, 13);
        expect((chest.width, chest.height), (16.0, 16.0));
        expect(chest.properties.getString('loot'), 'gold');
        expect(chest.properties.propertyTypeOf('loot'), 'Loot');
      }
      expect(map.objectGroups.single.objects[0].x, 5);
    });

    test("keeps the object's own values over the template's", () async {
      final map = await TmjParser.parse(
        _tmj([
          {
            'id': 1,
            'template': '../templates/chest.tj',
            'x': 5,
            'y': 6,
            'name': '',
            'width': 32,
            'height': 32,
            'visible': false,
            'properties': [
              {'name': 'locked', 'type': 'bool', 'value': false},
            ],
          },
        ]),
        fileProvider: _files({'../templates/chest.tj': _tj(3)}),
      );
      final chest = map.objectGroups.single.objects.single;

      expect(chest.name, '');
      expect(chest.width, 32);
      expect(chest.visible, isFalse);
      expect(chest.properties.getBool('locked'), isFalse);
      expect(chest.properties.getString('loot'), 'gold');
    });
  });

  group('written back, an object gives only what it sets itself', () {
    late MemoryFiles files;
    late TiledMap map;
    setUp(() async {
      files = _files({'../templates/chest.tx': _tx('3')});
      map = await TmxParser.parse(
        _tmx([
          '<object id="1" template="../templates/chest.tx" x="5" y="6"/>',
          '<object id="2" template="../templates/chest.tx" name="big" '
              'x="7" y="8" width="32" height="32">'
              '<properties><property name="locked" type="bool" value="false"/>'
              '</properties></object>',
        ]),
        fileProvider: files,
      );
    });

    test('as TMX', () async {
      final xml = TmxWriter.write(map);

      expect(
        xml,
        contains(
          '<object id="1" template="../templates/chest.tx" x="5" y="6"/>',
        ),
      );
      expect(
        xml,
        contains(
          '<object id="2" template="../templates/chest.tx" name="big" x="7" '
          'y="8" width="32" height="32">',
        ),
      );
      expect(
        xml,
        contains('<property name="locked" type="bool" value="false"/>'),
      );
      expect(xml, isNot(contains('loot')));
      expect(xml, isNot(contains(' gid=')));

      // Read again, the objects are the same: the rest still comes from
      // the template.
      final again = await TmxParser.parse(xml, fileProvider: files);
      expect(_objectsJson(again), _objectsJson(map));
    });

    test('as TMJ', () async {
      final objects = TmjWriter.toJson(map)['layers'][0]['objects'] as List;

      expect(objects[0], {
        'id': 1,
        'template': '../templates/chest.tx',
        'x': 5.0,
        'y': 6.0,
      });
      expect(objects[1], {
        'height': 32.0,
        'id': 2,
        'name': 'big',
        'properties': [
          {'name': 'locked', 'type': 'bool', 'value': false},
        ],
        'template': '../templates/chest.tx',
        'width': 32.0,
        'x': 7.0,
        'y': 8.0,
      });

      final again = await TmjParser.parse(
        TmjWriter.write(map),
        fileProvider: files,
      );
      expect(_objectsJson(again), _objectsJson(map));
    });
  });
}

/// Every object of [map], in full: what it holds, inherited or not.
String _objectsJson(TiledMap map) => jsonEncode([
  for (final o in map.objectGroups.single.objects)
    {
      'id': o.id,
      'name': o.name,
      'type': o.type,
      'gid': o.gid,
      'x': o.x,
      'y': o.y,
      'size': [o.width, o.height],
      'visible': o.visible,
      'template': o.templatePath,
      'properties': {
        for (final key in o.properties.keys)
          key: [
            o.properties[key],
            o.properties.typeOf(key),
            o.properties.propertyTypeOf(key),
          ],
      },
    },
]);
