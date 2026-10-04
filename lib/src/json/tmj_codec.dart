/// Tiled's JSON formats: TMJ maps and TSJ tilesets, read and written.
library;

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:archive/archive.dart';
import 'package:just_zstd/just_zstd.dart';

import '../models/models.dart';
import '../parser/tile_map_parser.dart';
import '../parser/tsx_provider.dart';
import '../writer/xml_common.dart' show tiledColor, tmxFormatVersion;

/// Reads TMJ maps and TSJ tilesets into the same models the TMX parser
/// produces.
abstract final class TmjParser {
  /// Parse a TMJ document. External tilesets are read through
  /// [tsxProvider], as TSJ or TSX by their file ending.
  static Future<TiledMap> parse(String json, {TsxProvider? tsxProvider}) =>
      parseMap(jsonDecode(json) as Map<String, dynamic>, tsxProvider: tsxProvider);

  /// Parse an already-decoded TMJ document.
  static Future<TiledMap> parseMap(
    Map<String, dynamic> json, {
    TsxProvider? tsxProvider,
  }) async {
    final tilesets = <Tileset>[];
    for (final raw in _list(json['tilesets'])) {
      final ts = raw as Map<String, dynamic>;
      final firstGid = _int(ts['firstgid'], 1);
      final source = ts['source'] as String?;
      if (source != null && tsxProvider != null) {
        final text = await tsxProvider.getTsx(source);
        final p = source.toLowerCase();
        tilesets.add(
          p.endsWith('.tsj') || p.endsWith('.json')
              ? parseTilesetJson(
                  jsonDecode(text) as Map<String, dynamic>,
                  firstGid: firstGid,
                  source: source,
                )
              : TileMapParser.parseTileset(
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
      infinite: json['infinite'] == true,
      backgroundColor: _color(json['backgroundcolor']),
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
      layers: [for (final l in _list(json['layers'])) ?_layer(l as Map<String, dynamic>)],
      properties: _properties(json['properties']),
    );
  }

  /// Parse a TSJ document.
  static Tileset parseTileset(String json, {int firstGid = 1, String? source}) =>
      parseTilesetJson(
        jsonDecode(json) as Map<String, dynamic>,
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
      transparentColor: _color(json['transparentcolor']),
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
          color: _color(c['color']) ?? const Color(0xFFFF0000),
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

  static Layer? _layer(Map<String, dynamic> json) {
    final id = _int(json['id']);
    final name = json['name'] as String? ?? '';
    final className = json['class'] as String? ?? '';
    final visible = json['visible'] != false;
    final locked = json['locked'] == true;
    final opacity = _double(json['opacity'], 1);
    final offsetX = _double(json['offsetx']);
    final offsetY = _double(json['offsety']);
    final tint = _color(json['tintcolor']);
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
        final chunks = [
          for (final c in _list(json['chunks']))
            TileChunk(
              x: _int((c as Map)['x']),
              y: _int(c['y']),
              width: _int(c['width']),
              height: _int(c['height']),
              data: _data(c['data'], compression),
            ),
        ];
        final raw = chunks.isEmpty
            ? _data(json['data'], compression)
            : Uint32List(0);
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
          width: _int(json['width']),
          height: _int(json['height']),
          data: [for (final g in raw) TiledGid.idOf(g)],
          flipHorizontal: [for (final g in raw) TiledGid.isFlippedHorizontally(g)],
          flipVertical: [for (final g in raw) TiledGid.isFlippedVertically(g)],
          flipDiagonal: [for (final g in raw) TiledGid.isFlippedDiagonally(g)],
          rawData: chunks.isEmpty ? raw : null,
          chunks: chunks,
          encoding: encoding,
          compression: compression,
        );
      case 'objectgroup':
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
          color: _color(json['color']),
          objects: [
            for (final o in _list(json['objects']))
              _object(o as Map<String, dynamic>),
          ],
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
          transparentColor: _color(json['transparentcolor']),
          imageWidth: (json['imagewidth'] as num?)?.toInt(),
          imageHeight: (json['imageheight'] as num?)?.toInt(),
          repeatX: json['repeatx'] == true,
          repeatY: json['repeaty'] == true,
        );
      case 'group':
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
          layers: [
            for (final l in _list(json['layers']))
              ?_layer(l as Map<String, dynamic>),
          ],
        );
      default:
        return null;
    }
  }

