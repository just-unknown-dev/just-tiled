/// TMX map file parser.
///
/// Parses the XML-based TMX Map Format (version 1.8 and above) into typed
/// Dart objects.
library;

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:archive/archive.dart';
import 'package:just_zstd/just_zstd.dart';
import 'package:xml/xml.dart';

import '../models/models.dart';
import 'tsx_provider.dart';

/// GID flip flag bitmasks (top 3 bits of 32-bit unsigned integer).
const int _flipHorizontalFlag = 0x80000000;
const int _flipVerticalFlag = 0x40000000;
const int _flipDiagonalFlag = 0x20000000;
const int _gidMask = 0x1FFFFFFF;

/// Parser for Tiled Map Editor TMX files.
///
/// Usage:
/// ```dart
/// final tmxXml = await rootBundle.loadString('assets/maps/level1.tmx');
/// final map = await TileMapParser.parse(tmxXml);
/// ```
class TileMapParser {
  const TileMapParser._();

  /// Parse a TMX XML string into a [TiledMap].
  ///
  /// [tmxXml] is the raw XML content of the .tmx file.
  /// [tsxProvider] is used to resolve external .tsx tileset references.
  /// If null, external tilesets will have minimal data.
  static Future<TiledMap> parse(
    String tmxXml, {
    TsxProvider? tsxProvider,
  }) async {
    final document = XmlDocument.parse(tmxXml);
    final mapElement = document.rootElement;

    if (mapElement.name.local != 'map') {
      throw FormatException(
        'Expected root element map, got ${mapElement.name.local}',
      );
    }

    return _parseMap(mapElement, tsxProvider);
  }

  /// Parse the root `map` element.
  static Future<TiledMap> _parseMap(
    XmlElement element,
    TsxProvider? tsxProvider,
  ) async {
    final tilesets = <Tileset>[];
    for (final tsElement in element.findElements('tileset')) {
      tilesets.add(await _parseTileset(tsElement, tsxProvider));
    }

    final layers = <Layer>[];
    for (final child in element.childElements) {
      final layer = await _parseLayerElement(child, tsxProvider);
      if (layer != null) layers.add(layer);
    }

    return TiledMap(
      version: element.getAttribute('version') ?? '1.0',
      tiledVersion: element.getAttribute('tiledversion'),
      orientation: MapOrientation.fromString(
        element.getAttribute('orientation') ?? 'orthogonal',
      ),
      renderOrder: RenderOrder.fromString(
        element.getAttribute('renderorder') ?? 'right-down',
      ),
      width: int.parse(element.getAttribute('width') ?? '0'),
      height: int.parse(element.getAttribute('height') ?? '0'),
      tileWidth: int.parse(element.getAttribute('tilewidth') ?? '0'),
      tileHeight: int.parse(element.getAttribute('tileheight') ?? '0'),
      infinite: element.getAttribute('infinite') == '1',
      backgroundColor: _parseColor(element.getAttribute('backgroundcolor')),
      nextLayerId: int.tryParse(element.getAttribute('nextlayerid') ?? ''),
      nextObjectId: int.tryParse(element.getAttribute('nextobjectid') ?? ''),
      staggerAxis: element.getAttribute('staggeraxis') != null
          ? StaggerAxis.fromString(element.getAttribute('staggeraxis')!)
          : null,
      staggerIndex: element.getAttribute('staggerindex') != null
          ? StaggerIndex.fromString(element.getAttribute('staggerindex')!)
          : null,
      hexSideLength: int.tryParse(
        element.getAttribute('hexsidelength') ?? '',
      ),
      tilesets: tilesets,
      layers: layers,
      properties: _parseProperties(element),
    );
  }

  /// Parse a `tileset` element (embedded or external reference).
  static Future<Tileset> _parseTileset(
    XmlElement element,
    TsxProvider? tsxProvider,
  ) async {
    final firstGid = int.parse(element.getAttribute('firstgid') ?? '1');
    final source = element.getAttribute('source');

    // External tileset reference
    if (source != null && tsxProvider != null) {
      final tsxXml = await tsxProvider.getTsx(source);
      final tsxDoc = XmlDocument.parse(tsxXml);
      final tsxRoot = tsxDoc.rootElement;
      return _parseTilesetData(tsxRoot, firstGid, source);
    }

    return _parseTilesetData(element, firstGid, source);
  }

