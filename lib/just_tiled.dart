/// Tiled Map Editor integration for just_game_engine.
///
/// Provides robust, hardware-accelerated support for the Tiled Map Editor
/// (TMX/TSX formats). This package is standalone and does not depend on
/// just_game_engine — ECS integration is provided by the engine itself.
///
/// ## Quick Start
///
/// ```dart
/// import 'package:just_tiled/just_tiled.dart';
///
/// // Parse a TMX file
/// final tmxXml = await rootBundle.loadString('assets/maps/level1.tmx');
/// final map = await TileMapParser.parse(tmxXml);
///
/// // Access tile layers
/// for (final layer in map.tileLayers) {
///   print('${layer.name}: ${layer.width}x${layer.height}');
/// }
/// ```
library;

// Data models
export 'src/models/models.dart';

// TMX parser
export 'src/parser/parser.dart';

// Rendering pipeline
export 'src/rendering/rendering.dart';

// Spatial optimization
export 'src/spatial/spatial.dart';
