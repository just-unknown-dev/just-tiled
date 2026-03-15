/// TSX/TX provider interface for resolving external tileset and template files.
library;

import 'package:flutter/services.dart' show rootBundle;

/// Dependency injection interface for loading external .tsx tileset files
/// and .tx object template files.
///
/// Implement this to provide custom file resolution (e.g., from network,
/// file system, or custom asset bundle).
abstract class TsxProvider {
  /// Resolve and load an external .tsx tileset file.
  ///
  /// [source] is the path/URI as written in the TMX <tileset> element's
  /// `source` attribute.
  ///
  /// Returns the raw XML string content of the .tsx file.
  Future<String> getTsx(String source);

  /// Resolve and load an external .tx template file.
  ///
  /// [source] is the path/URI as written in the <object> element's
  /// `template` attribute.
  ///
  /// Returns the raw XML string content of the .tx file.
  Future<String> getTemplate(String source);
}

/// Default [TsxProvider] that loads from Flutter's asset bundle.
///
/// Expects tileset and template files to be declared in pubspec.yaml assets.
class DefaultTsxProvider implements TsxProvider {
  /// Base path prefix for asset resolution.
  final String basePath;

  /// Create a provider with an optional [basePath] prefix.
  ///
  /// For example, if your TMX files are in `assets/maps/` and reference
  /// tilesets as `../tilesets/terrain.tsx`, set [basePath] to `assets/`.
  const DefaultTsxProvider({this.basePath = ''});

  @override
  Future<String> getTsx(String source) async {
    final path = _resolvePath(source);
    return await rootBundle.loadString(path);
  }

  @override
  Future<String> getTemplate(String source) async {
    final path = _resolvePath(source);
    return await rootBundle.loadString(path);
  }

  String _resolvePath(String source) {
    if (source.startsWith('/') || source.startsWith('assets/')) {
      return source;
    }
    final resolved = basePath.isEmpty ? source : '$basePath/$source';
    // Normalize path separators
    return resolved.replaceAll('\\', '/');
  }
}
