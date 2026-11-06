/// Where a map's external files come from: its tilesets and templates.
library;

import 'package:flutter/services.dart' show rootBundle;

import 'tiled_paths.dart';

/// Loads the files a map refers to: external tilesets (TSX, TSJ) and
/// object templates (TX, TJ).
///
/// Implement this to load them from anywhere else: the file system, the
/// network, another asset bundle.
abstract class TiledFileProvider {
  /// Lets subclasses be const.
  const TiledFileProvider();

  /// The text of the external tileset at [source]: TSX, or TSJ (`.tsj` or
  /// `.json`), which the readers tell apart by the file ending.
  ///
  /// [source] is the path as written in the map's tileset `source`: relative
  /// to the map file.
  Future<String> loadTileset(String source);

  /// The text of the object template at [source]: TX, or TJ (`.tj` or
  /// `.json`), which the readers tell apart by the file ending.
  ///
  /// [source] is the path as written in the object's `template`: relative
  /// to the map file.
  Future<String> loadTemplate(String source);
}

/// A [TiledFileProvider] that loads from Flutter's asset bundle.
///
/// Expects tileset and template files to be declared in pubspec.yaml assets.
class AssetTiledFileProvider implements TiledFileProvider {
  /// The folder the map is in, as an asset path: the paths in the map are
  /// read relative to it.
  final String basePath;

  /// Create a provider for maps in the asset folder [basePath].
  ///
  /// For example, for a map at `assets/maps/level1.tmx` whose tilesets are
  /// `../tilesets/terrain.tsx`, set [basePath] to `assets/maps`; the
  /// tileset loads from `assets/tilesets/terrain.tsx`.
  const AssetTiledFileProvider({this.basePath = ''});

  @override
  Future<String> loadTileset(String source) =>
      rootBundle.loadString(resolve(source));

  @override
  Future<String> loadTemplate(String source) =>
      rootBundle.loadString(resolve(source));

  /// The asset key [source], a path from the map, loads from: [basePath]
  /// and [source] joined, with `\` read as `/` and `.` and `..` collapsed.
  ///
  /// A [source] that starts with `assets/` or `/` is taken from the root of
  /// the asset bundle instead, without [basePath].
  String resolve(String source) {
    final path = source.replaceAll('\\', '/');
    if (path.startsWith('/') ||
        path.startsWith('assets/') ||
        basePath.isEmpty) {
      return normalizePath(path);
    }
    return normalizePath('$basePath/$path');
  }
}
