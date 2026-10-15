/// Tiled object and custom properties models.
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

/// A Tiled map object (from <object> elements).
class TiledObject {
  /// Unique object ID.
  final int id;

  /// Object name.
  final String name;

  /// Object type/class name.
  final String type;

  /// X position in pixels.
  final double x;

  /// Y position in pixels.
  final double y;

  /// Width in pixels.
  final double width;

  /// Height in pixels.
  final double height;

  /// Rotation in degrees (clockwise).
  final double rotation;

  /// Global tile ID (if this object is a tile object).
  final int? gid;

  /// Whether this object is visible.
  final bool visible;

  /// Template file path (if this object uses a template).
  final String? templatePath;

  /// Polygon points (relative to x,y). Null if not a polygon.
  final List<Offset>? polygon;

  /// Polyline points (relative to x,y). Null if not a polyline.
  final List<Offset>? polyline;

  /// Whether this is an ellipse shape.
  final bool isEllipse;

  /// Whether this is a point object.
  final bool isPoint;

  /// Text content (if this is a text object).
  final String? text;

  /// Custom properties.
  final TiledProperties properties;

  /// An object; [id] is unique within the map.
  const TiledObject({
    required this.id,
    this.name = '',
    this.type = '',
    this.x = 0,
    this.y = 0,
    this.width = 0,
    this.height = 0,
    this.rotation = 0,
    this.gid,
    this.visible = true,
    this.templatePath,
    this.polygon,
    this.polyline,
    this.isEllipse = false,
    this.isPoint = false,
    this.text,
    TiledProperties? properties,
  }) : properties = properties ?? const TiledProperties();
}