  /// Parse tileset data from either embedded or TSX element.
  static Tileset _parseTilesetData(
    XmlElement element,
    int firstGid,
    String? source,
  ) {
    // Parse tile offset
    Offset tileOffset = Offset.zero;
    final offsetElement = element.getElement('tileoffset');
    if (offsetElement != null) {
      tileOffset = Offset(
        double.parse(offsetElement.getAttribute('x') ?? '0'),
        double.parse(offsetElement.getAttribute('y') ?? '0'),
      );
    }

    // Parse image
    final imageElement = element.getElement('image');

    // Parse per-tile data
    final tiles = <int, Tile>{};
    for (final tileElement in element.findElements('tile')) {
      final tile = _parseTile(tileElement);
      tiles[tile.id] = tile;
    }

    return Tileset(
      firstGid: firstGid,
      name: element.getAttribute('name') ?? '',
      tileWidth: int.parse(element.getAttribute('tilewidth') ?? '0'),
      tileHeight: int.parse(element.getAttribute('tileheight') ?? '0'),
      spacing: int.parse(element.getAttribute('spacing') ?? '0'),
      margin: int.parse(element.getAttribute('margin') ?? '0'),
      tileCount: int.parse(element.getAttribute('tilecount') ?? '0'),
      columns: int.parse(element.getAttribute('columns') ?? '0'),
      tileOffset: tileOffset,
      imageSource: imageElement?.getAttribute('source'),
      imageWidth: int.tryParse(imageElement?.getAttribute('width') ?? ''),
      imageHeight: int.tryParse(imageElement?.getAttribute('height') ?? ''),
      transparentColor: _parseColor(
        imageElement?.getAttribute('trans'),
      ),
      tiles: tiles,
      source: source,
      properties: _parseProperties(element),
    );
  }

  /// Parse a `tile` element within a tileset.
  static Tile _parseTile(XmlElement element) {
    // Parse collision object group
    final objectGroupElement = element.getElement('objectgroup');
    final collisionObjects = <TiledObject>[];
    if (objectGroupElement != null) {
      for (final objElement in objectGroupElement.findElements('object')) {
        collisionObjects.add(_parseObject(objElement));
      }
    }

    // Parse animation
    final animElement = element.getElement('animation');
    final animation = <AnimationFrame>[];
    if (animElement != null) {
      for (final frameElement in animElement.findElements('frame')) {
        animation.add(AnimationFrame(
          tileId: int.parse(frameElement.getAttribute('tileid') ?? '0'),
          duration: int.parse(frameElement.getAttribute('duration') ?? '100'),
        ));
      }
    }

    return Tile(
      id: int.parse(element.getAttribute('id') ?? '0'),
      type: element.getAttribute('type') ?? element.getAttribute('class'),
      probability: double.parse(
        element.getAttribute('probability') ?? '1.0',
      ),
      imageSource: element.getElement('image')?.getAttribute('source'),
      imageWidth: int.tryParse(
        element.getElement('image')?.getAttribute('width') ?? '',
      ),
      imageHeight: int.tryParse(
        element.getElement('image')?.getAttribute('height') ?? '',
      ),
      objectGroup: collisionObjects,
      animation: animation,
      properties: _parseProperties(element),
    );
  }

  /// Parse a layer-type child element.
  static Future<Layer?> _parseLayerElement(
    XmlElement element,
    TsxProvider? tsxProvider,
  ) async {
    switch (element.name.local) {
      case 'layer':
        return _parseTileLayer(element);
      case 'objectgroup':
        return _parseObjectGroup(element, tsxProvider);
      case 'imagelayer':
        return _parseImageLayer(element);
      case 'group':
        return _parseGroupLayer(element, tsxProvider);
      default:
        return null;
    }
  }

