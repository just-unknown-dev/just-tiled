/// Writes Tiled's JSON formats: TMJ maps and TSJ tilesets.
library;

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:just_deflate/just_deflate.dart';

import '../../files/tiled_notation.dart';
import '../../models/models.dart';
import '../template_overrides.dart';
import '../tiled_data_encoding.dart';

/// Writes TMJ maps and TSJ tilesets.
///
/// An object placed from a loaded template is written with only what it
/// sets itself, as Tiled writes it.
abstract final class TmjWriter {
  /// [map] as a TMJ document, its tile data stored as [encoding] says:
  /// [TiledDataEncoding.csv] writes number arrays.
  static String write(
    TiledMap map, {
    TiledDataEncoding encoding = TiledDataEncoding.csv,
    String tiledVersion = '1.10.2',
  }) => const JsonEncoder.withIndent(
    ' ',
  ).convert(toJson(map, encoding: encoding, tiledVersion: tiledVersion));

  /// [map] as a TMJ object.
  static Map<String, dynamic> toJson(
    TiledMap map, {
    TiledDataEncoding encoding = TiledDataEncoding.csv,
    String tiledVersion = '1.10.2',
  }) => {
    if (map.backgroundColor != null)
      'backgroundcolor': tiledColor(map.backgroundColor!),
    if (map.className.isNotEmpty) 'class': map.className,
    'compressionlevel': -1,
    'height': map.height,
    if (map.hexSideLength != null) 'hexsidelength': map.hexSideLength,
    'infinite': map.infinite,
    'layers': [for (final l in map.layers) ?_layer(l, encoding)],
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
  static String writeTileset(
    Tileset tileset, {
    String tiledVersion = '1.10.2',
  }) => const JsonEncoder.withIndent(' ').convert({
    ...tilesetToJson(tileset),
    'tiledversion': tiledVersion,
    'type': 'tileset',
    'version': tmxFormatVersion,
  });

  /// [ts] as a tileset object; with [firstGid] when embedded in a map.
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
      if (ids.isNotEmpty) 'tiles': [for (final id in ids) _tile(ts.tiles[id]!)],
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

  static Map<String, dynamic>? _layer(Layer l, TiledDataEncoding encoding) {
    switch (l) {
      case TileLayer():
        Object data(Uint32List gids) {
          if (encoding == TiledDataEncoding.csv) return [...gids];
          final bytes = TiledGid.toBytes(gids);
          return base64Encode(switch (encoding) {
            TiledDataEncoding.base64Zlib => const ZlibCodec().encode(bytes),
            TiledDataEncoding.base64Gzip => const GzipCodec().encode(bytes),
            _ => bytes,
          });
        }
        return {
          ..._common(l),
          if (l.isChunked)
            'chunks': [
              for (final c in l.chunks)
                {
                  'data': data(c.gids),
                  'height': c.height,
                  'width': c.width,
                  'x': c.x,
                  'y': c.y,
                },
            ]
          else
            'data': data(l.gids),
          if (encoding == TiledDataEncoding.base64Zlib) 'compression': 'zlib',
          if (encoding == TiledDataEncoding.base64Gzip) 'compression': 'gzip',
          if (encoding != TiledDataEncoding.csv) 'encoding': 'base64',
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
          'layers': [for (final c in l.layers) ?_layer(c, encoding)],
          'type': 'group',
        };
      default:
        return null;
    }
  }

  /// An object: in full, or, placed from a loaded template, its id,
  /// template and position, and what it sets itself.
  static Map<String, dynamic> _object(TiledObject o) {
    final t = o.template;
    final properties = ownProperties(o);
    final shape = t == null || !sameShape(o, t);
    return {
      if (shape && o.isEllipse) 'ellipse': true,
      if (o.gid != null && o.gid != t?.gid) 'gid': o.gid!.toUnsigned(32),
      if (t == null || o.height != t.height || o.width != t.width)
        'height': o.height,
      'id': o.id,
      if (t == null || o.name != t.name) 'name': o.name,
      if (shape && o.isPoint) 'point': true,
      if (shape && o.polygon != null)
        'polygon': [
          for (final p in o.polygon!) {'x': p.dx, 'y': p.dy},
        ],
      if (shape && o.polyline != null)
        'polyline': [
          for (final p in o.polyline!) {'x': p.dx, 'y': p.dy},
        ],
      if (properties.isNotEmpty) 'properties': _properties(properties),
      if (t == null || o.rotation != t.rotation) 'rotation': o.rotation,
      'template': ?o.templatePath,
      if (o.text != null && o.text != t?.text) 'text': {'text': o.text},
      if (t == null || o.type != t.type) 'type': o.type,
      if (t == null || o.visible != t.visible) 'visible': o.visible,
      if (t == null || o.height != t.height || o.width != t.width)
        'width': o.width,
      'x': o.x,
      'y': o.y,
    };
  }

  static List<Map<String, dynamic>> _properties(TiledProperties p) => [
    for (final key in p.keys)
      {
        'name': key,
        'propertytype': ?p.propertyTypeOf(key),
        'type': p.typeOf(key),
        'value': _propertyValue(p[key]),
      },
  ];

  /// A property's value as TMJ writes it: a colour as its notation, a
  /// class's members as an object of their values.
  static Object? _propertyValue(Object? value) => switch (value) {
    final Color c => tiledColor(c),
    final TiledProperties members => {
      for (final key in members.keys) key: _propertyValue(members[key]),
    },
    _ => value,
  };
}
