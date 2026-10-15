/// just_tiled example
///
/// Reads a Tiled map (TMX or TMJ), loads its tileset images, draws its tile
/// layers on a Flutter canvas you can drag around, and shows the map's
/// objects, properties, raw tile ids and the writers.
///
/// Prerequisites:
/// - Put a `.tmx` or `.tmj` map, and the tilesets and images it uses, under
///   `assets/` and declare the folders in `pubspec.yaml`:
///
/// ```yaml
/// flutter:
///   assets:
///     - assets/maps/
/// ```
///
/// - Set [mapPath] below to your map.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:just_tiled/just_tiled.dart';

/// The map to show. A `.tmj` file is read with [TmjParser], anything else
/// with [TileMapParser].
const mapPath = 'assets/maps/desert.tmx';

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

  /// How far the map has been dragged from the centre of the screen.
  Offset _pan = Offset.zero;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // 1. Parse the map ----------------------------------------------------
      //    The provider loads external tilesets (.tsx / .tsj) and object
      //    templates from the asset bundle, reading their paths from the
      //    map's folder, `../` included.
      final text = await rootBundle.loadString(mapPath);
      final provider = DefaultTsxProvider(
        basePath: mapPath.substring(0, mapPath.lastIndexOf('/')),
      );
      final map = mapPath.endsWith('.tmj')
          ? await TmjParser.parse(text, tsxProvider: provider)
          : await TileMapParser.parse(text, tsxProvider: provider);

      // 2. Load tileset images and build texture atlases ---------------------
      //    An image path is relative to the file that declares the tileset:
      //    the map, or the external tileset file. Image-collection tilesets
      //    have no single image and are skipped.
      final atlases = <TextureAtlas>[];
      for (final tileset in map.tilesets) {
        final imageSource = tileset.imageSource;
        if (imageSource == null) continue;

        final declaredIn = tileset.source == null
            ? mapPath
            : _resolve(mapPath, tileset.source!);
        final image = await _loadImage(_resolve(declaredIn, imageSource));
        atlases.add(TextureAtlas(image: image, tileset: tileset));
      }

      // 3. Create the renderers ---------------------------------------------
      //    A renderer draws one layer's tiles from one atlas, so a layer that
      //    uses several tilesets gets one per atlas. compile() turns the
      //    layer — finite, or an infinite map's chunks — into the buffers of
      //    a single Canvas.drawRawAtlas call. Hidden layers are skipped.
      final renderers = [
        for (final layer in map.tileLayers)
          if (layer.visible)
            for (final atlas in atlases)
              TileMapRenderer(map: map, tileLayer: layer, atlas: atlas)
                ..compile(),
      ];

      // 4. Log the map and its layers ----------------------------------------
      debugPrint(
        'Map: ${map.width}x${map.height} tiles '
        '(${map.pixelWidth}x${map.pixelHeight} px), '
        '${map.orientation.name}${map.infinite ? ', infinite' : ''}',
      );
      for (final layer in map.tileLayers) {
        debugPrint(
          layer.isChunked
              ? 'Layer "${layer.name}": ${layer.chunks.length} chunk(s)'
              : 'Layer "${layer.name}": ${layer.width}x${layer.height}',
        );
      }

      // 5. Log the objects ---------------------------------------------------
      //    A tile object's gid is raw: TiledGid takes the flags off.
      for (final group in map.objectGroups) {
        for (final obj in group.objects) {
          final gid = obj.gid;
          debugPrint(
            'Object "${obj.name}" (${obj.type}) '
            'at (${obj.x.toStringAsFixed(0)}, ${obj.y.toStringAsFixed(0)})'
            '${gid == null ? '' : ', tile ${TiledGid.idOf(gid)}'}'
            '${gid != null && TiledGid.isFlippedHorizontally(gid) ? ', mirrored' : ''}',
          );
        }
      }

      // 6. Read a custom map property ----------------------------------------
      if (map.properties.has('gravity')) {
        final gravity = map.properties.getDouble('gravity');
        debugPrint('Custom gravity: $gravity');
      }

      // 7. Index the objects in a spatial hash grid --------------------------
      final grid = SpatialHashGrid<TiledObject>(cellSize: 128);
      for (final obj in map.objectGroups.expand((g) => g.objects)) {
        grid.insert(obj, Rect.fromLTWH(obj.x, obj.y, obj.width, obj.height));
      }
      final nearby = grid.query(const Rect.fromLTWH(0, 0, 512, 512));
      debugPrint('Objects within 512 px of the origin: ${nearby.length}');

      // 8. Write the map back out --------------------------------------------
      //    The writers return text; save it wherever you like.
      final tmx = TmxWriter.write(map, encoding: TmxDataEncoding.base64Zlib);
      final tmj = TmjWriter.write(map);
      debugPrint('As TMX: ${tmx.length} characters; as TMJ: ${tmj.length}');

      if (!mounted) {
        for (final atlas in atlases) {
          atlas.dispose();
        }
        return;
      }
      setState(() {
        _scene = _MapScene(map: map, atlases: atlases, renderers: renderers);
        _status = '${renderers.length} renderer(s) · drag to move';
      });
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
    final scene = _scene;
    return Scaffold(
      backgroundColor: scene?.map.backgroundColor ?? Colors.black,
      appBar: AppBar(
        title: const Text('just_tiled Example'),
        backgroundColor: Colors.black87,
      ),
      body: scene == null
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
                GestureDetector(
                  onPanUpdate: (details) =>
                      setState(() => _pan += details.delta),
                  child: CustomPaint(
                    painter: _TileMapPainter(scene: scene, pan: _pan),
                    child: const SizedBox.expand(),
                  ),
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
// Loading
// ---------------------------------------------------------------------------

/// [relative] as written in [file], as an asset path: resolved against the
/// folder [file] is in, with `.` and `..` collapsed.
String _resolve(String file, String relative) {
  final parts = file.split('/')..removeLast();
  for (final part in relative.replaceAll('\\', '/').split('/')) {
    if (part == '..') {
      if (parts.isNotEmpty) parts.removeLast();
    } else if (part.isNotEmpty && part != '.') {
      parts.add(part);
    }
  }
  return parts.join('/');
}

Future<ui.Image> _loadImage(String asset) async {
  final data = await rootBundle.load(asset);
  final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
  return (await codec.getNextFrame()).image;
}

// ---------------------------------------------------------------------------
// Scene container
// ---------------------------------------------------------------------------

class _MapScene {
  final TiledMap map;
  final List<TextureAtlas> atlases;
  final List<TileMapRenderer> renderers;

  /// Everything the renderers draw, in world space.
  final Rect bounds;

  _MapScene({required this.map, required this.atlases, required this.renderers})
    : bounds = renderers.isEmpty
          ? Rect.zero
          : renderers
                .map((r) => r.worldBounds)
                .reduce((a, b) => a.expandToInclude(b));

  /// Renderers share atlases, so each atlas is disposed here, once —
  /// not through TileMapRenderer.dispose().
  void dispose() {
    for (final atlas in atlases) {
      atlas.dispose();
    }
  }
}

// ---------------------------------------------------------------------------
// Painter
// ---------------------------------------------------------------------------

class _TileMapPainter extends CustomPainter {
  final _MapScene scene;
  final Offset pan;

  const _TileMapPainter({required this.scene, required this.pan});

  @override
  void paint(Canvas canvas, Size size) {
    // The camera is the world point at the screen's top-left: the map
    // starts centred, then follows the drag.
    final camera = scene.bounds.center - size.center(Offset.zero) - pan;

    // render() doesn't move the canvas: translate to the camera here, and
    // pass the world-space area on screen for culling.
    canvas.save();
    canvas.translate(-camera.dx, -camera.dy);
    final visible = camera & size;

    for (final renderer in scene.renderers) {
      renderer.render(canvas, camera, visible);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TileMapPainter old) =>
      old.scene != scene || old.pan != pan;
}
