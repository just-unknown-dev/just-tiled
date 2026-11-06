/// TMX map file parser.
///
/// Parses the XML-based TMX Map Format (version 1.8 and above) into typed
/// Dart objects.
library;

import 'dart:typed_data';
import 'dart:ui';

import 'package:meta/meta.dart';
import 'package:xml/xml.dart';

import '../../files/tile_data.dart';
import '../../files/tiled_file_provider.dart';
import '../../files/tiled_notation.dart';
import '../../files/tiled_paths.dart';
import '../../models/models.dart';
import '../object_templates.dart';
import '../tmj/tmj_parser.dart';

/// Reads TMX maps, TSX tilesets and TX templates.
///
/// Usage:
/// ```dart
/// final tmxXml = await rootBundle.loadString('assets/maps/level1.tmx');
/// final map = await TmxParser.parse(tmxXml);
/// ```
///
/// A document that isn't a valid map or tileset throws a
/// [FormatException], as does tile data that doesn't hold exactly its
/// layer's or chunk's tiles.
abstract final class TmxParser {
  /// Parse a TMX XML string into a [TiledMap].
  ///
  /// [tmxXml] is the raw XML content of the .tmx file. [fileProvider] loads
  /// the external tilesets (TSX or TSJ) and object templates (TX or TJ) the
  /// map names. Without one, an external tileset has only its first gid
  /// and source, and a templated object only its own values.
  static Future<TiledMap> parse(
    String tmxXml, {
    TiledFileProvider? fileProvider,
  }) async {
    final document = XmlDocument.parse(tmxXml);
    final mapElement = document.rootElement;

    if (mapElement.name.local != 'map') {
      throw FormatException(
        'Expected root element map, got ${mapElement.name.local}',
      );
    }

    return _parseMap(mapElement, fileProvider);
  }

  /// Parse a standalone TSX tileset document. [firstGid] is what the map
  /// that uses it assigns; 1 when read on its own.
  static Tileset parseTileset(
    String tsxXml, {
    int firstGid = 1,
    String? source,
  }) {
    final root = XmlDocument.parse(tsxXml).rootElement;
    if (root.name.local != 'tileset') {
      throw FormatException(
        'Expected root element tileset, got ${root.name.local}',
      );
    }
    return _parseTilesetData(root, firstGid, source);
  }

  /// Parse a TX template document: its object, and the external tileset
  /// its tile is numbered from.
  @internal
  static TemplateFile parseTemplate(String txXml) {
    final root = XmlDocument.parse(txXml).rootElement;
    final object = root.getElement('object');
    if (root.name.local != 'template' || object == null) {
      throw const FormatException('Not a TX template');
    }
    final tileset = root.getElement('tileset');
    return TemplateFile(
      _parseObject(object),
      tilesetSource: tileset?.getAttribute('source'),
      tilesetFirstGid: _int(tileset, 'firstgid', 1),
    );
  }

