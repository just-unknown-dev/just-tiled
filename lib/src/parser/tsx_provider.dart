/// TSX/TX provider interface for resolving external tileset and template files.
library;

import 'package:flutter/services.dart' show rootBundle;

import 'paths.dart';

/// Dependency injection interface for loading external .tsx tileset files
/// and .tx object template files.
///
/// Implement this to provide custom file resolution (e.g., from network,
/// file system, or custom asset bundle).
abstract class TsxProvider {
  /// Lets subclasses be const.
  const TsxProvider();

  /// Resolve and load an external tileset file: TSX, or TSJ (`.tsj` or
  /// `.json`), which the parsers tell apart by the file ending.
  ///
  /// [source] is the path as written in the map's tileset `source`
  /// attribute: relative to the map file.
  ///
  /// Returns the file's text.
  Future<String> getTsx(String source);

  /// Resolve and load an external .tx template file.
  ///
  /// [source] is the path as written in the object's `template` attribute:
  /// relative to the map file.
  ///
  /// Returns the raw XML string content of the .tx file.
  Future<String> getTemplate(String source);
}

/// Default [TsxProvider] that loads from Flutter's asset bundle.
///
/// Expects tileset and template files to be declared in pubspec.yaml assets.
class DefaultTsxProvider implements TsxProvider {
  /// The folder the map is in, as an asset path: the paths in the map are
  /// read relative to it.
  final String basePath;

  /// Create a provider for maps in the asset folder [basePath].
  ///
  /// For example, for a map at `assets/maps/level1.tmx` whose tilesets are
  /// `../tilesets/terrain.tsx`, set [basePath] to `assets/maps`; the
  /// tileset loads from `assets/tilesets/terrain.tsx`.
  const DefaultTsxProvider({this.basePath = ''});

  @override
  Future<String> getTsx(String source) =>
      rootBundle.loadString(resolve(source));

  @override
  Future<String> getTemplate(String source) =>
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
