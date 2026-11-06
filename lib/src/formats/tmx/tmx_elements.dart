/// The XML elements the TMX and TSX writers share.
library;

import 'dart:ui';

import 'package:meta/meta.dart';
import 'package:xml/xml.dart';

import '../../files/tiled_notation.dart';
import '../../models/models.dart';
import '../template_overrides.dart';

/// Pretty-prints [builder]'s document, leaving the text of tile data,
/// chunks, text objects and multi-line properties exactly as written.
@internal
String prettyXml(XmlBuilder builder) => builder.buildDocument().toXmlString(
  pretty: true,
  indent: ' ',
  preserveWhitespace: (node) =>
      node is XmlElement &&
      (const {'data', 'chunk', 'text'}.contains(node.name.local) ||
          (node.name.local == 'property' &&
              node.getElement('properties') == null)),
);

void _attr(XmlBuilder b, String name, Object? value) {
  if (value == null) return;
  b.attribute(name, value is num ? tiledNum(value) : '$value');
}

/// `<properties>`, when there are any. A `class` property's members are
/// written as its own nested `<properties>`.
@internal
void writeProperties(XmlBuilder b, TiledProperties properties) {
  if (properties.isEmpty) return;
  b.element(
    'properties',
    nest: () {
      for (final key in properties.keys) {
        final type = properties.typeOf(key);
        final propertyType = properties.propertyTypeOf(key);
        final value = properties[key];
        if (value is TiledProperties) {
          b.element(
            'property',
            nest: () {
              b.attribute('name', key);
              b.attribute('type', 'class');
              if (propertyType != null) {
                b.attribute('propertytype', propertyType);
              }
              writeProperties(b, value);
            },
          );
          continue;
        }
        final text = switch (value) {
          final Color c => tiledColor(c),
          final bool v => v ? 'true' : 'false',
          final num v => tiledNum(v),
          null => '',
          _ => '$value',
        };
        b.element(
          'property',
          nest: () {
            b.attribute('name', key);
            if (type != 'string') b.attribute('type', type);
            if (propertyType != null) {
              b.attribute('propertytype', propertyType);
            }
            // A multi-line string is written as text, as Tiled does.
            if (text.contains('\n')) {
              b.text(text);
            } else {
              b.attribute('value', text);
            }
          },
        );
      }
    },
  );
}

/// One `<object>`. An object placed from a loaded template is written as
/// Tiled writes one: its id, template and position, then only what it
/// sets itself.
@internal
void writeObject(XmlBuilder b, TiledObject o) {
  final t = o.template;
  b.element(
    'object',
    nest: () {
      _attr(b, 'id', o.id);
      if (o.templatePath != null) _attr(b, 'template', o.templatePath);
      if (t == null ? o.name.isNotEmpty : o.name != t.name) {
        _attr(b, 'name', o.name);
      }
      if (t == null ? o.type.isNotEmpty : o.type != t.type) {
        _attr(b, 'type', o.type);
      }
      if (o.gid != null && o.gid != t?.gid) {
        _attr(b, 'gid', o.gid!.toUnsigned(32));
      }
      _attr(b, 'x', o.x);
      _attr(b, 'y', o.y);
      if (t == null) {
        if (o.width != 0) _attr(b, 'width', o.width);
        if (o.height != 0) _attr(b, 'height', o.height);
      } else if (o.width != t.width || o.height != t.height) {
        _attr(b, 'width', o.width);
        _attr(b, 'height', o.height);
      }
      if (o.rotation != (t?.rotation ?? 0)) _attr(b, 'rotation', o.rotation);
      if (o.visible != (t?.visible ?? true)) {
        _attr(b, 'visible', o.visible ? 1 : 0);
      }
      writeProperties(b, ownProperties(o));
      if (t == null || !sameShape(o, t)) {
        if (o.isEllipse) b.element('ellipse');
        if (o.isPoint) b.element('point');
        if (o.polygon != null) {
          b.element('polygon', attributes: {'points': _points(o.polygon!)});
        }
        if (o.polyline != null) {
          b.element('polyline', attributes: {'points': _points(o.polyline!)});
        }
      }
      if (o.text != null && o.text != t?.text) b.element('text', nest: o.text);
    },
  );
}

String _points(List<Offset> points) =>
    points.map((p) => '${tiledNum(p.dx)},${tiledNum(p.dy)}').join(' ');

