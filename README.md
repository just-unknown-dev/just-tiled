# Just Tiled

A standalone TMX/TSX parser and hardware-accelerated renderer for [Tiled Map Editor](https://www.mapeditor.org/) files, designed for Flutter-based 2D games.

Built to work independently from any game engine — ECS integration is handled at the engine layer (e.g. via `just_game_engine`'s `TiledMapFactory` and `TileMapRenderSystem`).

---

## Features

- **Full Tiled format support** — TMX maps and external TSX tilesets (Tiled 1.8+)
- **All map orientations** — Orthogonal, Isometric, Staggered (X/Y), Hexagonal
- **All layer types** — Tile layers, Object groups, Image layers, nested Group layers
- **All encodings & compression** — CSV, Base64, XML; GZIP, Zlib, Zstd, or uncompressed
- **Tile features** — per-tile properties, animation frames, custom images, collision shapes
- **Object types** — Rectangle, polygon, polyline, ellipse, point, tile objects, text objects, object templates
- **Typed custom properties** — `int`, `float`, `bool`, `string`, `color`, `file`
- **Rendering** — tile flipping (H/V/diagonal), opacity, tint colors, layer offsets, parallax
- **Multi-tileset maps** — correct GID mapping across multiple tilesets
- **Hardware-accelerated rendering** — single `Canvas.drawRawAtlas` batch per layer
- **Frustum culling** — automatic tile-level culling for large maps (> 10 k tiles)
- **Spatial hash grid** — O(1) AABB / point / radius queries for collision and culling

---

## Getting started

Add `just_tiled` to your `pubspec.yaml`:

```yaml
dependencies:
  just_tiled: ^0.1.0
```

Place your `.tmx` map and `.tsx` + image files under `assets/` and declare them:

```yaml
flutter:
  assets:
    - assets/maps/
```

---

## Usage

### 1. Parse a map

```dart
import 'package:flutter/services.dart' show rootBundle;
import 'package:just_tiled/just_tiled.dart';

final tmxString = await rootBundle.loadString('assets/maps/desert.tmx');

final map = await TileMapParser.parse(
  tmxString,
  tsxProvider: const DefaultTsxProvider(basePath: 'assets/maps'),
);

print('${map.width}x${map.height} tiles, orientation: ${map.orientation}');
```

### 2. Build texture atlases

```dart
final atlases = <TextureAtlas>[];

for (final tileset in map.tilesets) {
  if (tileset.imageSource != null) {
    final image = await loadUiImage('assets/maps/${tileset.imageSource}');
    atlases.add(TextureAtlas(image: image, tileset: tileset));
  }
}

final collection = TextureAtlasCollection(atlases);
```

### 3. Render with a CustomPainter

```dart
// Create one renderer per tile layer
final renderers = <TileMapRenderer>[];
for (final layer in map.tileLayers) {
  renderers.add(TileMapRenderer(
    map: map,
    layer: layer,
    atlasCollection: collection,
  ));
}

// In CustomPainter.paint():
for (final renderer in renderers) {
  renderer.render(canvas, cameraOffset, visibleBounds);
}
```

### 4. Query objects

```dart
for (final group in map.objectGroups) {
  for (final obj in group.objects) {
    print('${obj.name} (${obj.type}) at (${obj.x}, ${obj.y})');
  }
}
```

### 5. Read custom properties

```dart
final props = map.layers.first.properties;
if (props.has('speed')) {
  final speed = props.getDouble('speed');
}
```

### 6. Use the spatial hash grid

```dart
final grid = SpatialHashGrid<TiledObject>(cellSize: 128);

for (final obj in map.objectGroups.expand((g) => g.objects)) {
  grid.insert(obj, Rect.fromLTWH(obj.x, obj.y, obj.width, obj.height));
}

// Query objects near the camera
final nearby = grid.query(cameraRect);
```

---

## Integration with just_game_engine

When used alongside `just_game_engine`, the `TiledMapFactory` spawns the map directly into the ECS `World` and `TileMapRenderSystem` renders all tile layers automatically:

```dart
TiledMapFactory.spawnMap(world, map, atlasCollection);
world.addSystem(TileMapRenderSystem(camera: engine.rendering.camera));
```

---

## Supported Tiled features

| Category | Supported |
|----------|-----------|
| Map orientations | Orthogonal, Isometric, Staggered, Hexagonal |
| Layer types | Tile, Object, Image, Group (nested) |
| Encodings | CSV, Base64, XML |
| Compression | None, GZIP, Zlib, Zstd |
| Tilesets | Embedded, external (.tsx), multi-tileset |
| Tile flipping | Horizontal, Vertical, Diagonal (anti-diagonal) |
| Tile animation | Frame sequences with per-frame duration |
| Object types | Rectangle, polygon, polyline, ellipse, point, tile, text, template |
| Properties | string, int, float, bool, color, file |
| Parallax | Per-layer parallax X/Y factors |

---

## Additional information

- **Issues & feature requests:** [GitHub Issues](https://github.com/just-unknown-dev/just-tiled/issues)
- **Contributing:** See [CONTRIBUTING.md](CONTRIBUTING.md)
- **Code of Conduct:** See [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)
- **License:** BSD-3-Clause

