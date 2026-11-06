/// Reads Tiled's JSON formats: TMJ maps, TSJ tilesets and TJ templates.
library;

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:meta/meta.dart';

import '../../files/tile_data.dart';
import '../../files/tiled_file_provider.dart';
import '../../files/tiled_notation.dart';
import '../../files/tiled_paths.dart';
import '../../models/models.dart';
import '../object_templates.dart';
import '../tmx/tmx_parser.dart';

/// Reads TMJ maps, TSJ tilesets and TJ templates into the same models the
/// TMX reader produces.
///
/// A document that isn't valid JSON, or whose values have the wrong types,
/// throws a [FormatException], as does tile data that doesn't hold exactly
/// its layer's or chunk's tiles.
abstract final class TmjParser {
  /// Parse a TMJ document. [fileProvider] loads the external tilesets (TSJ
  /// or TSX) and object templates (TJ or TX) the map names, by their file
  /// ending. Without one, an external tileset has only its first gid and
  /// source, and a templated object only its own values.
  static Future<TiledMap> parse(
    String json, {
    TiledFileProvider? fileProvider,
  }) async => parseMap(
    _jsonObject(jsonDecode(json), 'TMJ map'),
    fileProvider: fileProvider,
  );

  /// Parse an already-decoded TMJ document.
  static Future<TiledMap> parseMap(
    Map<String, dynamic> json, {
    TiledFileProvider? fileProvider,
  }) async {
    try {
      return await _parseMap(json, fileProvider);
    } on TypeError catch (e) {
      throw FormatException('Not a valid TMJ map: $e');
    }
  }

  /// Parse a TSJ document.
  static Tileset parseTileset(
    String json, {
    int firstGid = 1,
    String? source,
  }) => parseTilesetJson(
    _jsonObject(jsonDecode(json), 'TSJ tileset'),
    firstGid: firstGid,
    source: source,
  );

  /// Parse an already-decoded tileset: a TSJ document, or one embedded in
  /// a TMJ map.
  static Tileset parseTilesetJson(
    Map<String, dynamic> json, {
    int firstGid = 1,
    String? source,
  }) {
    try {
      return _parseTileset(json, firstGid, source);
    } on TypeError catch (e) {
      throw FormatException('Not a valid TSJ tileset: $e');
    }
  }

  /// Parse a TJ template document: its object, and the external tileset
  /// its tile is numbered from.
  @internal
  static TemplateFile parseTemplate(String json) {
    final root = _jsonObject(jsonDecode(json), 'TJ template');
    try {
      final object = root['object'];
      if (object is! Map<String, dynamic>) {
        throw const FormatException('Not a valid TJ template: no object');
      }
      final tileset = root['tileset'] as Map<String, dynamic>?;
      return TemplateFile(
        _object(object),
        tilesetSource: tileset?['source'] as String?,
        tilesetFirstGid: _int(tileset?['firstgid'], 1),
      );
    } on TypeError catch (e) {
      throw FormatException('Not a valid TJ template: $e');
    }
  }

  /// [decoded] as a JSON object, or a [FormatException] naming [what] it
  /// should have been.
  static Map<String, dynamic> _jsonObject(Object? decoded, String what) {
    if (decoded is Map<String, dynamic>) return decoded;
    throw FormatException('Not a valid $what: expected a JSON object');
  }

  static Future<TiledMap> _parseMap(
    Map<String, dynamic> json,
    TiledFileProvider? fileProvider,
  ) async {
    final tilesets = <Tileset>[];
    for (final raw in _list(json['tilesets'])) {
      final ts = raw as Map<String, dynamic>;
      final firstGid = _int(ts['firstgid'], 1);
      final source = ts['source'] as String?;
      if (source != null && fileProvider != null) {
        final text = await fileProvider.loadTileset(source);
        tilesets.add(
          isJsonFile(source)
              ? parseTileset(text, firstGid: firstGid, source: source)
              : TmxParser.parseTileset(
                  text,
                  firstGid: firstGid,
                  source: source,
                ),
        );
      } else if (source != null) {
        tilesets.add(Tileset(firstGid: firstGid, source: source));
      } else {
        tilesets.add(parseTilesetJson(ts, firstGid: firstGid));
      }
    }

    final infinite = json['infinite'] == true;
    final templates = TemplateLoader(fileProvider, tilesets);
    final layers = <Layer>[];
    for (final l in _list(json['layers'])) {
      final layer = await _layer(
        l as Map<String, dynamic>,
        infinite,
        templates,
      );
      if (layer != null) layers.add(layer);
    }

    return TiledMap(
      version: '${json['version'] ?? '1.0'}',
      tiledVersion: json['tiledversion'] as String?,
      className: json['class'] as String? ?? '',
      orientation: MapOrientation.fromString(
        json['orientation'] as String? ?? 'orthogonal',
      ),
      renderOrder: RenderOrder.fromString(
        json['renderorder'] as String? ?? 'right-down',
      ),
      width: _int(json['width']),
      height: _int(json['height']),
      tileWidth: _int(json['tilewidth']),
      tileHeight: _int(json['tileheight']),
      infinite: infinite,
      backgroundColor: parseTiledColor(json['backgroundcolor']),
      nextLayerId: (json['nextlayerid'] as num?)?.toInt(),
      nextObjectId: (json['nextobjectid'] as num?)?.toInt(),
      staggerAxis: json['staggeraxis'] == null
          ? null
          : StaggerAxis.fromString(json['staggeraxis'] as String),
      staggerIndex: json['staggerindex'] == null
          ? null
          : StaggerIndex.fromString(json['staggerindex'] as String),
      hexSideLength: (json['hexsidelength'] as num?)?.toInt(),
      parallaxOriginX: _double(json['parallaxoriginx']),
      parallaxOriginY: _double(json['parallaxoriginy']),
      tilesets: tilesets,
      layers: layers,
      properties: _properties(json['properties']),
    );
  }