  /// Parse a `layer` (tile layer) element.
  static TileLayer _parseTileLayer(XmlElement element) {
    final width = int.parse(element.getAttribute('width') ?? '0');
    final height = int.parse(element.getAttribute('height') ?? '0');

    final dataElement = element.getElement('data');
    List<int> rawGids = [];
    LayerEncoding encoding = LayerEncoding.xml;
    LayerCompression compression = LayerCompression.none;

    if (dataElement != null) {
      encoding = LayerEncoding.fromString(
        dataElement.getAttribute('encoding'),
      );
      compression = LayerCompression.fromString(
        dataElement.getAttribute('compression'),
      );
      rawGids = _decodeData(dataElement, encoding, compression);
    }

    // Extract flip flags and clean GIDs
    final data = <int>[];
    final flipH = <bool>[];
    final flipV = <bool>[];
    final flipD = <bool>[];

    for (final gid in rawGids) {
      flipH.add((gid & _flipHorizontalFlag) != 0);
      flipV.add((gid & _flipVerticalFlag) != 0);
      flipD.add((gid & _flipDiagonalFlag) != 0);
      data.add(gid & _gidMask);
    }

    return TileLayer(
      id: int.parse(element.getAttribute('id') ?? '0'),
      name: element.getAttribute('name') ?? '',
      visible: element.getAttribute('visible') != '0',
      opacity: double.parse(element.getAttribute('opacity') ?? '1.0'),
      offsetX: double.parse(element.getAttribute('offsetx') ?? '0'),
      offsetY: double.parse(element.getAttribute('offsety') ?? '0'),
      tintColor: _parseColor(element.getAttribute('tintcolor')),
      parallelX: double.parse(element.getAttribute('parallaxx') ?? '1.0'),
      parallelY: double.parse(element.getAttribute('parallaxy') ?? '1.0'),
      properties: _parseProperties(element),
      width: width,
      height: height,
      data: data,
      flipHorizontal: flipH,
      flipVertical: flipV,
      flipDiagonal: flipD,
      encoding: encoding,
      compression: compression,
    );
  }

  /// Decode the `data` element content.
  static List<int> _decodeData(
    XmlElement dataElement,
    LayerEncoding encoding,
    LayerCompression compression,
  ) {
    switch (encoding) {
      case LayerEncoding.csv:
        return _decodeCsv(dataElement.innerText);

      case LayerEncoding.base64:
        return _decodeBase64(dataElement.innerText.trim(), compression);

      case LayerEncoding.xml:
        return _decodeXmlTiles(dataElement);
    }
  }

  /// Decode CSV-encoded tile data.
  static List<int> _decodeCsv(String csvText) {
    return csvText
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .map((s) => int.parse(s))
        .toList();
  }

  /// Decode base64-encoded tile data with optional compression.
  static List<int> _decodeBase64(
    String base64Text,
    LayerCompression compression,
  ) {
    final bytes = base64Decode(base64Text);

    Uint8List decompressed;
    switch (compression) {
      case LayerCompression.none:
        decompressed = bytes;
        break;

      case LayerCompression.gzip:
        decompressed = Uint8List.fromList(
          GZipDecoder().decodeBytes(bytes),
        );
        break;

      case LayerCompression.zlib:
        decompressed = Uint8List.fromList(
          ZLibDecoder().decodeBytes(bytes),
        );
        break;

      case LayerCompression.zstd:
        decompressed = const ZstdDecoder().decodeBytes(bytes);
        break;
    }

    // Convert bytes to 32-bit unsigned integers (little-endian)
    return _bytesToGids(decompressed);
  }

  /// Decode XML `tile` elements (unencoded format).
  static List<int> _decodeXmlTiles(XmlElement dataElement) {
    return dataElement
        .findElements('tile')
        .map((e) => int.parse(e.getAttribute('gid') ?? '0'))
        .toList();
  }

  /// Convert byte buffer to list of 32-bit unsigned GIDs (little-endian).
  static List<int> _bytesToGids(Uint8List bytes) {
    final gids = <int>[];
    for (int i = 0; i + 3 < bytes.length; i += 4) {
      final gid = bytes[i] |
          (bytes[i + 1] << 8) |
          (bytes[i + 2] << 16) |
          (bytes[i + 3] << 24);
      gids.add(gid & 0xFFFFFFFF);
    }
    return gids;
  }

  /// Parse an `objectgroup` element.
  static Future<ObjectGroup> _parseObjectGroup(
    XmlElement element,
    TsxProvider? tsxProvider,
  ) async {
    final objects = <TiledObject>[];
    for (final objElement in element.findElements('object')) {
      objects.add(await _parseObjectWithTemplate(objElement, tsxProvider));
    }

    return ObjectGroup(
      id: int.parse(element.getAttribute('id') ?? '0'),
      name: element.getAttribute('name') ?? '',
      visible: element.getAttribute('visible') != '0',
      opacity: double.parse(element.getAttribute('opacity') ?? '1.0'),
      offsetX: double.parse(element.getAttribute('offsetx') ?? '0'),
      offsetY: double.parse(element.getAttribute('offsety') ?? '0'),
      tintColor: _parseColor(element.getAttribute('tintcolor')),
      parallelX: double.parse(element.getAttribute('parallaxx') ?? '1.0'),
      parallelY: double.parse(element.getAttribute('parallaxy') ?? '1.0'),
      properties: _parseProperties(element),
      drawOrder: DrawOrder.fromString(
        element.getAttribute('draworder') ?? 'topdown',
      ),
      color: _parseColor(element.getAttribute('color')),
      objects: objects,
    );
  }

