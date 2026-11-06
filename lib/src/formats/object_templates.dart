/// Object templates: loaded once per map through its file provider, as TX
/// or TJ, their tile renumbered for the map. Both readers use them.
library;

import 'package:meta/meta.dart';

import '../files/tiled_file_provider.dart';
import '../files/tiled_paths.dart';
import '../models/models.dart';
import 'tmj/tmj_parser.dart';
import 'tmx/tmx_parser.dart';

/// A template file as read: its object, whose gid is numbered from the
/// template's own external tileset, [tilesetSource] (relative to the
/// template file) at [tilesetFirstGid].
@internal
final class TemplateFile {
  /// A template of [object].
  const TemplateFile(
    this.object, {
    this.tilesetSource,
    this.tilesetFirstGid = 1,
  });

  /// The template's object.
  final TiledObject object;

  /// The tileset its gid is numbered from, if it names one.
  final String? tilesetSource;

  /// The first gid that tileset has in the template.
  final int tilesetFirstGid;
}

/// The templates one map's objects are placed from, each loaded once.
@internal
final class TemplateLoader {
  /// Loads through [provider], for a map holding [tilesets].
  TemplateLoader(this._provider, this._tilesets);

  final TiledFileProvider? _provider;
  final List<Tileset> _tilesets;
  final _loaded = <String, Future<TiledObject?>>{};

  /// The object of the template at [path] (as the map writes it), its gid
  /// numbered for the map. Null without a provider, or when the file can't
  /// be loaded or read: the object then keeps only its own values.
  Future<TiledObject?> load(String path) => _loaded[path] ??= _load(path);

  Future<TiledObject?> _load(String path) async {
    final provider = _provider;
    if (provider == null) return null;
    try {
      final text = await provider.loadTemplate(path);
      final file = isJsonFile(path)
          ? TmjParser.parseTemplate(text)
          : TmxParser.parseTemplate(text);
      final o = file.object;
      final gid = o.gid;
      if (gid == null) return o;
      return TiledObject(
        id: o.id,
        name: o.name,
        type: o.type,
        x: o.x,
        y: o.y,
        width: o.width,
        height: o.height,
        rotation: o.rotation,
        gid: _renumbered(gid, file, path),
        visible: o.visible,
        polygon: o.polygon,
        polyline: o.polyline,
        isEllipse: o.isEllipse,
        isPoint: o.isPoint,
        text: o.text,
        properties: o.properties,
      );
    } catch (e, st) {
      // The template can't be had: degrade to the instance's own values.
      assert(() {
        // ignore: avoid_print
        print('just_tiled: failed to load template "$path": $e\n$st');
        return true;
      }());
      return null;
    }
  }

  /// The template's tile gid [raw], flags kept, renumbered for the map.
  ///
  /// A template numbers its tile from its own `tileset`, an external
  /// tileset given relative to the template file. The map holds that same
  /// tileset under its own first gid, so the id moves by the difference.
  /// [raw] as it is when the template names no tileset, or the map doesn't
  /// hold it.
  int _renumbered(int raw, TemplateFile file, String templatePath) {
    final source = file.tilesetSource;
    if (source == null) return raw;
    final path = resolveFrom(templatePath, source);
    for (final ts in _tilesets) {
      final mapSource = ts.source;
      if (mapSource == null || normalizePath(mapSource) != path) continue;
      return TiledGid.compose(
        TiledGid.idOf(raw) - file.tilesetFirstGid + ts.firstGid,
        TiledGid.flagsOf(raw),
      );
    }
    return raw;
  }
}

/// [instance] and [template]'s properties merged: the instance's win.
@internal
TiledProperties mergeProperties(
  TiledProperties template,
  TiledProperties instance,
) {
  if (template.isEmpty) return instance;
  final merged = <String, dynamic>{};
  final types = <String, String>{};
  final propertyTypes = <String, String>{};
  for (final from in [template, instance]) {
    for (final key in from.keys) {
      merged[key] = from[key];
      types[key] = from.typeOf(key);
      final propertyType = from.propertyTypeOf(key);
      if (propertyType != null) {
        propertyTypes[key] = propertyType;
      } else {
        propertyTypes.remove(key);
      }
    }
  }
  return TiledProperties(merged, types, propertyTypes);
}
