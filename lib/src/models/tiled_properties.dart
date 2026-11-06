/// Custom properties model.
library;

import 'dart:ui';

/// Typed custom properties from Tiled's properties tags.
///
/// A value is a `String` (`string` and `file` properties), an `int` (`int`
/// and `object`), a `double` (`float`), a `bool`, a [Color] (or null for a
/// `color` left empty), or, for a `class` property, the class's members as
/// another [TiledProperties].
class TiledProperties {
  final Map<String, dynamic> _values;
  final Map<String, String> _types;
  final Map<String, String> _propertyTypes;

  /// [types] records each property's declared Tiled type (`string`, `int`,
  /// `float`, `bool`, `color`, `file`, `object`, `class`) where the value
  /// alone cannot say — a `file` is a string, an `object` an int — so a
  /// writer can give it back as it was. [propertyTypes] records the custom
  /// type (Tiled 1.8+) of a property that has one: an enum's or a class's
  /// name.
  const TiledProperties([
    Map<String, dynamic>? values,
    Map<String, String>? types,
    Map<String, String>? propertyTypes,
  ]) : _values = values ?? const {},
       _types = types ?? const {},
       _propertyTypes = propertyTypes ?? const {};

  /// All property keys.
  Iterable<String> get keys => _values.keys;

  /// The Tiled type of [key]: as declared, or read from the value.
  String typeOf(String key) {
    final declared = _types[key];
    if (declared != null) return declared;
    final v = _values[key];
    if (v is bool) return 'bool';
    if (v is int) return 'int';
    if (v is double) return 'float';
    if (v is Color) return 'color';
    if (v is TiledProperties) return 'class';
    return 'string';
  }

  /// The custom type of [key] — the name of the enum or class it was
  /// declared with in Tiled's custom types (Tiled 1.8+) — or null.
  String? propertyTypeOf(String key) => _propertyTypes[key];

  /// A `class` property's members, or null if [key] is not one.
  TiledProperties? getClass(String key) {
    final v = _values[key];
    return v is TiledProperties ? v : null;
  }

  /// Whether a property exists.
  bool has(String key) => _values.containsKey(key);

  /// Get a string property.
  String? getString(String key) {
    final v = _values[key];
    return v is String ? v : v?.toString();
  }

  /// Get an integer property.
  int? getInt(String key) {
    final v = _values[key];
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
  }

  /// Get a double property.
  double? getDouble(String key) {
    final v = _values[key];
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  /// Get a boolean property.
  bool? getBool(String key) {
    final v = _values[key];
    if (v is bool) return v;
    if (v is String) return v.toLowerCase() == 'true';
    return null;
  }

  /// Get the raw dynamic value.
  dynamic operator [](String key) => _values[key];

  /// Get the underlying map.
  Map<String, dynamic> toMap() => Map.unmodifiable(_values);

  /// Whether properties are empty.
  bool get isEmpty => _values.isEmpty;

  /// Whether properties are not empty.
  bool get isNotEmpty => _values.isNotEmpty;

  @override
  String toString() => 'TiledProperties($_values)';
}
