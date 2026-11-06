/// How the writers store tile data.
library;

/// How a writer stores tile data: `TmxWriter` and `TmjWriter` take the same
/// choices.
enum TiledDataEncoding {
  /// Plain numbers: in TMX comma-separated, a row per line; in TMJ a JSON
  /// array. Readable and diffable.
  csv,

  /// Little-endian ids, base64, uncompressed.
  base64,

  /// Little-endian ids, zlib-compressed, base64. Tiled's default.
  base64Zlib,

  /// Little-endian ids, gzip-compressed, base64.
  base64Gzip,
}
