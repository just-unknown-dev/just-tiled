/// Writes a [TiledMap] as a TMX document the Tiled editor opens.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:just_deflate/just_deflate.dart';
import 'package:xml/xml.dart';

import '../models/models.dart';
import 'xml_common.dart';

/// How a writer stores tile data.
enum TmxDataEncoding {
  /// Comma-separated numbers, a row per line. Readable and diffable.
  csv,

  /// Little-endian ids, base64, uncompressed.
  base64,

  /// Little-endian ids, zlib-compressed, base64. Tiled's default.
  base64Zlib,

  /// Little-endian ids, gzip-compressed, base64.
  base64Gzip,
}

/// Writes TMX files.
///
/// Follows the TMX 1.10 format: `type` on tiles and objects, `class` on
/// everything else. A tileset with a [Tileset.source] is written as a
/// reference to that external file; write the file itself with
/// `TsxWriter`.
abstract final class TmxWriter {
  /// [map] as a TMX document.
  static String write(
    TiledMap map, {
    TmxDataEncoding encoding = TmxDataEncoding.csv,
    String tiledVersion = '1.10.2',
  }) {
    final b = XmlBuilder()..processing('xml', 'version="1.0" encoding="UTF-8"');
    b.element(
      'map',
      nest: () {
        b.attribute('version', tmxFormatVersion);
        b.attribute('tiledversion', tiledVersion);
        if (map.className.isNotEmpty) b.attribute('class', map.className);
        b.attribute('orientation', map.orientation.name);
        b.attribute('renderorder', map.renderOrder.tmxValue);
        b.attribute('width', '${map.width}');
        b.attribute('height', '${map.height}');
        b.attribute('tilewidth', '${map.tileWidth}');
        b.attribute('tileheight', '${map.tileHeight}');
        if (map.hexSideLength != null) {
          b.attribute('hexsidelength', '${map.hexSideLength}');
        }
        if (map.staggerAxis != null) {
          b.attribute('staggeraxis', map.staggerAxis!.name);
        }
        if (map.staggerIndex != null) {
          b.attribute('staggerindex', map.staggerIndex!.name);
        }
        if (map.parallaxOriginX != 0) {
          b.attribute('parallaxoriginx', tiledNum(map.parallaxOriginX));
        }
        if (map.parallaxOriginY != 0) {
          b.attribute('parallaxoriginy', tiledNum(map.parallaxOriginY));
        }
        if (map.backgroundColor != null) {
          b.attribute('backgroundcolor', tiledColor(map.backgroundColor!));
        }
        b.attribute('infinite', map.infinite ? '1' : '0');
        if (map.nextLayerId != null) {
          b.attribute('nextlayerid', '${map.nextLayerId}');
        }
        if (map.nextObjectId != null) {
          b.attribute('nextobjectid', '${map.nextObjectId}');
        }
        writeProperties(b, map.properties);
        for (final ts in map.tilesets) {
          if (ts.source != null) {
            b.element(
              'tileset',
              attributes: {'firstgid': '${ts.firstGid}', 'source': ts.source!},
            );
          } else {
            writeTilesetElement(b, ts, firstGid: ts.firstGid);
          }
        }
        for (final layer in map.layers) {
          _writeLayer(b, layer, encoding);
        }
      },
    );
    return prettyXml(b);
  }

  static void _common(XmlBuilder b, Layer layer) {
    b.attribute('id', '${layer.id}');
    b.attribute('name', layer.name);
    if (layer.className.isNotEmpty) b.attribute('class', layer.className);
  }

  static void _look(XmlBuilder b, Layer layer) {
    if (!layer.visible) b.attribute('visible', '0');
    if (layer.locked) b.attribute('locked', '1');
    if (layer.opacity != 1) b.attribute('opacity', tiledNum(layer.opacity));
    if (layer.tintColor != null) {
      b.attribute('tintcolor', tiledColor(layer.tintColor!));
    }
    if (layer.offsetX != 0) b.attribute('offsetx', tiledNum(layer.offsetX));
    if (layer.offsetY != 0) b.attribute('offsety', tiledNum(layer.offsetY));
    if (layer.parallaxX != 1) {
      b.attribute('parallaxx', tiledNum(layer.parallaxX));
    }
    if (layer.parallaxY != 1) {
      b.attribute('parallaxy', tiledNum(layer.parallaxY));
    }
  }

