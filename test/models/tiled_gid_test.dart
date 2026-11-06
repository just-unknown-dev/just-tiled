import 'package:flutter_test/flutter_test.dart';
import 'package:just_tiled/just_tiled.dart';

void main() {
  test('raw ids are written unsigned and read back exactly', () {
    const ids = [0xF0000001, 0x0FFFFFFF, 0, 0x80000000];
    expect(TiledGid.fromBytes(TiledGid.toBytes(ids)), ids);
    expect(TiledGid.idOf(0xF0000001), 1);
    expect(TiledGid.flagsOf(0xF0000001), TiledGid.flagMask);
    expect(TiledGid.compose(7, TiledGid.flipVertical), 0x40000007);
  });
}