  /// Parse an `object` element, resolving templates if needed.
  static Future<TiledObject> _parseObjectWithTemplate(
    XmlElement element,
    TsxProvider? tsxProvider,
  ) async {
    final templatePath = element.getAttribute('template');
    if (templatePath != null && tsxProvider != null) {
      try {
        final templateXml = await tsxProvider.getTemplate(templatePath);
        final templateDoc = XmlDocument.parse(templateXml);
        final templateRoot = templateDoc.rootElement;
        final templateObjectElement = templateRoot.getElement('object');
        if (templateObjectElement != null) {
          // Merge template with instance — instance attributes override
          return _mergeTemplateObject(
            templateObjectElement,
            element,
            templatePath,
          );
        }
      } catch (_) {
        // Fall through to parse without template
      }
    }
    return _parseObject(element);
  }

  /// Merge a template object with an instance override.
  static TiledObject _mergeTemplateObject(
    XmlElement template,
    XmlElement instance,
    String templatePath,
  ) {
    // Instance attributes override template attributes
    String attr(String name, [String defaultValue = '']) {
      return instance.getAttribute(name) ??
          template.getAttribute(name) ??
          defaultValue;
    }

    return TiledObject(
      id: int.parse(attr('id', '0')),
      name: attr('name'),
      type: attr('type', instance.getAttribute('class') ?? ''),
      x: double.parse(attr('x', '0')),
      y: double.parse(attr('y', '0')),
      width: double.parse(attr('width', '0')),
      height: double.parse(attr('height', '0')),
      rotation: double.parse(attr('rotation', '0')),
      gid: int.tryParse(attr('gid')),
      visible: attr('visible', '1') != '0',
      templatePath: templatePath,
      polygon: _parsePolygon(instance) ?? _parsePolygon(template),
      polyline: _parsePolyline(instance) ?? _parsePolyline(template),
      isEllipse: instance.getElement('ellipse') != null ||
          template.getElement('ellipse') != null,
      isPoint: instance.getElement('point') != null ||
          template.getElement('point') != null,
      text: instance.getElement('text')?.innerText ??
          template.getElement('text')?.innerText,
      properties: _mergeProperties(
        _parseProperties(template),
        _parseProperties(instance),
      ),
    );
  }

  /// Parse an `object` element into a [TiledObject].
  static TiledObject _parseObject(XmlElement element) {
    return TiledObject(
      id: int.parse(element.getAttribute('id') ?? '0'),
      name: element.getAttribute('name') ?? '',
      type: element.getAttribute('type') ??
          element.getAttribute('class') ??
          '',
      x: double.parse(element.getAttribute('x') ?? '0'),
      y: double.parse(element.getAttribute('y') ?? '0'),
      width: double.parse(element.getAttribute('width') ?? '0'),
      height: double.parse(element.getAttribute('height') ?? '0'),
      rotation: double.parse(element.getAttribute('rotation') ?? '0'),
      gid: int.tryParse(element.getAttribute('gid') ?? ''),
      visible: element.getAttribute('visible') != '0',
      templatePath: element.getAttribute('template'),
      polygon: _parsePolygon(element),
      polyline: _parsePolyline(element),
      isEllipse: element.getElement('ellipse') != null,
      isPoint: element.getElement('point') != null,
      text: element.getElement('text')?.innerText,
      properties: _parseProperties(element),
    );
  }

  /// Parse an `imagelayer` element.
  static ImageLayer _parseImageLayer(XmlElement element) {
    final imageElement = element.getElement('image');
    return ImageLayer(
      id: int.parse(element.getAttribute('id') ?? '0'),
      name: element.getAttribute('name') ?? '',
      visible: element.getAttribute('visible') != '0',
      opacity: double.parse(element.getAttribute('opacity') ?? '1.0'),
      offsetX: double.parse(element.getAttribute('offsetx') ?? '0'),
      offsetY: double.parse(element.getAttribute('offsety') ?? '0'),
      tintColor: _parseColor(element.getAttribute('tintcolor')),
      parallelX: double.parse(element.getAttribute('parallaxx') ?? '1.0'),
      parallelY: double.parse(element.getAttribute('parallaxy') ?? '1.0'),
      properties: _parseProperties(element),
      imageSource: imageElement?.getAttribute('source'),
      transparentColor: _parseColor(
        imageElement?.getAttribute('trans'),
      ),
    );
  }