  static void _writeLayer(XmlBuilder b, Layer layer, TmxDataEncoding enc) {
    switch (layer) {
      case TileLayer():
        b.element(
          'layer',
          nest: () {
            _common(b, layer);
            b.attribute('width', '${layer.width}');
            b.attribute('height', '${layer.height}');
            _look(b, layer);
            writeProperties(b, layer.properties);
            b.element(
              'data',
              nest: () {
                _encodingAttributes(b, enc);
                if (layer.isChunked) {
                  for (final chunk in layer.chunks) {
                    b.element(
                      'chunk',
                      nest: () {
                        b.attribute('x', '${chunk.x}');
                        b.attribute('y', '${chunk.y}');
                        b.attribute('width', '${chunk.width}');
                        b.attribute('height', '${chunk.height}');
                        b.text(_encode(chunk.data, chunk.width, enc));
                      },
                    );
                  }
                } else {
                  b.text(_encode(layer.rawGids, layer.width, enc));
                }
              },
            );
          },
        );
      case ObjectGroup():
        b.element(
          'objectgroup',
          nest: () {
            _common(b, layer);
            if (layer.color != null) {
              b.attribute('color', tiledColor(layer.color!));
            }
            _look(b, layer);
            if (layer.drawOrder != DrawOrder.topDown) {
              b.attribute('draworder', layer.drawOrder.tmxValue);
            }
            writeProperties(b, layer.properties);
            for (final o in layer.objects) {
              writeObject(b, o);
            }
          },
        );
      case ImageLayer():
        b.element(
          'imagelayer',
          nest: () {
            _common(b, layer);
            _look(b, layer);
            if (layer.repeatX) b.attribute('repeatx', '1');
            if (layer.repeatY) b.attribute('repeaty', '1');
            writeProperties(b, layer.properties);
            if (layer.imageSource != null) {
              b.element(
                'image',
                nest: () {
                  b.attribute('source', layer.imageSource!);
                  if (layer.transparentColor case final key?) {
                    b.attribute(
                      'trans',
                      (key.toARGB32() & 0xFFFFFF)
                          .toRadixString(16)
                          .padLeft(6, '0'),
                    );
                  }
                  if (layer.imageWidth != null) {
                    b.attribute('width', '${layer.imageWidth}');
                  }
                  if (layer.imageHeight != null) {
                    b.attribute('height', '${layer.imageHeight}');
                  }
                },
              );
            }
          },
        );
      case GroupLayer():
        b.element(
          'group',
          nest: () {
            _common(b, layer);
            _look(b, layer);
            writeProperties(b, layer.properties);
            for (final child in layer.layers) {
              _writeLayer(b, child, enc);
            }
          },
        );
      default:
        break;
    }
  }

  static void _encodingAttributes(XmlBuilder b, TmxDataEncoding enc) {
    switch (enc) {
      case TmxDataEncoding.csv:
        b.attribute('encoding', 'csv');
      case TmxDataEncoding.base64:
        b.attribute('encoding', 'base64');
      case TmxDataEncoding.base64Zlib:
        b.attribute('encoding', 'base64');
        b.attribute('compression', 'zlib');
      case TmxDataEncoding.base64Gzip:
        b.attribute('encoding', 'base64');
        b.attribute('compression', 'gzip');
    }
  }

  /// Tile ids as the chosen encoding writes them. CSV is a row per line,
  /// every row but the last ending in a comma, framed by newlines.
  static String _encode(List<int> gids, int width, TmxDataEncoding enc) {
    if (enc == TmxDataEncoding.csv) {
      final rowWidth = width <= 0 ? gids.length : width;
      final rows = <String>[];
      for (var i = 0; i < gids.length; i += rowWidth) {
        final end = i + rowWidth > gids.length ? gids.length : i + rowWidth;
        rows.add(
          [for (var j = i; j < end; j++) gids[j].toUnsigned(32)].join(','),
        );
      }
      return '\n${rows.join(',\n')}\n';
    }
    final Uint8List bytes = TiledGid.toBytes(gids);
    final List<int> packed = switch (enc) {
      TmxDataEncoding.base64Zlib => const ZlibCodec().encode(bytes),
      TmxDataEncoding.base64Gzip => const GzipCodec().encode(bytes),
      _ => bytes,
    };
    return '\n   ${base64Encode(packed)}\n  ';
  }
}

/// Writes TSX files: one tileset, as Tiled saves an external one.
abstract final class TsxWriter {
  /// [tileset] as a TSX document. Its [Tileset.firstGid] belongs to the
  /// map that uses it and is not written.
  static String write(Tileset tileset, {String tiledVersion = '1.10.2'}) {
    final b = XmlBuilder()..processing('xml', 'version="1.0" encoding="UTF-8"');
    writeTilesetElement(
      b,
      tileset,
      version: tmxFormatVersion,
      tiledVersion: tiledVersion,
    );
    return prettyXml(b);
  }
}
