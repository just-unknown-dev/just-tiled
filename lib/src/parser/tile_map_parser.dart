/// TMX map file parser.
///
/// Parses the XML-based TMX Map Format (version 1.8 and above) into typed
/// Dart objects.
library;

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:just_deflate/just_deflate.dart';
import 'package:just_zstd/just_zstd.dart';
import 'package:xml/xml.dart';

import '../json/tmj_codec.dart';
import '../models/models.dart';
import 'tsx_provider.dart';

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
  /// [tsxProvider] is used to resolve external .tsx (or .tsj) tileset
  /// references. If null, external tilesets will have minimal data.
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

  /// Parse a standalone TSX tileset document. [firstGid] is what the map
  /// that uses it assigns; 1 when read on its own.
  static Tileset parseTileset(String tsxXml, {int firstGid = 1, String? source}) {
    final root = XmlDocument.parse(tsxXml).rootElement;
    if (root.name.local != 'tileset') {
      throw FormatException(
        'Expected root element tileset, got ${root.name.local}',
      );
    }
    return _parseTilesetData(root, firstGid, source);
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
      className: element.getAttribute('class') ?? '',
      orientation: MapOrientation.fromString(
        element.getAttribute('orientation') ?? 'orthogonal',
      ),
      renderOrder: RenderOrder.fromString(
        element.getAttribute('renderorder') ?? 'right-down',
      ),
      width: _int(element, 'width'),
      height: _int(element, 'height'),
      tileWidth: _int(element, 'tilewidth'),
      tileHeight: _int(element, 'tileheight'),
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
      hexSideLength: int.tryParse(element.getAttribute('hexsidelength') ?? ''),
      parallaxOriginX: _double(element, 'parallaxoriginx'),
      parallaxOriginY: _double(element, 'parallaxoriginy'),
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

    // External tileset reference: XML, or Tiled's JSON form.
    if (source != null && tsxProvider != null) {
      final text = await tsxProvider.getTsx(source);
      if (_isJsonPath(source)) {
        return TmjParser.parseTilesetJson(
          jsonDecode(text) as Map<String, dynamic>,
          firstGid: firstGid,
          source: source,
        );
      }
      return _parseTilesetData(
        XmlDocument.parse(text).rootElement,
        firstGid,
        source,
      );
    }

    return _parseTilesetData(element, firstGid, source);
  }

  static bool _isJsonPath(String path) {
    final p = path.toLowerCase();
    return p.endsWith('.tsj') || p.endsWith('.json');
  }

  /// Parse tileset data from either embedded or TSX element.
  static Tileset _parseTilesetData(
    XmlElement element,
    int firstGid,
    String? source,
  ) {
    Offset tileOffset = Offset.zero;
    final offsetElement = element.getElement('tileoffset');
    if (offsetElement != null) {
      tileOffset = Offset(
        _double(offsetElement, 'x'),
        _double(offsetElement, 'y'),
      );
    }

    final gridElement = element.getElement('grid');
    final transformsElement = element.getElement('transformations');
    final imageElement = element.getElement('image');

    final tiles = <int, Tile>{};
    for (final tileElement in element.findElements('tile')) {
      final tile = _parseTile(tileElement);
      tiles[tile.id] = tile;
    }

    final wangSets = <WangSet>[
      for (final setElement
          in element.getElement('wangsets')?.findElements('wangset') ??
              const <XmlElement>[])
        _parseWangSet(setElement),
    ];

    return Tileset(
      firstGid: firstGid,
      name: element.getAttribute('name') ?? '',
      className: element.getAttribute('class') ?? '',
      tileWidth: _int(element, 'tilewidth'),
      tileHeight: _int(element, 'tileheight'),
      spacing: _int(element, 'spacing'),
      margin: _int(element, 'margin'),
      tileCount: _int(element, 'tilecount'),
      columns: _int(element, 'columns'),
      tileOffset: tileOffset,
      objectAlignment: ObjectAlignment.fromString(
        element.getAttribute('objectalignment'),
      ),
      tileRenderSize: TileRenderSize.fromString(
        element.getAttribute('tilerendersize'),
      ),
      fillMode: FillMode.fromString(element.getAttribute('fillmode')),
      grid: gridElement == null
          ? null
          : TilesetGrid(
              orientation: MapOrientation.fromString(
                gridElement.getAttribute('orientation') ?? 'orthogonal',
              ),
              width: _int(gridElement, 'width'),
              height: _int(gridElement, 'height'),
            ),
      transformations: transformsElement == null
          ? const TilesetTransformations()
          : TilesetTransformations(
              hflip: transformsElement.getAttribute('hflip') == '1',
              vflip: transformsElement.getAttribute('vflip') == '1',
              rotate: transformsElement.getAttribute('rotate') == '1',
              preferUntransformed:
                  transformsElement.getAttribute('preferuntransformed') == '1',
            ),
      imageSource: imageElement?.getAttribute('source'),
      imageWidth: int.tryParse(imageElement?.getAttribute('width') ?? ''),
      imageHeight: int.tryParse(imageElement?.getAttribute('height') ?? ''),
      transparentColor: _parseColor(imageElement?.getAttribute('trans')),
      tiles: tiles,
      wangSets: wangSets,
      source: source,
      properties: _parseProperties(element),
    );
  }

  /// Parse a `wangset` element.
  static WangSet _parseWangSet(XmlElement element) {
    final colors = [
      for (final c in element.findElements('wangcolor'))
        WangColor(
          name: c.getAttribute('name') ?? '',
          className: c.getAttribute('class') ?? '',
          color: _parseColor(c.getAttribute('color')) ?? const Color(0xFFFF0000),
          tile: int.tryParse(c.getAttribute('tile') ?? '') ?? -1,
          probability: double.tryParse(c.getAttribute('probability') ?? '') ?? 1,
          properties: _parseProperties(c),
        ),
    ];
    final wangTiles = <int, List<int>>{};
    for (final t in element.findElements('wangtile')) {
      final id = int.tryParse(t.getAttribute('tileid') ?? '');
      if (id == null) continue;
      wangTiles[id] = parseWangId(t.getAttribute('wangid') ?? '');
    }
    return WangSet(
      name: element.getAttribute('name') ?? '',
      className: element.getAttribute('class') ?? '',
      type: WangSetType.fromString(element.getAttribute('type')),
      tile: int.tryParse(element.getAttribute('tile') ?? '') ?? -1,
      colors: colors,
      wangTiles: wangTiles,
      properties: _parseProperties(element),
    );
  }

  /// A Wang id: eight comma-separated colour indices. Tiled before 1.5 wrote
  /// one hex number, a nibble per slot, lowest nibble first.
  static List<int> parseWangId(String text) {
    final trimmed = text.trim();
    if (trimmed.startsWith('0x')) {
      final value = int.tryParse(trimmed.substring(2), radix: 16) ?? 0;
      return [for (var i = 0; i < 8; i++) (value >> (i * 4)) & 0xF];
    }
    final parts = trimmed.split(',');
    return [
      for (var i = 0; i < 8; i++)
        i < parts.length ? int.tryParse(parts[i].trim()) ?? 0 : 0,
    ];
  }

  /// Parse a `tile` element within a tileset.
  static Tile _parseTile(XmlElement element) {
    final objectGroupElement = element.getElement('objectgroup');
    final collisionObjects = <TiledObject>[];
    if (objectGroupElement != null) {
      for (final objElement in objectGroupElement.findElements('object')) {
        collisionObjects.add(_parseObject(objElement));
      }
    }

    final animElement = element.getElement('animation');
    final animation = <AnimationFrame>[];
    if (animElement != null) {
      for (final frameElement in animElement.findElements('frame')) {
        animation.add(
          AnimationFrame(
            tileId: int.parse(frameElement.getAttribute('tileid') ?? '0'),
            duration: int.parse(frameElement.getAttribute('duration') ?? '100'),
          ),
        );
      }
    }

    return Tile(
      id: int.parse(element.getAttribute('id') ?? '0'),
      type: element.getAttribute('type') ?? element.getAttribute('class'),
      probability: double.parse(element.getAttribute('probability') ?? '1.0'),
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
    final width = _int(element, 'width');
    final height = _int(element, 'height');

    final dataElement = element.getElement('data');
    var raw = Uint32List(0);
    final chunks = <TileChunk>[];
    var encoding = LayerEncoding.xml;
    var compression = LayerCompression.none;

    if (dataElement != null) {
      encoding = LayerEncoding.fromString(dataElement.getAttribute('encoding'));
      compression = LayerCompression.fromString(
        dataElement.getAttribute('compression'),
      );
      final chunkElements = dataElement.findElements('chunk').toList();
      if (chunkElements.isNotEmpty) {
        // An infinite map: each chunk is a rectangle encoded on its own.
        // Reading the data element's whole text as one list, as this parser
        // once did, ran every chunk together into nonsense.
        for (final chunk in chunkElements) {
          chunks.add(
            TileChunk(
              x: _int(chunk, 'x'),
              y: _int(chunk, 'y'),
              width: _int(chunk, 'width'),
              height: _int(chunk, 'height'),
              data: _decodeData(
                chunk,
                encoding,
                compression,
                _int(chunk, 'width') * _int(chunk, 'height'),
              ),
            ),
          );
        }
      } else {
        raw = _decodeData(dataElement, encoding, compression, width * height);
      }
    }

    // Flags split out for the older fields; [rawData] keeps them whole,
    // hexagonal rotation included.
    final data = <int>[];
    final flipH = <bool>[];
    final flipV = <bool>[];
    final flipD = <bool>[];
    for (final gid in raw) {
      flipH.add(TiledGid.isFlippedHorizontally(gid));
      flipV.add(TiledGid.isFlippedVertically(gid));
      flipD.add(TiledGid.isFlippedDiagonally(gid));
      data.add(TiledGid.idOf(gid));
    }

    return TileLayer(
      id: _int(element, 'id'),
      name: element.getAttribute('name') ?? '',
      className: element.getAttribute('class') ?? '',
      visible: element.getAttribute('visible') != '0',
      locked: element.getAttribute('locked') == '1',
      opacity: _double(element, 'opacity', 1),
      offsetX: _double(element, 'offsetx'),
      offsetY: _double(element, 'offsety'),
      tintColor: _parseColor(element.getAttribute('tintcolor')),
      parallaxX: _double(element, 'parallaxx', 1),
      parallaxY: _double(element, 'parallaxy', 1),
      properties: _parseProperties(element),
      width: width,
      height: height,
      data: data,
      flipHorizontal: flipH,
      flipVertical: flipV,
      flipDiagonal: flipD,
      rawData: chunks.isEmpty ? raw : null,
      chunks: chunks,
      encoding: encoding,
      compression: compression,
    );
  }

  /// Decode the tiles of a `data` or `chunk` element of [cells] tiles: raw
  /// ids, flags kept.
  static Uint32List _decodeData(
    XmlElement element,
    LayerEncoding encoding,
    LayerCompression compression,
    int cells,
  ) {
    switch (encoding) {
      case LayerEncoding.csv:
        return _decodeCsv(element.innerText);
      case LayerEncoding.base64:
        return _decodeBase64(element.innerText.trim(), compression, cells);
      case LayerEncoding.xml:
        return _decodeXmlTiles(element);
    }
  }

  /// Decode CSV-encoded tile data.
  static Uint32List _decodeCsv(String csvText) => Uint32List.fromList([
    for (final s in csvText.split(','))
      if (s.trim().isNotEmpty) int.parse(s.trim()).toUnsigned(32),
  ]);

  /// Decode base64-encoded tile data with optional compression.
  ///
  /// [cells] is how many tiles the data holds, so zlib or gzip data can't
  /// unpack to more than their bytes: damaged or hostile data fails rather
  /// than filling memory. 0 (no size given) sets no limit.
  static Uint32List _decodeBase64(
    String base64Text,
    LayerCompression compression,
    int cells,
  ) {
    final bytes = base64Decode(base64Text);
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
    return TiledGid.fromBytes(plain);
  }

  /// Decode XML `tile` elements (unencoded format).
  static Uint32List _decodeXmlTiles(XmlElement element) => Uint32List.fromList([
    for (final e in element.findElements('tile'))
      int.parse(e.getAttribute('gid') ?? '0').toUnsigned(32),
  ]);

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
      id: _int(element, 'id'),
      name: element.getAttribute('name') ?? '',
      className: element.getAttribute('class') ?? '',
      visible: element.getAttribute('visible') != '0',
      locked: element.getAttribute('locked') == '1',
      opacity: _double(element, 'opacity', 1),
      offsetX: _double(element, 'offsetx'),
      offsetY: _double(element, 'offsety'),
      tintColor: _parseColor(element.getAttribute('tintcolor')),
      parallaxX: _double(element, 'parallaxx', 1),
      parallaxY: _double(element, 'parallaxy', 1),
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
      } catch (e, st) {
        // Template load failed; degrade gracefully to the inline object.
        assert(() {
          // ignore: avoid_print
          print('just_tiled: failed to load template "$templatePath": $e\n$st');
          return true;
        }());
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
      type:
          instance.getAttribute('type') ??
          instance.getAttribute('class') ??
          template.getAttribute('type') ??
          template.getAttribute('class') ??
          '',
      x: double.parse(attr('x', '0')),
      y: double.parse(attr('y', '0')),
      width: double.parse(attr('width', '0')),
      height: double.parse(attr('height', '0')),
      rotation: double.parse(attr('rotation', '0')),
      gid: _gid(attr('gid')),
      visible: attr('visible', '1') != '0',
      templatePath: templatePath,
      polygon: _parsePolygon(instance) ?? _parsePolygon(template),
      polyline: _parsePolyline(instance) ?? _parsePolyline(template),
      isEllipse:
          instance.getElement('ellipse') != null ||
          template.getElement('ellipse') != null,
      isPoint:
          instance.getElement('point') != null ||
          template.getElement('point') != null,
      text:
          instance.getElement('text')?.innerText ??
          template.getElement('text')?.innerText,
      properties: _mergeProperties(
        _parseProperties(template),
        _parseProperties(instance),
      ),
    );
  }

  /// A tile object's raw gid, flags kept, as an unsigned value.
  static int? _gid(String? text) =>
      text == null || text.isEmpty ? null : int.tryParse(text)?.toUnsigned(32);

  /// Parse an `object` element into a [TiledObject].
  static TiledObject _parseObject(XmlElement element) {
    return TiledObject(
      id: _int(element, 'id'),
      name: element.getAttribute('name') ?? '',
      type: element.getAttribute('type') ?? element.getAttribute('class') ?? '',
      x: _double(element, 'x'),
      y: _double(element, 'y'),
      width: _double(element, 'width'),
      height: _double(element, 'height'),
      rotation: _double(element, 'rotation'),
      gid: _gid(element.getAttribute('gid')),
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
      id: _int(element, 'id'),
      name: element.getAttribute('name') ?? '',
      className: element.getAttribute('class') ?? '',
      visible: element.getAttribute('visible') != '0',
      locked: element.getAttribute('locked') == '1',
      opacity: _double(element, 'opacity', 1),
      offsetX: _double(element, 'offsetx'),
      offsetY: _double(element, 'offsety'),
      tintColor: _parseColor(element.getAttribute('tintcolor')),
      parallaxX: _double(element, 'parallaxx', 1),
      parallaxY: _double(element, 'parallaxy', 1),
      properties: _parseProperties(element),
      imageSource: imageElement?.getAttribute('source'),
      transparentColor: _parseColor(imageElement?.getAttribute('trans')),
      imageWidth: int.tryParse(imageElement?.getAttribute('width') ?? ''),
      imageHeight: int.tryParse(imageElement?.getAttribute('height') ?? ''),
      repeatX: element.getAttribute('repeatx') == '1',
      repeatY: element.getAttribute('repeaty') == '1',
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
      id: _int(element, 'id'),
      name: element.getAttribute('name') ?? '',
      className: element.getAttribute('class') ?? '',
      visible: element.getAttribute('visible') != '0',
      locked: element.getAttribute('locked') == '1',
      opacity: _double(element, 'opacity', 1),
      offsetX: _double(element, 'offsetx'),
      offsetY: _double(element, 'offsety'),
      tintColor: _parseColor(element.getAttribute('tintcolor')),
      parallaxX: _double(element, 'parallaxx', 1),
      parallaxY: _double(element, 'parallaxy', 1),
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
    return pointsStr.split(' ').where((p) => p.isNotEmpty).map((pair) {
      final parts = pair.split(',');
      return Offset(
        double.tryParse(parts[0]) ?? 0.0,
        parts.length > 1 ? (double.tryParse(parts[1]) ?? 0.0) : 0.0,
      );
    }).toList();
  }

  /// Parse `properties` element, keeping each property's declared type.
  static TiledProperties _parseProperties(XmlElement element) {
    final propsElement = element.getElement('properties');
    if (propsElement == null) return const TiledProperties();

    final map = <String, dynamic>{};
    final types = <String, String>{};
    for (final prop in propsElement.findElements('property')) {
      final name = prop.getAttribute('name') ?? '';
      final type = prop.getAttribute('type') ?? 'string';
      final value = prop.getAttribute('value') ?? prop.innerText;
      types[name] = type;

      switch (type) {
        case 'int':
        case 'object':
          map[name] = int.tryParse(value) ?? 0;
        case 'float':
          map[name] = double.tryParse(value) ?? 0.0;
        case 'bool':
          map[name] = value.toLowerCase() == 'true';
        case 'color':
          map[name] = _parseColor(value);
        case 'file':
        case 'string':
        default:
          map[name] = value;
      }
    }

    return TiledProperties(map, types);
  }

  /// Merge two property sets (instance overrides template).
  static TiledProperties _mergeProperties(
    TiledProperties template,
    TiledProperties instance,
  ) {
    final merged = <String, dynamic>{...template.toMap()};
    final types = <String, String>{
      for (final key in template.keys) key: template.typeOf(key),
    };
    for (final key in instance.keys) {
      merged[key] = instance[key];
      types[key] = instance.typeOf(key);
    }
    return TiledProperties(merged, types);
  }

  static int _int(XmlElement element, String name, [int fallback = 0]) =>
      int.tryParse(element.getAttribute(name) ?? '') ?? fallback;

  static double _double(
    XmlElement element,
    String name, [
    double fallback = 0,
  ]) => double.tryParse(element.getAttribute(name) ?? '') ?? fallback;

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
