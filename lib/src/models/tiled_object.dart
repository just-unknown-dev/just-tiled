/// Tiled map object model.
library;

import 'dart:ui';

import 'tiled_properties.dart';

/// A Tiled map object (from <object> elements).
///
/// An object placed from a template (a TX or TJ file) holds the template's
/// values merged with its own: what the instance doesn't set, it takes
/// from the template. [template] keeps the template's object, so a writer
/// gives back only what the instance sets itself.
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

  /// Global tile ID (if this object is a tile object), flags kept: see
  /// `TiledGid`.
  final int? gid;

  /// Whether this object is visible.
  final bool visible;

  /// Template file path (if this object uses a template), as the map
  /// writes it: relative to the map file.
  final String? templatePath;

  /// The object of the template at [templatePath], as loaded: what this
  /// object inherits. Its gid is numbered for the map. Null when the object
  /// has no template, or the template wasn't loaded (no file provider, or
  /// the file couldn't be read); the object then holds only its own values.
  final TiledObject? template;

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
    this.template,
    this.polygon,
    this.polyline,
    this.isEllipse = false,
    this.isPoint = false,
    this.text,
    TiledProperties? properties,
  }) : properties = properties ?? const TiledProperties();
}