  static Tileset _parseTileset(
    Map<String, dynamic> json,
    int firstGid,
    String? source,
  ) {
    final offset = json['tileoffset'] as Map<String, dynamic>?;
    final grid = json['grid'] as Map<String, dynamic>?;
    final transforms = json['transformations'] as Map<String, dynamic>?;
    final tiles = <int, Tile>{};
    for (final raw in _list(json['tiles'])) {
      final tile = _tile(raw as Map<String, dynamic>);
      tiles[tile.id] = tile;
    }
    return Tileset(
      firstGid: firstGid,
      name: json['name'] as String? ?? '',
      className: json['class'] as String? ?? '',
      tileWidth: _int(json['tilewidth']),
      tileHeight: _int(json['tileheight']),
      spacing: _int(json['spacing']),
      margin: _int(json['margin']),
      tileCount: _int(json['tilecount']),
      columns: _int(json['columns']),
      tileOffset: offset == null
          ? Offset.zero
          : Offset(_double(offset['x']), _double(offset['y'])),
      objectAlignment: ObjectAlignment.fromString(
        json['objectalignment'] as String?,
      ),
      tileRenderSize: TileRenderSize.fromString(
        json['tilerendersize'] as String?,
      ),
      fillMode: FillMode.fromString(json['fillmode'] as String?),
      grid: grid == null
          ? null
          : TilesetGrid(
              orientation: MapOrientation.fromString(
                grid['orientation'] as String? ?? 'orthogonal',
              ),
              width: _int(grid['width']),
              height: _int(grid['height']),
            ),
      transformations: transforms == null
          ? const TilesetTransformations()
          : TilesetTransformations(
              hflip: transforms['hflip'] == true,
              vflip: transforms['vflip'] == true,
              rotate: transforms['rotate'] == true,
              preferUntransformed: transforms['preferuntransformed'] == true,
            ),
      imageSource: json['image'] as String?,
      imageWidth: (json['imagewidth'] as num?)?.toInt(),
      imageHeight: (json['imageheight'] as num?)?.toInt(),
      transparentColor: parseTiledColor(json['transparentcolor']),
      tiles: tiles,
      wangSets: [
        for (final w in _list(json['wangsets']))
          _wangSet(w as Map<String, dynamic>),
      ],
      source: source,
      properties: _properties(json['properties']),
    );
  }

  static Tile _tile(Map<String, dynamic> json) {
    final group = json['objectgroup'] as Map<String, dynamic>?;
    return Tile(
      id: _int(json['id']),
      type: (json['type'] ?? json['class']) as String?,
      probability: _double(json['probability'], 1),
      imageSource: json['image'] as String?,
      imageWidth: (json['imagewidth'] as num?)?.toInt(),
      imageHeight: (json['imageheight'] as num?)?.toInt(),
      objectGroup: group == null
          ? const []
          : [
              for (final o in _list(group['objects']))
                _object(o as Map<String, dynamic>),
            ],
      animation: [
        for (final f in _list(json['animation']))
          AnimationFrame(
            tileId: _int((f as Map)['tileid']),
            duration: _int(f['duration'], 100),
          ),
      ],
      properties: _properties(json['properties']),
    );
  }

