/// Unpacking base64 tile data, shared by the TMX and TMJ readers.
library;

import 'dart:typed_data';

import 'package:just_deflate/just_deflate.dart';
import 'package:just_zstd/just_zstd.dart';

import '../models/models.dart';

/// The raw tile ids in [bytes]: a layer's or chunk's base64-decoded data,
/// of [cells] tiles, unpacked by [compression].
///
/// Compressed data may not unpack to more than [cells] ids, so damaged or
/// hostile data throws a [FormatException] rather than filling memory; 0
/// [cells] (no size given) sets no limit. zlib and gzip stop as soon as
/// the limit is passed.
///
/// Zstandard data must unpack to exactly [cells] ids. The Zstandard decoder
/// takes no limit, and it reads only some frames right (uncompressed
/// blocks): on others it returns the wrong bytes rather than failing, and
/// the size is what shows it.
Uint32List unpackTileIds(
  Uint8List bytes,
  LayerCompression compression,
  int cells,
) {
  final limit = cells > 0 ? cells * 4 : null;
  final Uint8List plain = switch (compression) {
    LayerCompression.none => bytes,
    LayerCompression.gzip => const GzipCodec().decode(
      bytes,
      maxOutputSize: limit,
    ),
    LayerCompression.zlib => const ZlibCodec().decode(
      bytes,
      maxOutputSize: limit,
    ),
    LayerCompression.zstd => const ZstdDecoder().decodeBytes(bytes),
  };
  if (compression == LayerCompression.zstd &&
      limit != null &&
      plain.length != limit) {
    throw FormatException(
      'Zstandard tile data unpacks to ${plain.length} bytes, not the $limit '
      'of its $cells tiles: the data is damaged, or uses Zstandard '
      'features the decoder cannot read yet',
    );
  }
  return TiledGid.fromBytes(plain);
}