  /// Parse the root `map` element.
  static Future<TiledMap> _parseMap(
    XmlElement element,
    TiledFileProvider? fileProvider,
  ) async {
    final tilesets = <Tileset>[];
    for (final tsElement in element.findElements('tileset')) {
      tilesets.add(await _parseTileset(tsElement, fileProvider));
    }

    final infinite = element.getAttribute('infinite') == '1';
    final templates = TemplateLoader(fileProvider, tilesets);
    final layers = <Layer>[];
    for (final child in element.childElements) {
      final layer = await _parseLayerElement(child, infinite, templates);
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
      infinite: infinite,
      backgroundColor: parseTiledColor(element.getAttribute('backgroundcolor')),
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
    TiledFileProvider? fileProvider,
  ) async {
    final firstGid = int.parse(element.getAttribute('firstgid') ?? '1');
    final source = element.getAttribute('source');

    // External tileset reference: XML, or Tiled's JSON form.
    if (source != null && fileProvider != null) {
      final text = await fileProvider.loadTileset(source);
      if (isJsonFile(source)) {
        return TmjParser.parseTileset(text, firstGid: firstGid, source: source);
      }
      return _parseTilesetData(
        XmlDocument.parse(text).rootElement,
        firstGid,
        source,
      );
    }

    return _parseTilesetData(element, firstGid, source);
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
      transparentColor: parseTiledColor(imageElement?.getAttribute('trans')),
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
          color:
              parseTiledColor(c.getAttribute('color')) ??
              const Color(0xFFFF0000),
          tile: int.tryParse(c.getAttribute('tile') ?? '') ?? -1,
          probability:
              double.tryParse(c.getAttribute('probability') ?? '') ?? 1,
          properties: _parseProperties(c),
        ),
    ];
    final wangTiles = <int, List<int>>{};
    for (final t in element.findElements('wangtile')) {
      final id = int.tryParse(t.getAttribute('tileid') ?? '');
      if (id == null) continue;
      wangTiles[id] = _parseWangId(t.getAttribute('wangid') ?? '');
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
  static List<int> _parseWangId(String text) {
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

  /// Parse a layer-type child element of a map in which [infinite] says
  /// whether tile layers hold chunks.
  static Future<Layer?> _parseLayerElement(
    XmlElement element,
    bool infinite,
    TemplateLoader templates,
  ) async {
    switch (element.name.local) {
      case 'layer':
        return _parseTileLayer(element, infinite);
      case 'objectgroup':
        return _parseObjectGroup(element, templates);
      case 'imagelayer':
        return _parseImageLayer(element);
      case 'group':
        return _parseGroupLayer(element, infinite, templates);
      default:
        return null;
    }
  }

  /// Parse a `layer` (tile layer) element.
  ///
  /// A finite layer's data must hold exactly its width × height tiles; a
  /// layer with no `data` is empty. An infinite map's layer holds chunks,
  /// each exactly its own size, and may have none.
  static TileLayer _parseTileLayer(XmlElement element, bool infinite) {
    final width = _int(element, 'width');
    final height = _int(element, 'height');
    final name = element.getAttribute('name') ?? '';

    final dataElement = element.getElement('data');
    Uint32List? gids;
    final chunks = <TileChunk>[];
    var encoding = LayerEncoding.xml;
    var compression = LayerCompression.none;

    if (dataElement != null) {
      encoding = LayerEncoding.fromString(dataElement.getAttribute('encoding'));
      compression = LayerCompression.fromString(
        dataElement.getAttribute('compression'),
      );
      final chunkElements = dataElement.findElements('chunk').toList();
      if (chunkElements.isNotEmpty || infinite) {
        // Each chunk is a rectangle encoded on its own.
        for (final chunk in chunkElements) {
          final x = _int(chunk, 'x');
          final y = _int(chunk, 'y');
          final w = _int(chunk, 'width');
          final h = _int(chunk, 'height');
          chunks.add(
            TileChunk(
              x: x,
              y: y,
              width: w,
              height: h,
              gids: _decodeData(
                chunk,
                encoding,
                compression,
                w * h,
                'the chunk at ($x, $y) of layer "$name"',
              ),
            ),
          );
        }
      } else {
        gids = _decodeData(
          dataElement,
          encoding,
          compression,
          width * height,
          'layer "$name"',
        );
      }
    } else if (!infinite) {
      gids = Uint32List(width * height);
    }

    return TileLayer(
      id: _int(element, 'id'),
      name: name,
      className: element.getAttribute('class') ?? '',
      visible: element.getAttribute('visible') != '0',
      locked: element.getAttribute('locked') == '1',
      opacity: _double(element, 'opacity', 1),
      offsetX: _double(element, 'offsetx'),
      offsetY: _double(element, 'offsety'),
      tintColor: parseTiledColor(element.getAttribute('tintcolor')),
      parallaxX: _double(element, 'parallaxx', 1),
      parallaxY: _double(element, 'parallaxy', 1),
      properties: _parseProperties(element),
      width: width,
      height: height,
      gids: gids,
      chunks: chunks,
      encoding: encoding,
      compression: compression,
    );
  }

  /// Decode the [cells] tiles of a `data` or `chunk` element, [what] for
  /// messages: raw ids, flags kept.
  static Uint32List _decodeData(
    XmlElement element,
    LayerEncoding encoding,
    LayerCompression compression,
    int cells,
    String what,
  ) => switch (encoding) {
    LayerEncoding.csv => checkTileCount(
      _decodeCsv(element.innerText),
      cells,
      what,
    ),
    LayerEncoding.base64 => decodeBase64Tiles(
      element.innerText,
      compression,
      cells,
      what,
    ),
    LayerEncoding.xml => checkTileCount(_decodeXmlTiles(element), cells, what),
  };

  /// Decode CSV-encoded tile data.
  static Uint32List _decodeCsv(String csvText) => Uint32List.fromList([
    for (final s in csvText.split(','))
      if (s.trim().isNotEmpty) int.parse(s.trim()).toUnsigned(32),
  ]);

  /// Decode XML `tile` elements (unencoded format).
  static Uint32List _decodeXmlTiles(XmlElement element) => Uint32List.fromList([
    for (final e in element.findElements('tile'))
      int.parse(e.getAttribute('gid') ?? '0').toUnsigned(32),
  ]);

  /// Parse an `objectgroup` element.
  static Future<ObjectGroup> _parseObjectGroup(
    XmlElement element,
    TemplateLoader templates,
  ) async {
    final objects = <TiledObject>[];
    for (final objElement in element.findElements('object')) {
      final path = objElement.getAttribute('template');
      final template = path == null ? null : await templates.load(path);
      objects.add(_parseObject(objElement, template: template));
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
      tintColor: parseTiledColor(element.getAttribute('tintcolor')),
      parallaxX: _double(element, 'parallaxx', 1),
      parallaxY: _double(element, 'parallaxy', 1),
      properties: _parseProperties(element),
      drawOrder: DrawOrder.fromString(
        element.getAttribute('draworder') ?? 'topdown',
      ),
      color: parseTiledColor(element.getAttribute('color')),
      objects: objects,
    );
  }

  /// A tile object's raw gid, flags kept, as an unsigned value.
  static int? _gid(String? text) =>
      text == null || text.isEmpty ? null : int.tryParse(text)?.toUnsigned(32);

  /// Parse an `object` element into a [TiledObject]. What an object placed
  /// from [template] doesn't set, it takes from the template; its shape
  /// too, unless it has one of its own.
  static TiledObject _parseObject(XmlElement element, {TiledObject? template}) {
    final t = template;
    String? attribute(String name) => element.getAttribute(name);
    final visible = attribute('visible');
    final ownShape = const [
      'ellipse',
      'point',
      'polygon',
      'polyline',
    ].any((shape) => element.getElement(shape) != null);
    final properties = _parseProperties(element);
    return TiledObject(
      id: _int(element, 'id'),
      name: attribute('name') ?? t?.name ?? '',
      type: attribute('type') ?? attribute('class') ?? t?.type ?? '',
      x: _double(element, 'x', t?.x ?? 0),
      y: _double(element, 'y', t?.y ?? 0),
      width: _double(element, 'width', t?.width ?? 0),
      height: _double(element, 'height', t?.height ?? 0),
      rotation: _double(element, 'rotation', t?.rotation ?? 0),
      gid: _gid(attribute('gid')) ?? t?.gid,
      visible: visible == null ? t?.visible ?? true : visible != '0',
      templatePath: attribute('template'),
      template: t,
      polygon: ownShape ? _parsePolygon(element) : t?.polygon,
      polyline: ownShape ? _parsePolyline(element) : t?.polyline,
      isEllipse: ownShape
          ? element.getElement('ellipse') != null
          : t?.isEllipse ?? false,
      isPoint: ownShape
          ? element.getElement('point') != null
          : t?.isPoint ?? false,
      text: element.getElement('text')?.innerText ?? t?.text,
      properties: t == null
          ? properties
          : mergeProperties(t.properties, properties),
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
      tintColor: parseTiledColor(element.getAttribute('tintcolor')),
      parallaxX: _double(element, 'parallaxx', 1),
      parallaxY: _double(element, 'parallaxy', 1),
      properties: _parseProperties(element),
      imageSource: imageElement?.getAttribute('source'),
      transparentColor: parseTiledColor(imageElement?.getAttribute('trans')),
      imageWidth: int.tryParse(imageElement?.getAttribute('width') ?? ''),
      imageHeight: int.tryParse(imageElement?.getAttribute('height') ?? ''),
      repeatX: element.getAttribute('repeatx') == '1',
      repeatY: element.getAttribute('repeaty') == '1',
    );
  }

  /// Parse a `group` element.
  static Future<GroupLayer> _parseGroupLayer(
    XmlElement element,
    bool infinite,
    TemplateLoader templates,
  ) async {
    final layers = <Layer>[];
    for (final child in element.childElements) {
      final layer = await _parseLayerElement(child, infinite, templates);
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
      tintColor: parseTiledColor(element.getAttribute('tintcolor')),
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
    return pointsStr.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).map((
      pair,
    ) {
      final parts = pair.split(',');
      return Offset(
        double.tryParse(parts[0]) ?? 0.0,
        parts.length > 1 ? (double.tryParse(parts[1]) ?? 0.0) : 0.0,
      );
    }).toList();
  }

  /// Parse `properties` element, keeping each property's declared type and
  /// custom type. A `class` property's members are its own nested
  /// `properties` element.
  static TiledProperties _parseProperties(XmlElement element) {
    final propsElement = element.getElement('properties');
    if (propsElement == null) return const TiledProperties();

    final map = <String, dynamic>{};
    final types = <String, String>{};
    final propertyTypes = <String, String>{};
    for (final prop in propsElement.findElements('property')) {
      final name = prop.getAttribute('name') ?? '';
      final type = prop.getAttribute('type') ?? 'string';
      types[name] = type;
      final propertyType = prop.getAttribute('propertytype');
      if (propertyType != null && propertyType.isNotEmpty) {
        propertyTypes[name] = propertyType;
      }
      if (type == 'class') {
        map[name] = _parseProperties(prop);
        continue;
      }
      final value = prop.getAttribute('value') ?? prop.innerText;

      switch (type) {
        case 'int':
        case 'object':
          map[name] = int.tryParse(value) ?? 0;
        case 'float':
          map[name] = double.tryParse(value) ?? 0.0;
        case 'bool':
          map[name] = value.toLowerCase() == 'true';
        case 'color':
          map[name] = parseTiledColor(value);
        case 'file':
        case 'string':
        default:
          map[name] = value;
      }
    }

    return TiledProperties(map, types, propertyTypes);
  }

  static int _int(XmlElement? element, String name, [int fallback = 0]) =>
      int.tryParse(element?.getAttribute(name) ?? '') ?? fallback;

  static double _double(
    XmlElement element,
    String name, [
    double fallback = 0,
  ]) => double.tryParse(element.getAttribute(name) ?? '') ?? fallback;
}
