import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_tiled/just_tiled.dart';

import '../../test_files.dart';

void main() {
  test('the TMX a writer makes looks like the TMX Tiled makes', () async {
    final map = await TmxParser.parse(
      fixture('ortho_finite.tmx'),
      fileProvider: FolderFiles(),
    );
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

  test('each encoding writes its data attributes', () async {
    final map = await TmxParser.parse(fixture('ortho_finite.tmx'));
    String data(TiledDataEncoding encoding) => RegExp(
      r'<data[^>]*>',
    ).firstMatch(TmxWriter.write(map, encoding: encoding))!.group(0)!;

    expect(data(TiledDataEncoding.csv), '<data encoding="csv">');
    expect(data(TiledDataEncoding.base64), '<data encoding="base64">');
    expect(
      data(TiledDataEncoding.base64Zlib),
      '<data encoding="base64" compression="zlib">',
    );
    expect(
      data(TiledDataEncoding.base64Gzip),
      '<data encoding="base64" compression="gzip">',
    );
  });

  test('a map that refers to a tileset by file refers to it again', () async {
    final map = await TmxParser.parse(
      fixture('external.tmx'),
      fileProvider: FolderFiles(),
    );
    final xml = TmxWriter.write(map);
    expect(
      xml,
      contains('<tileset firstgid="1" source="tilesets/terrain.tsx"/>'),
    );
    expect(
      xml,
      contains('<tileset firstgid="17" source="tilesets/props.tsj"/>'),
    );
  });

  test('a TSX tileset written and read again is the same tileset', () {
    final ts = TmxParser.parseTileset(fixture('tilesets/terrain.tsx'));
    final again = TmxParser.parseTileset(TsxWriter.write(ts));
    expect(
      jsonEncode(TmjWriter.tilesetToJson(again)),
      jsonEncode(TmjWriter.tilesetToJson(ts)),
    );
  });
}
