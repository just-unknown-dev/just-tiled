/// What an object placed from a template sets itself: all a writer gives
/// back, so the object goes on following its template in Tiled.
library;

import 'dart:ui';

import 'package:meta/meta.dart';

import '../models/models.dart';

/// The properties [object] sets itself: all of them, or, for an object
/// with a loaded [TiledObject.template], those the template lacks or holds
/// with another value or type.
@internal
TiledProperties ownProperties(TiledObject object) {
  final template = object.template;
  final p = object.properties;
  if (template == null) return p;
  final t = template.properties;
  final values = <String, dynamic>{};
  final types = <String, String>{};
  final propertyTypes = <String, String>{};
  for (final key in p.keys) {
    if (t.has(key) && _sameProperty(p, t, key)) continue;
    values[key] = p[key];
    types[key] = p.typeOf(key);
    final propertyType = p.propertyTypeOf(key);
    if (propertyType != null) propertyTypes[key] = propertyType;
  }
  return TiledProperties(values, types, propertyTypes);
}

bool _sameProperty(TiledProperties a, TiledProperties b, String key) =>
    a.typeOf(key) == b.typeOf(key) &&
    a.propertyTypeOf(key) == b.propertyTypeOf(key) &&
    _sameValue(a[key], b[key]);

bool _sameValue(Object? a, Object? b) {
  if (a is TiledProperties && b is TiledProperties) {
    if (a.keys.length != b.keys.length) return false;
    for (final key in a.keys) {
      if (!b.has(key) || !_sameProperty(a, b, key)) return false;
    }
    return true;
  }
  return a == b;
}

/// Whether [a] and [b] have the same shape: rectangle, ellipse, point,
/// polygon or polyline, with the same points.
@internal
bool sameShape(TiledObject a, TiledObject b) =>
    a.isEllipse == b.isEllipse &&
    a.isPoint == b.isPoint &&
    _samePoints(a.polygon, b.polygon) &&
    _samePoints(a.polyline, b.polyline);

bool _samePoints(List<Offset>? a, List<Offset>? b) {
  if (a == null || b == null) return a == b;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
