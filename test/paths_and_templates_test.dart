// Where external files come from: DefaultTsxProvider's asset paths, and
// templates whose tile objects number their tiles from their own tileset.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_tiled/just_tiled.dart';

/// Files by path, as written in the map.
class _Files implements TsxProvider {
  _Files(this.files);
  final Map<String, String> files;

  @override
  Future<String> getTsx(String source) async => files[source]!;

  @override
  Future<String> getTemplate(String source) async => files[source]!;
}

const _props = '''<?xml version="1.0" encoding="UTF-8"?>
<tileset version="1.10" tiledversion="1.10.2" name="props" tilewidth="16" tileheight="16" tilecount="8" columns="4">
 <image source="props.png" width="64" height="32"/>
</tileset>
''';

/// A map in `maps/` with an embedded tileset of 10 tiles, then `props`
/// from `tilesets/` at first gid 11, and one object per [objects] entry.
String _map(List<String> objects) =>
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

/// A template whose tile object is tile [gid] of `props`, numbered from
/// first gid 1.
String _template(String gid) =>
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

Future<List<TiledObject>> _objects(
  List<String> objects,
  Map<String, String> files,
) async {
  final map = await TileMapParser.parse(
    _map(objects),
    tsxProvider: _Files({'../tilesets/props.tsx': _props, ...files}),
  );
  return map.objectGroups.single.objects;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DefaultTsxProvider.resolve', () {
    const maps = DefaultTsxProvider(basePath: 'assets/maps');

    test('reads a path from the map folder, collapsing . and ..', () {
      expect(maps.resolve('terrain.tsx'), 'assets/maps/terrain.tsx');
      expect(maps.resolve('./terrain.tsx'), 'assets/maps/terrain.tsx');
      expect(
        maps.resolve('../tilesets/terrain.tsx'),
        'assets/tilesets/terrain.tsx',
      );
      expect(maps.resolve('a/../../t/x.tx'), 'assets/t/x.tx');
    });

    test(r'reads \ as / and ignores a trailing slash on basePath', () {
      expect(
        maps.resolve(r'..\tilesets\terrain.tsx'),
        'assets/tilesets/terrain.tsx',
      );
      expect(
        const DefaultTsxProvider(basePath: 'assets/maps/').resolve('t.tsx'),
        'assets/maps/t.tsx',
      );
    });

    test('takes assets/ and / paths from the bundle root', () {
      expect(maps.resolve('assets/shared/t.tsx'), 'assets/shared/t.tsx');
      expect(maps.resolve('/assets/shared/t.tsx'), 'assets/shared/t.tsx');
    });

    test('without a basePath, keeps the path as written', () {
      expect(const DefaultTsxProvider().resolve('t/./x.tsx'), 't/x.tsx');
      expect(const DefaultTsxProvider().resolve('../x.tsx'), '../x.tsx');
    });

    test('loads the asset it resolves to', () async {
      final asked = <String>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMessageHandler('flutter/assets', (message) async {
        final key = Uri.decodeFull(
          utf8.decode(message!.buffer.asUint8List(), allowMalformed: true),
        );
        asked.add(key);
        if (key != 'assets/tilesets/props.tsx') return null;
        return ByteData.sublistView(Uint8List.fromList(utf8.encode(_props)));
      });
      addTearDown(
        () => messenger.setMockMessageHandler('flutter/assets', null),
      );

      final map = await TileMapParser.parse(_map(const []), tsxProvider: maps);

      expect(asked, ['assets/tilesets/props.tsx']);
      expect(map.tilesets[1].name, 'props');
      expect(map.tilesets[1].tileCount, 8);
    });
  });

  group('a template', () {
    test("numbers its tile object's gid for the map", () async {
      final objects = await _objects(
        ['<object id="1" template="../templates/chest.tx" x="5" y="6"/>'],
        {'../templates/chest.tx': _template('3')},
      );
      final chest = objects.single;

      // Tile 3 of props, which the map puts at 11: 3 - 1 + 11.
      expect(chest.gid, 13);
      expect(chest.name, 'chest');
      expect(chest.type, 'Chest');
      expect(chest.x, 5);
      expect(chest.width, 16);
      expect(chest.templatePath, '../templates/chest.tx');
    });

    test('keeps the flags of its gid', () async {
      final objects = await _objects(
        ['<object id="1" template="../templates/chest.tx"/>'],
        {
          '../templates/chest.tx': _template(
            '${TiledGid.compose(3, TiledGid.flipHorizontal)}',
          ),
        },
      );

      expect(objects.single.gid, TiledGid.compose(13, TiledGid.flipHorizontal));
    });

    test("gives way to the object's own gid, which is the map's", () async {
      final objects = await _objects(
        ['<object id="1" template="../templates/chest.tx" gid="12"/>'],
        {'../templates/chest.tx': _template('3')},
      );

      expect(objects.single.gid, 12);
    });

    test('keeps its gid when the map lacks its tileset', () async {
      final objects = await _objects(
        ['<object id="1" template="../templates/chest.tx"/>'],
        {
          '../templates/chest.tx': _template(
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
        {'../templates/chest.tx': _template('3')},
      );
      final props = objects.single.properties;

      expect(props.getBool('locked'), isFalse);
      expect(props.getString('loot'), 'gold');
      expect(props.propertyTypeOf('loot'), 'Loot');
      expect(props.propertyTypeOf('locked'), isNull);
    });
  });
}
