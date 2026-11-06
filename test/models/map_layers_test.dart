// A tile layer keeps its tiles once: raw ids, flags in, 4 bytes a cell.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_tiled/just_tiled.dart';

void main() {
  test('gids holds raw ids; idAt takes the flags off', () {
    final layer = TileLayer(
      id: 1,
      width: 2,
      height: 1,
      gids: Uint32List.fromList([
        TiledGid.compose(5, TiledGid.flipHorizontal | TiledGid.rotateHex120),
        0,
      ]),
    );

    expect(layer.gids, [0x90000005, 0]);
    expect(layer.idAt(0), 5);
    expect(layer.idAt(1), 0);
    expect(layer.isChunked, isFalse);
  });

  test('a layer built without tiles holds none; chunks make it chunked', () {
    final chunked = TileLayer(
      id: 1,
      width: 0,
      height: 0,
      chunks: [
        TileChunk(
          x: -16,
          y: 0,
          width: 1,
          height: 1,
          gids: Uint32List.fromList([3]),
        ),
      ],
    );

    expect(chunked.gids, isEmpty);
    expect(chunked.isChunked, isTrue);
    expect(chunked.chunks.single.gids, [3]);
  });
}