  /// Parse a `group` element.
  static Future<GroupLayer> _parseGroupLayer(
    XmlElement element,
    TsxProvider? tsxProvider,
  ) async {
    final layers = <Layer>[];
    for (final child in element.childElements) {
      final layer = await _parseLayerElement(child, tsxProvider);
      if (layer != null) layers.add(layer);
    }

    return GroupLayer(
      id: int.parse(element.getAttribute('id') ?? '0'),
      name: element.getAttribute('name') ?? '',
      visible: element.getAttribute('visible') != '0',
      opacity: double.parse(element.getAttribute('opacity') ?? '1.0'),
      offsetX: double.parse(element.getAttribute('offsetx') ?? '0'),
      offsetY: double.parse(element.getAttribute('offsety') ?? '0'),
      tintColor: _parseColor(element.getAttribute('tintcolor')),
      parallelX: double.parse(element.getAttribute('parallaxx') ?? '1.0'),
      parallelY: double.parse(element.getAttribute('parallaxy') ?? '1.0'),
      properties: _parseProperties(element),
      layers: layers,
    );
  }

  /// Parse `polygon` points attribute.
  static List<Offset>? _parsePolygon(XmlElement element) {
    final polygonElement = element.getElement('polygon');
    if (polygonElement == null) return null;
    return _parsePointsString(polygonElement.getAttribute('points') ?? '');
  }

  /// Parse `polyline` points attribute.
  static List<Offset>? _parsePolyline(XmlElement element) {
    final polylineElement = element.getElement('polyline');
    if (polylineElement == null) return null;
    return _parsePointsString(polylineElement.getAttribute('points') ?? '');
  }

  /// Parse a Tiled points string (e.g., "0,0 32,0 32,32").
  static List<Offset> _parsePointsString(String pointsStr) {
    if (pointsStr.isEmpty) return [];
    return pointsStr.split(' ').map((pair) {
      final parts = pair.split(',');
      return Offset(
        double.parse(parts[0]),
        double.parse(parts.length > 1 ? parts[1] : '0'),
      );
    }).toList();
  }

  /// Parse `properties` element.
  static TiledProperties _parseProperties(XmlElement element) {
    final propsElement = element.getElement('properties');
    if (propsElement == null) return const TiledProperties();

    final map = <String, dynamic>{};
    for (final prop in propsElement.findElements('property')) {
      final name = prop.getAttribute('name') ?? '';
      final type = prop.getAttribute('type') ?? 'string';
      final value = prop.getAttribute('value') ?? prop.innerText;

      switch (type) {
        case 'int':
          map[name] = int.tryParse(value) ?? 0;
          break;
        case 'float':
          map[name] = double.tryParse(value) ?? 0.0;
          break;
        case 'bool':
          map[name] = value.toLowerCase() == 'true';
          break;
        case 'color':
          map[name] = _parseColor(value);
          break;
        case 'file':
        case 'string':
        default:
          map[name] = value;
          break;
      }
    }

    return TiledProperties(map);
  }

  /// Merge two property sets (instance overrides template).
  static TiledProperties _mergeProperties(
    TiledProperties template,
    TiledProperties instance,
  ) {
    final merged = <String, dynamic>{...template.toMap()};
    for (final key in instance.keys) {
      merged[key] = instance[key];
    }
    return TiledProperties(merged);
  }

  /// Parse a Tiled color string (#AARRGGBB or #RRGGBB).
  static Color? _parseColor(String? colorStr) {
    if (colorStr == null || colorStr.isEmpty) return null;

    String hex = colorStr;
    if (hex.startsWith('#')) hex = hex.substring(1);

    // #RRGGBB → #FFRRGGBB
    if (hex.length == 6) hex = 'FF$hex';
    // #AARRGGBB
    if (hex.length == 8) {
      final value = int.tryParse(hex, radix: 16);
      if (value != null) return Color(value);
    }

    return null;
  }
}