  static WangSet _wangSet(Map<String, dynamic> json) => WangSet(
    name: json['name'] as String? ?? '',
    className: json['class'] as String? ?? '',
    type: WangSetType.fromString(json['type'] as String?),
    tile: _int(json['tile'], -1),
    colors: [
      for (final c in _list(json['colors']))
        WangColor(
          name: (c as Map)['name'] as String? ?? '',
          className: c['class'] as String? ?? '',
          color: parseTiledColor(c['color']) ?? const Color(0xFFFF0000),
          tile: _int(c['tile'], -1),
          probability: _double(c['probability'], 1),
          properties: _properties(c['properties']),
        ),
    ],
    wangTiles: {
      for (final t in _list(json['wangtiles']))
        _int((t as Map)['tileid']): [
          for (final v in _list(t['wangid'])) (v as num).toInt(),
        ],
    },
    properties: _properties(json['properties']),
  );

  /// A layer of a map in which [infinite] says whether tile layers hold
  /// chunks.
  static Future<Layer?> _layer(
    Map<String, dynamic> json,
    bool infinite,
    TemplateLoader templates,
  ) async {
    final id = _int(json['id']);
    final name = json['name'] as String? ?? '';
    final className = json['class'] as String? ?? '';
    final visible = json['visible'] != false;
    final locked = json['locked'] == true;
    final opacity = _double(json['opacity'], 1);
    final offsetX = _double(json['offsetx']);
    final offsetY = _double(json['offsety']);
    final tint = parseTiledColor(json['tintcolor']);
    final parallaxX = _double(json['parallaxx'], 1);
    final parallaxY = _double(json['parallaxy'], 1);
    final properties = _properties(json['properties']);
    switch (json['type']) {
      case 'tilelayer':
        final encoding = json['encoding'] == 'base64'
            ? LayerEncoding.base64
            : LayerEncoding.csv;
        final compression = LayerCompression.fromString(
          json['compression'] as String?,
        );
        final width = _int(json['width']);
        final height = _int(json['height']);
        final chunked = json['chunks'] != null || infinite;
        final chunks = [
          for (final c in _list(json['chunks']))
            _chunk(c as Map<String, dynamic>, compression, name),
        ];
        // A finite layer's data must hold exactly its tiles; no data at
        // all is an empty layer.
        final Uint32List? gids = chunked
            ? null
            : json['data'] == null
            ? Uint32List(width * height)
            : _data(json['data'], compression, width * height, 'layer "$name"');
        return TileLayer(
          id: id,
          name: name,
          className: className,
          visible: visible,
          locked: locked,
          opacity: opacity,
          offsetX: offsetX,
          offsetY: offsetY,
          tintColor: tint,
          parallaxX: parallaxX,
          parallaxY: parallaxY,
          properties: properties,
          width: width,
          height: height,
          gids: gids,
          chunks: chunks,
          encoding: encoding,
          compression: compression,
        );
      case 'objectgroup':
        final objects = <TiledObject>[];
        for (final raw in _list(json['objects'])) {
          final o = raw as Map<String, dynamic>;
          final path = o['template'] as String?;
          final template = path == null ? null : await templates.load(path);
          objects.add(_object(o, template: template));
        }
        return ObjectGroup(
          id: id,
          name: name,
          className: className,
          visible: visible,
          locked: locked,
          opacity: opacity,
          offsetX: offsetX,
          offsetY: offsetY,
          tintColor: tint,
          parallaxX: parallaxX,
          parallaxY: parallaxY,
          properties: properties,
          drawOrder: DrawOrder.fromString(
            json['draworder'] as String? ?? 'topdown',
          ),
          color: parseTiledColor(json['color']),
          objects: objects,
        );
      case 'imagelayer':
        return ImageLayer(
          id: id,
          name: name,
          className: className,
          visible: visible,
          locked: locked,
          opacity: opacity,
          offsetX: offsetX,
          offsetY: offsetY,
          tintColor: tint,
          parallaxX: parallaxX,
          parallaxY: parallaxY,
          properties: properties,
          imageSource: json['image'] as String?,
          transparentColor: parseTiledColor(json['transparentcolor']),
          imageWidth: (json['imagewidth'] as num?)?.toInt(),
          imageHeight: (json['imageheight'] as num?)?.toInt(),
          repeatX: json['repeatx'] == true,
          repeatY: json['repeaty'] == true,
        );
      case 'group':
        final layers = <Layer>[];
        for (final l in _list(json['layers'])) {
          final layer = await _layer(
            l as Map<String, dynamic>,
            infinite,
            templates,
          );
          if (layer != null) layers.add(layer);
        }
        return GroupLayer(
          id: id,
          name: name,
          className: className,
          visible: visible,
          locked: locked,
          opacity: opacity,
          offsetX: offsetX,
          offsetY: offsetY,
          tintColor: tint,
          parallaxX: parallaxX,
          parallaxY: parallaxY,
          properties: properties,
          layers: layers,
        );
      default:
        return null;
    }
  }

