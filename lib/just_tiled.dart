/// Read and write Tiled files (TMX, TSX, TX; TMJ, TSJ, TJ) and draw their
/// tile layers with `Canvas.drawRawAtlas`.
///
/// No game-engine dependency: `just_game_engine` uses it for its Tiled
/// import and export.
///
/// ## Quick Start
///
/// ```dart
/// import 'package:just_tiled/just_tiled.dart';
///
/// // Parse a TMX file
/// final tmxXml = await rootBundle.loadString('assets/maps/level1.tmx');
/// final map = await TmxParser.parse(
///   tmxXml,
///   fileProvider: const AssetTiledFileProvider(basePath: 'assets/maps'),
/// );
///
/// // Access tile layers
/// for (final layer in map.tileLayers) {
///   print('${layer.name}: ${layer.width}x${layer.height}');
/// }
/// ```
library;

// The models every reader produces and every writer takes.
export 'src/models/models.dart';

// Where external tilesets and templates come from.
export 'src/files/files.dart';

// TMX and TMJ, read and written.
export 'src/formats/formats.dart';

// Drawing tile layers.
export 'src/rendering/rendering.dart';
