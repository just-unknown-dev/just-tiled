/// How Tiled spells colours, numbers and its format version, in every file
/// kind: what the readers and writers of both formats share.
library;

import 'dart:ui';

import 'package:meta/meta.dart';

/// The TMX (and TMJ) format version the writers follow.
@internal
const String tmxFormatVersion = '1.10';

/// Tiled's colour notation: `#rrggbb`, or `#aarrggbb` when not opaque.
@internal
String tiledColor(Color color) {
  final argb = color.toARGB32();
  final alpha = (argb >> 24) & 0xFF;
  final rgb = (argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
  return alpha == 0xFF
      ? '#$rgb'
      : '#${alpha.toRadixString(16).padLeft(2, '0')}$rgb';
}

/// The colour [text] spells in Tiled's notation, `#rrggbb` or
/// `#aarrggbb` (the `#` optional); null for none or anything else.
@internal
Color? parseTiledColor(Object? text) {
  if (text is! String || text.isEmpty) return null;
  var hex = text.startsWith('#') ? text.substring(1) : text;
  if (hex.length == 6) hex = 'FF$hex';
  if (hex.length != 8) return null;
  final value = int.tryParse(hex, radix: 16);
  return value == null ? null : Color(value);
}

/// A number the way Tiled writes one: no `.0` on whole numbers.
@internal
String tiledNum(num value) {
  if (value is int) return '$value';
  if (value == value.roundToDouble() && value.abs() < 1e15) {
    return '${value.toInt()}';
  }
  return '$value';
}
