# Just Tiled

Read and write [Tiled Map Editor](https://www.mapeditor.org/) files — TMX/TSX/TX and Tiled's JSON forms, TMJ/TSJ/TJ — and draw their tile layers with `Canvas.drawRawAtlas`. Made for Flutter 2D games.

The package doesn't depend on any game engine. `just_game_engine` uses it to import and export Tiled files (its `TiledInterop`); the engine draws and collides its own tile maps.

---

## Features

- **Readers** — TMX maps, TSX tilesets and TX object templates; TMJ maps, TSJ tilesets and TJ templates. A map in either format may use tilesets and templates of the other. Files from Tiled 1.8 to 1.11.
- **Writers** — `TmxWriter`, `TsxWriter` and `TmjWriter` write files the Tiled editor opens (the TMX 1.10 format).
- **Every orientation** — orthogonal, isometric, staggered (X/Y), hexagonal.
- **Every layer type** — tile, object, image and nested group layers.
- **Infinite maps** — chunked tile layers (`TileLayer.chunks`).
- **Every tile encoding** — CSV, Base64 and XML; uncompressed, gzip, zlib or [Zstandard](#zstandard). Tile data must hold exactly its layer's or chunk's tiles, and compressed data can't unpack past them.
- **Raw tile ids** — all four of Tiled's flags kept, including the hexagonal 120° one, in one `Uint32List` per layer (`TileLayer.gids`, `TiledGid`).
- **Tilesets** — per-tile properties, animation frames, per-tile images, collision shapes, Wang sets (corner, edge, mixed).
- **Objects** — rectangle, ellipse, point, polygon, polyline, tile and text objects; [templates](#templates), their tiles renumbered for the map, written back as Tiled writes them.
- **Typed custom properties** — `string`, `int`, `float`, `bool`, `color`, `file`, `object`, each written back as its own type, and Tiled's custom types: enums and classes.
- **Renderer** — one `drawRawAtlas` call per layer, finite or infinite; every flip and turn; tiles placed as Tiled places them; opacity, tint, layer offsets, render order; culling for every orientation.
- **Every platform** — Android, iOS, Linux, macOS, Windows and the web, compiled to JavaScript or WebAssembly. Pure Dart: no native code.

---

## Getting started

Add `just_tiled` to your `pubspec.yaml`:

```yaml
dependencies:
  just_tiled: ^0.5.0
```

Put your maps, tilesets and images under `assets/` and declare them:

```yaml
flutter:
  assets:
    - assets/maps/
```

---

## Reading maps

### TMX

```dart
import 'package:flutter/services.dart' show rootBundle;
import 'package:just_tiled/just_tiled.dart';

final tmx = await rootBundle.loadString('assets/maps/desert.tmx');

final map = await TmxParser.parse(
  tmx,
  fileProvider: const AssetTiledFileProvider(basePath: 'assets/maps'),
);

print('${map.width}x${map.height} tiles, ${map.orientation.name}');
```

### TMJ

```dart
final tmj = await rootBundle.loadString('assets/maps/desert.tmj');

final map = await TmjParser.parse(
  tmj,
  fileProvider: const AssetTiledFileProvider(basePath: 'assets/maps'),
);
```

Both give the same `TiledMap`, external tilesets and templates loaded.

A file that isn't a valid map or tileset throws a `FormatException`, from either reader. So does tile data that doesn't hold exactly its layer's `width × height` tiles (or its chunk's, on an infinite map).

### A tileset on its own

```dart
final terrain = TmxParser.parseTileset(tsxText); // .tsx
final props = TmjParser.parseTileset(tsjText);   // .tsj
```

### Where external files come from

The readers load external tilesets and templates through a `TiledFileProvider`. Without one, an external tileset is left with only its `firstGid` and `source`, and an object placed from a template with only its own values.

`AssetTiledFileProvider` reads from the asset bundle. Set `basePath` to the map's folder: it joins that and the path as written in the map, collapsing `.` and `..`, so `../tilesets/terrain.tsx` from `assets/maps` loads `assets/tilesets/terrain.tsx`. `resolve(source)` tells you the asset key. For anything else, write your own provider:

```dart
import 'dart:io';

class FolderFileProvider implements TiledFileProvider {
  FolderFileProvider(this.directory);

  final String directory;

  // Asked for .tsx and .tsj files; the reader picks the format by the ending.
  @override
  Future<String> loadTileset(String source) =>
      File('$directory/$source').readAsString();

  // Asked for .tx and .tj files.
  @override
  Future<String> loadTemplate(String source) =>
      File('$directory/$source').readAsString();
}
```

---

## Working with the data

### Objects

```dart
for (final group in map.objectGroups) {
  for (final obj in group.objects) {
    print('${obj.name} (${obj.type}) at (${obj.x}, ${obj.y})');
  }
}
```

`map.tileLayers`, `map.objectGroups` and `map.imageLayers` include the layers inside groups.

### Templates

An object placed from a template (a `.tx` or `.tj` file) holds the template's values merged with its own: what it doesn't set, it takes from the template, properties key by key. Its `templatePath` names the file, and `template` holds the template's object as loaded, its tile renumbered for the map. Each template is loaded once per map.

The writers give such an object back as Tiled does: its id, template and position, then only what it sets itself. Edit the template in Tiled later, and the objects still follow it.

### Custom properties

```dart
final props = map.layers.first.properties;
if (props.has('speed')) {
  final speed = props.getDouble('speed');
}

props.typeOf('door'); // 'object' — an object property holds the object's id
```

Properties of Tiled's custom types (Tiled 1.8+) keep the type's name, and a class keeps its members:

```dart
props.propertyTypeOf('facing'); // 'Direction', an enum
final stats = props.getClass('stats'); // the members, as TiledProperties
final hp = stats?.getInt('hp');
```

A TMJ file gives a class's members as bare values, so a member's type is read from its value there: a colour comes back as its `#rrggbb` text.

### Raw tile ids and flags

A finite layer keeps its tiles once, in `TileLayer.gids`: a `Uint32List` of `width × height` raw ids, row by row, every flag included. `idAt(i)` is the id at cell `i` without its flags. A tile object's `gid` is raw too.

Use `TiledGid` to take raw ids apart. It works on unsigned values, so it gives the same answers on the web:

```dart
final raw = layer.gids[index];
final gid = TiledGid.idOf(raw);
final mirrored = TiledGid.isFlippedHorizontally(raw);
final turned = TiledGid.isRotatedHex120(raw);

final tileset = map.findTilesetForGid(gid);
final localId = gid - tileset!.firstGid;
```

### Infinite maps

A layer of an infinite map holds its tiles in `chunks`, and its `gids` is empty:

```dart
for (final layer in map.tileLayers.where((l) => l.isChunked)) {
  for (final chunk in layer.chunks) {
    for (var i = 0; i < chunk.gids.length; i++) {
      final gid = TiledGid.idOf(chunk.gids[i]);
      if (gid == 0) continue;
      final x = chunk.x + i % chunk.width; // in tiles; may be negative
      final y = chunk.y + i ~/ chunk.width;
      // place tile gid at (x, y)
    }
  }
}
```

### Wang sets

```dart
for (final set in tileset.wangSets) {
  print('${set.name} (${set.type.name}): '
      '${set.colors.map((c) => c.name).join(', ')}');

  set.wangTiles.forEach((localId, wangId) {
    // Eight slots, clockwise from the top: 0 is none, n is colors[n - 1].
  });
}
```

---

## Rendering

### 1. Load the tileset images

```dart
import 'dart:ui' as ui;

Future<ui.Image> loadImage(String asset) async {
  final data = await rootBundle.load(asset);
  final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
  return (await codec.getNextFrame()).image;
}

final atlases = [
  for (final tileset in map.tilesets)
    if (tileset.imageSource != null)
      TextureAtlas(
        image: await loadImage('assets/maps/${tileset.imageSource}'),
        tileset: tileset,
      ),
];
```

A tileset's `imageSource` is relative to the file that declares the tileset: the TSX for an external one.

### 2. Make the renderers

A renderer draws one tile layer's tiles from one atlas, finite or infinite. For a layer that uses more than one tileset, make one per atlas:

```dart
final renderers = [
  for (final layer in map.tileLayers)
    if (layer.visible)
      for (final atlas in atlases)
        TileMapRenderer(map: map, tileLayer: layer, atlas: atlas)..compile(),
];
```

Tiles are placed as Tiled places them: a tile's bottom-left corner on its cell's, moved by the tileset's `tileOffset`, so tiles taller than the grid reach up over the row above. They draw in the map's render order (orthogonal maps; others draw right-down), with every flip and 90° turn. `canvas.drawRawAtlas` can turn a tile but not mirror it, so a layer with mirrored tiles draws from `TextureAtlas.mirroredImage`: the tileset image with a mirrored copy beside it (below it, for a wide image), made once, the first time it's needed.

Change tiles in place (`layer.gids[i] = …`) and call `invalidate()`; the next `render` compiles the layer again.

An atlas owns its image. When you're done, dispose each atlas once (`TextureAtlas.dispose()`, or `TextureAtlasCollection.dispose()` for a list); renderers own nothing to dispose.

### 3. Draw in a `CustomPainter`

`render` doesn't move the canvas: translate it to your camera first. `visibleBounds` is the part of the world on screen: only the tiles that can show inside it are drawn, still in one call. Pass `null` to draw every tile.

```dart
@override
void paint(Canvas canvas, Size size) {
  canvas.save();
  canvas.translate(-camera.dx, -camera.dy);
  final visible = camera & size; // world space

  for (final renderer in renderers) {
    renderer.render(canvas, visible);
  }

  canvas.restore();
}
```

### What the renderer doesn't do

- **Image-collection tilesets** (`isImageCollection`), which have no single image to make an atlas from.
- **Animated tiles.** Frames are read (`Tile.animation`), but a tile draws its first image.
- **Scaling tiles to the grid** (`TileRenderSize.grid`). Tiles draw at their own size.
- **Parallax, the hexagonal 120° flag, and a group's offset, opacity and tint.** These are read but not applied.
- **Hidden layers.** Skip layers whose `visible` is false, as above.

---

## Writing files

The writers return text; saving it is up to you.

```dart
final tmx = TmxWriter.write(map, encoding: TiledDataEncoding.base64Zlib);
final tsx = TsxWriter.write(map.tilesets.first);

final tmj = TmjWriter.write(map); // tile data as number arrays
final packed = TmjWriter.write(map, encoding: TiledDataEncoding.base64Zlib);
final tsj = TmjWriter.writeTileset(map.tilesets.first);
```

`TiledDataEncoding` is `csv` (the default: comma-separated in TMX, number arrays in TMJ), `base64`, `base64Zlib` (Tiled's default) or `base64Gzip`, for both writers.

A tileset with a `source` is written as a reference to its external file; write that file with `TsxWriter` or `TmjWriter.writeTileset`. Files follow the TMX 1.10 format: `type` on tiles and objects, `class` on everything else.

---

## Integration with just_game_engine

The engine's `TiledInterop` turns a parsed map into the engine's own tile map and back, and its editor imports and exports Tiled files with it. A `LevelMapComponent` can also name a `.tmx` or `.tmj` file directly.

---

## Supported Tiled features

| Category | Read | Write |
|----------|------|-------|
| Files | TMX, TSX, TX; TMJ, TSJ, TJ | TMX, TSX, TMJ, TSJ |
| Map orientations | Orthogonal, isometric, staggered, hexagonal | Same |
| Layer types | Tile (finite and infinite), object, image, group | Same |
| TMX tile data | CSV, Base64, XML; none, gzip, zlib, Zstandard | CSV, Base64; none, gzip, zlib |
| TMJ tile data | Arrays, Base64; none, gzip, zlib, Zstandard | Arrays, Base64; none, gzip, zlib |
| Tilesets | Embedded, external, several per map, image collections | Same |
| Tile flags | Horizontal, vertical, diagonal, hexagonal 120° | Same |
| Tiles | Properties, animation, own images, collision shapes | Same |
| Wang sets | Corner, edge, mixed; pre-1.5 hex Wang ids | Corner, edge, mixed |
| Objects | Rectangle, ellipse, point, polygon, polyline, tile, text; templates | Same; templates as Tiled writes them |
| Properties | string, int, float, bool, color, file, object; custom enums and classes | Same |
| Layer settings | Opacity, tint, offset, parallax, locked, class | Same |

### Zstandard

Zstandard tile data, as Tiled saves "Base64 (Zstandard compressed)" layers, is unpacked by [`just_zstd`](https://pub.dev/packages/just_zstd), a pure Dart decoder of the whole format, held to the layer's size: data that would unpack to more is refused as soon as it does. The writers don't write Zstandard; zlib is Tiled's default.

---

## Architecture

`lib/src` is split by feature, each folder with one barrel, in three layers: `models/` (the data), then `files/` (where external files come from, and the tile data and notation both formats share), then `formats/` (TMX and TMJ, read and written) and `rendering/`. Nothing imports a layer above its own; `test/library_layout_test.dart` checks it. Inside `formats/`, `tmx/` and `tmj/` import each other, since a map of one format may use the other's tilesets and templates.

`SpatialHashGrid` moved to [`just_dart`](https://pub.dev/packages/just_dart) in 0.5.0.

---

## Additional information

- **Example:** [example/example.dart](example/example.dart)
- **Changes:** [CHANGELOG.md](CHANGELOG.md)
- **Issues & feature requests:** [GitHub Issues](https://github.com/just-unknown-dev/just-tiled/issues)
- **Contributing:** See [CONTRIBUTING.md](CONTRIBUTING.md)
- **Code of Conduct:** See [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)
- **License:** BSD-3-Clause