  static Uint32List _data(Object? data, LayerCompression compression) {
    if (data is List) {
      return Uint32List.fromList([
        for (final v in data) (v as num).toInt().toUnsigned(32),
      ]);
    }
    if (data is String) {
      final bytes = base64Decode(data.trim());
      final Uint8List plain = switch (compression) {
        LayerCompression.none => bytes,
        LayerCompression.gzip => Uint8List.fromList(
          GZipDecoder().decodeBytes(bytes),
        ),
        LayerCompression.zlib => Uint8List.fromList(
          ZLibDecoder().decodeBytes(bytes),
        ),
        LayerCompression.zstd => const ZstdDecoder().decodeBytes(bytes),
      };
      return TiledGid.fromBytes(plain);
    }
    return Uint32List(0);
  }

  static TiledObject _object(Map<String, dynamic> json) {
    List<Offset>? points(Object? raw) => raw is List
        ? [
            for (final p in raw)
              Offset(_double((p as Map)['x']), _double(p['y'])),
          ]
        : null;
    final text = json['text'];
    return TiledObject(
      id: _int(json['id']),
      name: json['name'] as String? ?? '',
      type: (json['type'] ?? json['class'] ?? '') as String,
      x: _double(json['x']),
      y: _double(json['y']),
      width: _double(json['width']),
      height: _double(json['height']),
      rotation: _double(json['rotation']),
      gid: (json['gid'] as num?)?.toInt().toUnsigned(32),
      visible: json['visible'] != false,
      templatePath: json['template'] as String?,
      polygon: points(json['polygon']),
      polyline: points(json['polyline']),
      isEllipse: json['ellipse'] == true,
      isPoint: json['point'] == true,
      text: text is Map ? text['text'] as String? : null,
      properties: _properties(json['properties']),
    );
  }

  static TiledProperties _properties(Object? raw) {
    if (raw is! List || raw.isEmpty) return const TiledProperties();
    final values = <String, dynamic>{};
    final types = <String, String>{};
    for (final p in raw) {
      final m = p as Map;
      final name = m['name'] as String? ?? '';
      final type = m['type'] as String? ?? 'string';
      final value = m['value'];
      types[name] = type;
      values[name] = switch (type) {
        'int' || 'object' => (value as num?)?.toInt() ?? 0,
        'float' => (value as num?)?.toDouble() ?? 0.0,
        'bool' => value == true,
        'color' => _color(value),
        _ => value is String ? value : '${value ?? ''}',
      };
    }
    return TiledProperties(values, types);
  }

  static List<Object?> _list(Object? raw) => raw is List ? raw : const [];

  static int _int(Object? raw, [int fallback = 0]) =>
      raw is num ? raw.toInt() : fallback;

  static double _double(Object? raw, [double fallback = 0]) =>
      raw is num ? raw.toDouble() : fallback;

  static Color? _color(Object? raw) {
    if (raw is! String || raw.isEmpty) return null;
    var hex = raw.startsWith('#') ? raw.substring(1) : raw;
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length != 8) return null;
    final value = int.tryParse(hex, radix: 16);
    return value == null ? null : Color(value);
  }
}

/// Writes TMJ maps and TSJ tilesets.
abstract final class TmjWriter {
  /// [map] as a TMJ document. [base64Zlib] stores tile data compressed, as
  /// Tiled can; plain number arrays otherwise.
  static String write(
    TiledMap map, {
    bool base64Zlib = false,
    String tiledVersion = '1.10.2',
  }) => const JsonEncoder.withIndent(' ').convert(
    toJson(map, base64Zlib: base64Zlib, tiledVersion: tiledVersion),
  );

  /// [map] as a TMJ object.
  static Map<String, dynamic> toJson(
    TiledMap map, {
    bool base64Zlib = false,
    String tiledVersion = '1.10.2',
  }) => {
    if (map.backgroundColor != null)
      'backgroundcolor': tiledColor(map.backgroundColor!),
    if (map.className.isNotEmpty) 'class': map.className,
    'compressionlevel': -1,
    'height': map.height,
    if (map.hexSideLength != null) 'hexsidelength': map.hexSideLength,
    'infinite': map.infinite,
    'layers': [for (final l in map.layers) ?_layer(l, base64Zlib)],
    if (map.nextLayerId != null) 'nextlayerid': map.nextLayerId,
    if (map.nextObjectId != null) 'nextobjectid': map.nextObjectId,
    'orientation': map.orientation.name,
    if (map.parallaxOriginX != 0) 'parallaxoriginx': map.parallaxOriginX,
    if (map.parallaxOriginY != 0) 'parallaxoriginy': map.parallaxOriginY,
    if (map.properties.isNotEmpty) 'properties': _properties(map.properties),
    'renderorder': map.renderOrder.tmxValue,
    if (map.staggerAxis != null) 'staggeraxis': map.staggerAxis!.name,
    if (map.staggerIndex != null) 'staggerindex': map.staggerIndex!.name,
    'tiledversion': tiledVersion,
    'tileheight': map.tileHeight,
    'tilesets': [
      for (final ts in map.tilesets)
        ts.source != null
            ? {'firstgid': ts.firstGid, 'source': ts.source}
            : tilesetToJson(ts, firstGid: ts.firstGid),
    ],
    'tilewidth': map.tileWidth,
    'type': 'map',
    'version': tmxFormatVersion,
    'width': map.width,
  };