  static TileChunk _chunk(
    Map<String, dynamic> json,
    LayerCompression compression,
    String layer,
  ) {
    final x = _int(json['x']);
    final y = _int(json['y']);
    final width = _int(json['width']);
    final height = _int(json['height']);
    return TileChunk(
      x: x,
      y: y,
      width: width,
      height: height,
      gids: _data(
        json['data'],
        compression,
        width * height,
        'the chunk at ($x, $y) of layer "$layer"',
      ),
    );
  }

  /// The [cells] tile ids of [what] in [data]: a list of numbers, or base64
  /// text, compressed or not.
  static Uint32List _data(
    Object? data,
    LayerCompression compression,
    int cells,
    String what,
  ) {
    if (data is List) {
      return checkTileCount(
        Uint32List.fromList([
          for (final v in data) (v as num).toInt().toUnsigned(32),
        ]),
        cells,
        what,
      );
    }
    if (data is String) {
      return decodeBase64Tiles(data, compression, cells, what);
    }
    throw FormatException('The tile data of $what is neither a list nor text');
  }

  /// An object. What an object placed from [template] doesn't set, it
  /// takes from the template; its shape too, unless it has one of its own.
  static TiledObject _object(
    Map<String, dynamic> json, {
    TiledObject? template,
  }) {
    final t = template;
    List<Offset>? points(Object? raw) => raw is List
        ? [
            for (final p in raw)
              Offset(_double((p as Map)['x']), _double(p['y'])),
          ]
        : null;
    double number(String key, double? inherited) =>
        json.containsKey(key) ? _double(json[key]) : inherited ?? 0;
    final ownShape = const [
      'ellipse',
      'point',
      'polygon',
      'polyline',
    ].any(json.containsKey);
    final text = json['text'];
    final properties = _properties(json['properties']);
    return TiledObject(
      id: _int(json['id']),
      name: json['name'] as String? ?? t?.name ?? '',
      type: (json['type'] ?? json['class'] ?? t?.type ?? '') as String,
      x: number('x', t?.x),
      y: number('y', t?.y),
      width: number('width', t?.width),
      height: number('height', t?.height),
      rotation: number('rotation', t?.rotation),
      gid: (json['gid'] as num?)?.toInt().toUnsigned(32) ?? t?.gid,
      visible: json.containsKey('visible')
          ? json['visible'] != false
          : t?.visible ?? true,
      templatePath: json['template'] as String?,
      template: t,
      polygon: ownShape ? points(json['polygon']) : t?.polygon,
      polyline: ownShape ? points(json['polyline']) : t?.polyline,
      isEllipse: ownShape ? json['ellipse'] == true : t?.isEllipse ?? false,
      isPoint: ownShape ? json['point'] == true : t?.isPoint ?? false,
      text: text is Map ? text['text'] as String? : t?.text,
      properties: t == null
          ? properties
          : mergeProperties(t.properties, properties),
    );
  }

  static TiledProperties _properties(Object? raw) {
    if (raw is! List || raw.isEmpty) return const TiledProperties();
    final values = <String, dynamic>{};
    final types = <String, String>{};
    final propertyTypes = <String, String>{};
    for (final p in raw) {
      final m = p as Map;
      final name = m['name'] as String? ?? '';
      final type = m['type'] as String? ?? 'string';
      final value = m['value'];
      types[name] = type;
      final propertyType = m['propertytype'];
      if (propertyType is String && propertyType.isNotEmpty) {
        propertyTypes[name] = propertyType;
      }
      values[name] = switch (type) {
        'int' || 'object' => (value as num?)?.toInt() ?? 0,
        'float' => (value as num?)?.toDouble() ?? 0.0,
        'bool' => value == true,
        'color' => parseTiledColor(value),
        'class' => _members(value),
        _ => value is String ? value : '${value ?? ''}',
      };
    }
    return TiledProperties(values, types, propertyTypes);
  }

  /// A `class` property's members. TMJ gives only their values, so each
  /// member's type is read from its value: a colour comes back a string.
  static TiledProperties _members(Object? raw) {
    if (raw is! Map || raw.isEmpty) return const TiledProperties();
    return TiledProperties({
      for (final MapEntry(:key, :value) in raw.entries)
        key as String: value is Map ? _members(value) : value,
    });
  }

  static List<Object?> _list(Object? raw) => raw is List ? raw : const [];

  static int _int(Object? raw, [int fallback = 0]) =>
      raw is num ? raw.toInt() : fallback;

  static double _double(Object? raw, [double fallback = 0]) =>
      raw is num ? raw.toDouble() : fallback;
}
