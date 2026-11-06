/// Reading tile data, shared by the TMX and TMJ readers: base64, compressed
/// or not, and a count of tiles that must match the layer's size.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:just_deflate/just_deflate.dart';
import 'package:just_zstd/just_zstd.dart';
import 'package:meta/meta.dart';

import '../models/models.dart';

/// The [cells] raw tile ids of [what] (a layer or chunk, for the message)
/// in the base64 [text], unpacked by [compression].
///
/// Throws [FormatException] if the text isn't base64, the data is damaged,
/// or it doesn't hold exactly [cells] ids.
@internal
Uint32List decodeBase64Tiles(
  String text,
  LayerCompression compression,
  int cells,
  String what,
) => unpackTileIds(base64Decode(text.trim()), compression, cells, what);

/// The [cells] raw tile ids of [what] in [bytes], a layer's or chunk's
/// base64-decoded data, unpacked by [compression].
///
/// Compressed data may not unpack to more than the [cells] ids' bytes:
/// every decoder stops as soon as it passes them, so damaged or hostile
/// data throws a [FormatException] rather than filling memory.
///
/// Throws [FormatException] unless the data holds exactly [cells] ids.
@internal
Uint32List unpackTileIds(
  Uint8List bytes,
  LayerCompression compression,
  int cells,
  String what,
) {
  final size = cells * 4;
  final Uint8List plain = switch (compression) {
    LayerCompression.none => bytes,
    LayerCompression.gzip => const GzipCodec().decode(
      bytes,
      maxOutputSize: size,
    ),
    LayerCompression.zlib => const ZlibCodec().decode(
      bytes,
      maxOutputSize: size,
    ),
    LayerCompression.zstd => const ZstdDecoder().decode(
      bytes,
      maxOutputSize: size,
    ),
  };
  if (plain.length != size) {
    throw FormatException(
      'The tile data of $what holds ${plain.length} bytes, not the $size of '
      'its $cells tiles',
    );
  }
  return TiledGid.fromBytes(plain);
}

/// [ids], the tiles of [what] as CSV, XML or JSON numbers, if there are
/// exactly [cells] of them.
///
/// Throws [FormatException] otherwise.
@internal
Uint32List checkTileCount(Uint32List ids, int cells, String what) {
  if (ids.length != cells) {
    throw FormatException(
      'The tile data of $what holds ${ids.length} tiles, not $cells',
    );
  }
  return ids;
}