  /// [tileset] as a TSJ document.
  static String writeTileset(Tileset tileset, {String tiledVersion = '1.10.2'}) =>
      const JsonEncoder.withIndent(' ').convert({
        ...tilesetToJson(tileset),
        'tiledversion': tiledVersion,
        'type': 'tileset',
        'version': tmxFormatVersion,
      });

  /// [tileset] as a tileset object; with [firstGid] when embedded in a map.
  static Map<String, dynamic> tilesetToJson(Tileset ts, {int? firstGid}) {
    final t = ts.transformations;
    final ids = ts.tiles.keys.toList()..sort();
    return {
      if (ts.className.isNotEmpty) 'class': ts.className,
      'columns': ts.columns,
      if (ts.fillMode != FillMode.stretch) 'fillmode': ts.fillMode.tmxValue,
      'firstgid': ?firstGid,
      if (ts.grid != null)
        'grid': {
          'height': ts.grid!.height,
          'orientation': ts.grid!.orientation.name,
          'width': ts.grid!.width,
        },
      if (ts.imageSource != null) 'image': ts.imageSource,
      if (ts.imageHeight != null) 'imageheight': ts.imageHeight,
      if (ts.imageWidth != null) 'imagewidth': ts.imageWidth,
      'margin': ts.margin,
      'name': ts.name,
      if (ts.objectAlignment != ObjectAlignment.unspecified)
        'objectalignment': ts.objectAlignment.name,
      if (ts.properties.isNotEmpty) 'properties': _properties(ts.properties),
      'spacing': ts.spacing,
      'tilecount': ts.tileCount,
      'tileheight': ts.tileHeight,
      if (ts.tileOffset != Offset.zero)
        'tileoffset': {'x': ts.tileOffset.dx, 'y': ts.tileOffset.dy},
      if (ts.tileRenderSize != TileRenderSize.tile)
        'tilerendersize': ts.tileRenderSize.name,
      if (ids.isNotEmpty)
        'tiles': [for (final id in ids) _tile(ts.tiles[id]!)],
      'tilewidth': ts.tileWidth,
      if (t.any)
        'transformations': {
          'hflip': t.hflip,
          'preferuntransformed': t.preferUntransformed,
          'rotate': t.rotate,
          'vflip': t.vflip,
        },
      if (ts.transparentColor != null)
        'transparentcolor': tiledColor(ts.transparentColor!),
      if (ts.wangSets.isNotEmpty)
        'wangsets': [for (final w in ts.wangSets) _wangSet(w)],
    };
  }

  static Map<String, dynamic> _tile(Tile tile) => {
    if (tile.animation.isNotEmpty)
      'animation': [
        for (final f in tile.animation)
          {'duration': f.duration, 'tileid': f.tileId},
      ],
    'id': tile.id,
    if (tile.imageSource != null) 'image': tile.imageSource,
    if (tile.imageHeight != null) 'imageheight': tile.imageHeight,
    if (tile.imageWidth != null) 'imagewidth': tile.imageWidth,
    if (tile.objectGroup.isNotEmpty)
      'objectgroup': {
        'draworder': 'index',
        'name': '',
        'objects': [for (final o in tile.objectGroup) _object(o)],
        'opacity': 1,
        'type': 'objectgroup',
        'visible': true,
        'x': 0,
        'y': 0,
      },
    if (tile.probability != 1) 'probability': tile.probability,
    if (tile.properties.isNotEmpty) 'properties': _properties(tile.properties),
    if (tile.type != null && tile.type!.isNotEmpty) 'type': tile.type,
  };

