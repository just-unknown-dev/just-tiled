/// Global tile ids and the flags Tiled packs into their top bits.
library;

import 'dart:typed_data';

/// A raw global tile id, as a map stores it: the tile's global id in the low
/// 28 bits and four transform flags above it.
///
/// Work on raw ids with these helpers rather than by hand. On the web every
/// int is a double, so the flags must be read with masks (never by sign or by
/// comparison), and a raw id must be written as an unsigned 32-bit value.
abstract final class TiledGid {
  /// The tile is mirrored left to right.
  static const int flipHorizontal = 0x80000000;

  /// The tile is mirrored top to bottom.
  static const int flipVertical = 0x40000000;

  /// The tile is mirrored across its top-left to bottom-right diagonal —
  /// with the two flips above, how Tiled expresses a 90° rotation.
  static const int flipDiagonal = 0x20000000;

  /// Hexagonal maps only: the tile is turned 120°.
  static const int rotateHex120 = 0x10000000;

  /// Every flag bit.
  static const int flagMask = 0xF0000000;

  /// The bits holding the global id itself.
  static const int idMask = 0x0FFFFFFF;

  /// The global id in [raw], without its flags.
  static int idOf(int raw) => raw & idMask;

  /// The flag bits of [raw].
  static int flagsOf(int raw) => raw & flagMask;

  /// Whether [raw] has [flipHorizontal] set.
  static bool isFlippedHorizontally(int raw) => (raw & flipHorizontal) != 0;

  /// Whether [raw] has [flipVertical] set.
  static bool isFlippedVertically(int raw) => (raw & flipVertical) != 0;

  /// Whether [raw] has [flipDiagonal] set.
  static bool isFlippedDiagonally(int raw) => (raw & flipDiagonal) != 0;

  /// Whether [raw] has [rotateHex120] set.
  static bool isRotatedHex120(int raw) => (raw & rotateHex120) != 0;

  /// [id] with [flags] set, as an unsigned 32-bit value.
  static int compose(int id, [int flags = 0]) =>
      ((id & idMask) | (flags & flagMask)).toUnsigned(32);

  /// Reads little-endian unsigned 32-bit ids from [bytes].
  static Uint32List fromBytes(Uint8List bytes) {
    final count = bytes.length ~/ 4;
    final view = ByteData.sublistView(bytes);
    final out = Uint32List(count);
    for (var i = 0; i < count; i++) {
      out[i] = view.getUint32(i * 4, Endian.little);
    }
    return out;
  }

  /// Writes [ids] as little-endian unsigned 32-bit values.
  static Uint8List toBytes(List<int> ids) {
    final out = ByteData(ids.length * 4);
    for (var i = 0; i < ids.length; i++) {
      out.setUint32(i * 4, ids[i].toUnsigned(32), Endian.little);
    }
    return out.buffer.asUint8List();
  }
}
