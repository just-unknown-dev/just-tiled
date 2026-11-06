// AssetTiledFileProvider: which asset a path from the map loads.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_tiled/just_tiled.dart';

const _props = '''<?xml version="1.0" encoding="UTF-8"?>
<tileset version="1.10" tiledversion="1.10.2" name="props" tilewidth="16" tileheight="16" tilecount="8" columns="4">
 <image source="props.png" width="64" height="32"/>
</tileset>
''';

const _map = '''<?xml version="1.0" encoding="UTF-8"?>
<map version="1.10" orientation="orthogonal" width="1" height="1" tilewidth="16" tileheight="16" infinite="0">
 <tileset firstgid="1" source="../tilesets/props.tsx"/>
</map>
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const maps = AssetTiledFileProvider(basePath: 'assets/maps');

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
      const AssetTiledFileProvider(basePath: 'assets/maps/').resolve('t.tsx'),
      'assets/maps/t.tsx',
    );
  });

  test('takes assets/ and / paths from the bundle root', () {
    expect(maps.resolve('assets/shared/t.tsx'), 'assets/shared/t.tsx');
    expect(maps.resolve('/assets/shared/t.tsx'), 'assets/shared/t.tsx');
  });

  test('without a basePath, keeps the path as written', () {
    expect(const AssetTiledFileProvider().resolve('t/./x.tsx'), 't/x.tsx');
    expect(const AssetTiledFileProvider().resolve('../x.tsx'), '../x.tsx');
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
    addTearDown(() => messenger.setMockMessageHandler('flutter/assets', null));

    final map = await TmxParser.parse(_map, fileProvider: maps);

    expect(asked, ['assets/tilesets/props.tsx']);
    expect(map.tilesets.single.name, 'props');
    expect(map.tilesets.single.tileCount, 8);
  });
}