  static Map<String, dynamic> _wangSet(WangSet set) => {
    if (set.className.isNotEmpty) 'class': set.className,
    'colors': [
      for (final c in set.colors)
        {
          if (c.className.isNotEmpty) 'class': c.className,
          'color': tiledColor(c.color),
          'name': c.name,
          'probability': c.probability,
          if (c.properties.isNotEmpty) 'properties': _properties(c.properties),
          'tile': c.tile,
        },
    ],
    'name': set.name,
    if (set.properties.isNotEmpty) 'properties': _properties(set.properties),
    'tile': set.tile,
    'type': set.type.name,
    'wangtiles': [
      for (final id in set.wangTiles.keys.toList()..sort())
        {'tileid': id, 'wangid': set.wangTiles[id]},
    ],
  };

  static Map<String, dynamic> _common(Layer l) => {
    if (l.className.isNotEmpty) 'class': l.className,
    'id': l.id,
    if (l.locked) 'locked': true,
    'name': l.name,
    if (l.offsetX != 0) 'offsetx': l.offsetX,
    if (l.offsetY != 0) 'offsety': l.offsetY,
    'opacity': l.opacity,
    if (l.parallaxX != 1) 'parallaxx': l.parallaxX,
    if (l.parallaxY != 1) 'parallaxy': l.parallaxY,
    if (l.properties.isNotEmpty) 'properties': _properties(l.properties),
    if (l.tintColor != null) 'tintcolor': tiledColor(l.tintColor!),
    'visible': l.visible,
    'x': 0,
    'y': 0,
  };

  static Map<String, dynamic>? _layer(Layer l, bool base64Zlib) {
    switch (l) {
      case TileLayer():
        Object data(List<int> ids) => base64Zlib
            ? base64Encode(ZLibEncoder().encodeBytes(TiledGid.toBytes(ids)))
            : [for (final id in ids) id.toUnsigned(32)];
        return {
          ..._common(l),
          if (l.isChunked)
            'chunks': [
              for (final c in l.chunks)
                {
                  'data': data(c.data),
                  'height': c.height,
                  'width': c.width,
                  'x': c.x,
                  'y': c.y,
                },
            ]
          else
            'data': data(l.rawGids),
          if (base64Zlib) 'compression': 'zlib',
          if (base64Zlib) 'encoding': 'base64',
          'height': l.height,
          'type': 'tilelayer',
          'width': l.width,
        };
      case ObjectGroup():
        return {
          ..._common(l),
          if (l.color != null) 'color': tiledColor(l.color!),
          'draworder': l.drawOrder.tmxValue,
          'objects': [for (final o in l.objects) _object(o)],
          'type': 'objectgroup',
        };
      case ImageLayer():
        return {
          ..._common(l),
          'image': l.imageSource ?? '',
          if (l.imageHeight != null) 'imageheight': l.imageHeight,
          if (l.imageWidth != null) 'imagewidth': l.imageWidth,
          if (l.repeatX) 'repeatx': true,
          if (l.repeatY) 'repeaty': true,
          if (l.transparentColor != null)
            'transparentcolor': tiledColor(l.transparentColor!),
          'type': 'imagelayer',
        };
      case GroupLayer():
        return {
          ..._common(l),
          'layers': [for (final c in l.layers) ?_layer(c, base64Zlib)],
          'type': 'group',
        };
      default:
        return null;
    }
  }

  static Map<String, dynamic> _object(TiledObject o) => {
    if (o.isEllipse) 'ellipse': true,
    if (o.gid != null) 'gid': o.gid!.toUnsigned(32),
    'height': o.height,
    'id': o.id,
    'name': o.name,
    if (o.isPoint) 'point': true,
    if (o.polygon != null)
      'polygon': [for (final p in o.polygon!) {'x': p.dx, 'y': p.dy}],
    if (o.polyline != null)
      'polyline': [for (final p in o.polyline!) {'x': p.dx, 'y': p.dy}],
    if (o.properties.isNotEmpty) 'properties': _properties(o.properties),
    'rotation': o.rotation,
    'template': ?o.templatePath,
    if (o.text != null) 'text': {'text': o.text},
    'type': o.type,
    'visible': o.visible,
    'width': o.width,
    'x': o.x,
    'y': o.y,
  };

  static List<Map<String, dynamic>> _properties(TiledProperties p) => [
    for (final key in p.keys)
      {
        'name': key,
        'type': p.typeOf(key),
        'value': switch (p[key]) {
          final Color c => tiledColor(c),
          final Object? v => v,
        },
      },
  ];
}