/// A whole `<tileset>` element: embedded in a map when [firstGid] is given,
/// the root of a TSX file otherwise.
@internal
void writeTilesetElement(
  XmlBuilder b,
  Tileset ts, {
  int? firstGid,
  String? version,
  String? tiledVersion,
}) {
  b.element(
    'tileset',
    nest: () {
      if (firstGid != null) _attr(b, 'firstgid', firstGid);
      if (version != null) _attr(b, 'version', version);
      if (tiledVersion != null) _attr(b, 'tiledversion', tiledVersion);
      _attr(b, 'name', ts.name);
      if (ts.className.isNotEmpty) _attr(b, 'class', ts.className);
      _attr(b, 'tilewidth', ts.tileWidth);
      _attr(b, 'tileheight', ts.tileHeight);
      if (ts.spacing != 0) _attr(b, 'spacing', ts.spacing);
      if (ts.margin != 0) _attr(b, 'margin', ts.margin);
      _attr(b, 'tilecount', ts.tileCount);
      _attr(b, 'columns', ts.columns);
      if (ts.objectAlignment != ObjectAlignment.unspecified) {
        _attr(b, 'objectalignment', ts.objectAlignment.name);
      }
      if (ts.tileRenderSize != TileRenderSize.tile) {
        _attr(b, 'tilerendersize', ts.tileRenderSize.name);
      }
      if (ts.fillMode != FillMode.stretch) {
        _attr(b, 'fillmode', ts.fillMode.tmxValue);
      }
      if (ts.tileOffset != Offset.zero) {
        b.element(
          'tileoffset',
          attributes: {
            'x': tiledNum(ts.tileOffset.dx),
            'y': tiledNum(ts.tileOffset.dy),
          },
        );
      }
      final grid = ts.grid;
      if (grid != null) {
        b.element(
          'grid',
          attributes: {
            'orientation': grid.orientation.name,
            'width': '${grid.width}',
            'height': '${grid.height}',
          },
        );
      }
      writeProperties(b, ts.properties);
      if (ts.imageSource != null) {
        b.element(
          'image',
          nest: () {
            _attr(b, 'source', ts.imageSource);
            // A colour key is written bare: `ff00ff`, no `#`, no alpha.
            if (ts.transparentColor case final key?) {
              _attr(
                b,
                'trans',
                (key.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0'),
              );
            }
            _attr(b, 'width', ts.imageWidth);
            _attr(b, 'height', ts.imageHeight);
          },
        );
      }
      final t = ts.transformations;
      if (t.any) {
        b.element(
          'transformations',
          attributes: {
            'hflip': t.hflip ? '1' : '0',
            'vflip': t.vflip ? '1' : '0',
            'rotate': t.rotate ? '1' : '0',
            'preferuntransformed': t.preferUntransformed ? '1' : '0',
          },
        );
      }
      final ids = ts.tiles.keys.toList()..sort();
      for (final id in ids) {
        _writeTile(b, ts.tiles[id]!);
      }
      if (ts.wangSets.isNotEmpty) {
        b.element(
          'wangsets',
          nest: () {
            for (final set in ts.wangSets) {
              _writeWangSet(b, set);
            }
          },
        );
      }
    },
  );
}

void _writeTile(XmlBuilder b, Tile tile) {
  b.element(
    'tile',
    nest: () {
      _attr(b, 'id', tile.id);
      if (tile.type != null && tile.type!.isNotEmpty) {
        _attr(b, 'type', tile.type);
      }
      if (tile.probability != 1) _attr(b, 'probability', tile.probability);
      writeProperties(b, tile.properties);
      if (tile.imageSource != null) {
        b.element(
          'image',
          nest: () {
            _attr(b, 'width', tile.imageWidth);
            _attr(b, 'height', tile.imageHeight);
            _attr(b, 'source', tile.imageSource);
          },
        );
      }
      if (tile.objectGroup.isNotEmpty) {
        b.element(
          'objectgroup',
          attributes: {'draworder': 'index'},
          nest: () {
            for (final o in tile.objectGroup) {
              writeObject(b, o);
            }
          },
        );
      }
      if (tile.animation.isNotEmpty) {
        b.element(
          'animation',
          nest: () {
            for (final frame in tile.animation) {
              b.element(
                'frame',
                attributes: {
                  'tileid': '${frame.tileId}',
                  'duration': '${frame.duration}',
                },
              );
            }
          },
        );
      }
    },
  );
}

void _writeWangSet(XmlBuilder b, WangSet set) {
  b.element(
    'wangset',
    nest: () {
      _attr(b, 'name', set.name);
      if (set.className.isNotEmpty) _attr(b, 'class', set.className);
      _attr(b, 'type', set.type.name);
      _attr(b, 'tile', set.tile);
      writeProperties(b, set.properties);
      for (final color in set.colors) {
        b.element(
          'wangcolor',
          nest: () {
            _attr(b, 'name', color.name);
            if (color.className.isNotEmpty) {
              _attr(b, 'class', color.className);
            }
            _attr(b, 'color', tiledColor(color.color));
            _attr(b, 'tile', color.tile);
            _attr(b, 'probability', color.probability);
            writeProperties(b, color.properties);
          },
        );
      }
      final ids = set.wangTiles.keys.toList()..sort();
      for (final id in ids) {
        b.element(
          'wangtile',
          attributes: {'tileid': '$id', 'wangid': set.wangTiles[id]!.join(',')},
        );
      }
    },
  );
}
