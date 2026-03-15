/// just_tiled example
///
/// Demonstrates parsing a Tiled TMX map, building texture atlases, rendering
/// tile layers onto a Flutter canvas, and querying map objects.
///
/// Prerequisites:
/// - Add a `.tmx` file (and any `.tsx` / image files it references) under
///   `assets/maps/` and declare the folder in `pubspec.yaml`:
///
/// ```yaml
/// flutter:
///   assets:
///     - assets/maps/
/// ```
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:just_tiled/just_tiled.dart';

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

void main() {
  runApp(const MaterialApp(home: TiledExamplePage()));
}

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

class TiledExamplePage extends StatefulWidget {
  const TiledExamplePage({super.key});

  @override
  State<TiledExamplePage> createState() => _TiledExamplePageState();
}

class _TiledExamplePageState extends State<TiledExamplePage> {
  _MapScene? _scene;
  String _status = 'Loading map…';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // 1. Parse the TMX file ------------------------------------------------
      //    DefaultTsxProvider resolves .tsx / template files from the asset
      //    bundle relative to the given basePath.
      final tmxXml = await rootBundle.loadString('assets/maps/desert.tmx');
      final map = await TileMapParser.parse(
        tmxXml,
        tsxProvider: const DefaultTsxProvider(basePath: 'assets/maps'),
      );

      // 2. Load tileset images and build texture atlases ---------------------
      final atlases = <TextureAtlas>[];
      for (final tileset in map.tilesets) {
        final imageSource = tileset.imageSource;
        if (imageSource == null) continue;

        final data = await rootBundle.load('assets/maps/$imageSource');
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        final frame = await codec.getNextFrame();
        atlases.add(TextureAtlas(image: frame.image, tileset: tileset));
      }
      final atlasCollection = TextureAtlasCollection(atlases);

      // 3. Create one TileMapRenderer per tile layer -------------------------
      //    compile() converts the layer into Float32List buffers that are
      //    rendered with a single Canvas.drawRawAtlas call.
      final renderers = <TileMapRenderer>[];
      for (final layer in map.tileLayers) {
        // Find the atlas that covers the GIDs used in this layer.
        final atlas = atlasCollection.atlases.firstOrNull;
        if (atlas == null) continue;

        final renderer = TileMapRenderer(
          tileLayer: layer,
          map: map,
          atlas: atlas,
        );
        renderer.compile();
        renderers.add(renderer);
      }

      // 4. Log map info and objects ------------------------------------------
      debugPrint(
        'Map: ${map.width}x${map.height} tiles '
        '(${map.pixelWidth}x${map.pixelHeight} px), '
        'orientation: ${map.orientation}',
      );

      for (final group in map.objectGroups) {
        for (final obj in group.objects) {
          debugPrint(
            'Object "${obj.name}" (${obj.type}) '
            'at (${obj.x.toStringAsFixed(0)}, ${obj.y.toStringAsFixed(0)})',
          );
        }
      }

      // 5. Read a custom map property ----------------------------------------
      if (map.properties.has('gravity')) {
        final gravity = map.properties.getDouble('gravity');
        debugPrint('Custom gravity: $gravity');
      }

      // 6. Use the spatial hash grid to index objects -----------------------
      final grid = SpatialHashGrid<TiledObject>(cellSize: 128);
      for (final obj in map.objectGroups.expand((g) => g.objects)) {
        grid.insert(obj, Rect.fromLTWH(obj.x, obj.y, obj.width, obj.height));
      }
      // Query objects near the origin (e.g., camera viewport).
      final nearby = grid.query(const Rect.fromLTWH(0, 0, 512, 512));
      debugPrint('Objects near origin: ${nearby.length}');

      if (mounted) {
        setState(() {
          _scene = _MapScene(map: map, renderers: renderers);
          _status = '${map.tileLayers.length} layer(s) rendered';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _status = 'Error: $e');
      }
    }
  }

  @override
  void dispose() {
    _scene?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('just_tiled Example'),
        backgroundColor: Colors.black87,
      ),
      body: _scene == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(_status, style: const TextStyle(color: Colors.white)),
                ],
              ),
            )
          : Stack(
              children: [
                CustomPaint(
                  painter: _TileMapPainter(scene: _scene!),
                  child: const SizedBox.expand(),
                ),
                Positioned(
                  bottom: 16,
                  left: 16,
                  child: Text(
                    _status,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Scene container
// ---------------------------------------------------------------------------

class _MapScene {
  final TiledMap map;
  final List<TileMapRenderer> renderers;

  _MapScene({required this.map, required this.renderers});

  void dispose() {
    for (final r in renderers) {
      r.atlas.dispose();
    }
  }
}

// ---------------------------------------------------------------------------
// Painter
// ---------------------------------------------------------------------------

class _TileMapPainter extends CustomPainter {
  final _MapScene scene;

  const _TileMapPainter({required this.scene});

  @override
  void paint(Canvas canvas, Size size) {
    // Simple camera: centre the map in the viewport.
    final mapPixelW = scene.map.pixelWidth.toDouble();
    final mapPixelH = scene.map.pixelHeight.toDouble();
    final cameraOffset = Offset(
      (size.width - mapPixelW) / 2,
      (size.height - mapPixelH) / 2,
    );
    final visibleBounds = Rect.fromLTWH(0, 0, size.width, size.height);

    for (final renderer in scene.renderers) {
      renderer.render(canvas, cameraOffset, visibleBounds);
    }
  }

  @override
  bool shouldRepaint(covariant _TileMapPainter old) => false;
}
