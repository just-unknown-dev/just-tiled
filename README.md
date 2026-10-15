# Just Tiled

Read and write [Tiled Map Editor](https://www.mapeditor.org/) files — TMX/TSX and Tiled's JSON forms, TMJ/TSJ — and draw their tile layers with `Canvas.drawRawAtlas`. Made for Flutter 2D games.

The package doesn't depend on any game engine. `just_game_engine` uses it to import and export Tiled files (its `TiledInterop`); the engine draws and collides its own tile maps.

---

## Features

- **Readers** — TMX maps, TSX tilesets and TX object templates; TMJ maps and TSJ tilesets. A TMX map may use a TSJ tileset and a TMJ map a TSX one. Files from Tiled 1.8 to 1.10.
- **Writers** — `TmxWriter`, `TsxWriter` and `TmjWriter` write files the Tiled editor opens (the TMX 1.10 format).
- **Every orientation** — orthogonal, isometric, staggered (X/Y), hexagonal.
- **Every layer type** — tile, object, image and nested group layers.
- **Infinite maps** — chunked tile layers (`TileLayer.chunks`).
- **Every tile encoding** — CSV, Base64 and XML; uncompressed, gzip or zlib. Zstandard [in part](#zstandard).
- **Raw tile ids** — all four of Tiled's flags kept, including the hexagonal 120° one (`TileLayer.rawData`, `TiledGid`).
- **Tilesets** — per-tile properties, animation frames, per-tile images, collision shapes, Wang sets (corner, edge, mixed).
- **Objects** — rectangle, ellipse, point, polygon, polyline, tile and text objects; templates, their tiles renumbered for the map.
- **Typed custom properties** — `string`, `int`, `float`, `bool`, `color`, `file`, `object`, each written back as its own type, and Tiled's custom types: enums and classes.
- **Renderer** — one `drawRawAtlas` call per layer, finite or infinite; every flip and turn; tiles placed as Tiled places them; opacity, tint, layer offsets, render order; culling for every orientation.
- **Spatial hash grid** — fast rectangle, point and radius queries for collision and culling.
- **Every platform** — Android, iOS, Linux, macOS, Windows and the web, compiled to JavaScript or WebAssembly. Pure Dart: no native code.

---

## Getting started

Add `just_tiled` to your `pubspec.yaml`:

```yaml
dependencies:
  just_tiled: ^0.4.1
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

final map = await TileMapParser.parse(
  tmx,
  tsxProvider: const DefaultTsxProvider(basePath: 'assets/maps'),
);

print('${map.width}x${map.height} tiles, ${map.orientation.name}');
```

### TMJ

```dart
final tmj = await rootBundle.loadString('assets/maps/desert.tmj');

final map = await TmjParser.parse(
  tmj,
  tsxProvider: const DefaultTsxProvider(basePath: 'assets/maps'),
);
```

Both give the same `TiledMap`. A TMJ map keeps an object's template path (`templatePath`) but doesn't load the template; a TMX map does.

A file that isn't a valid map or tileset throws a `FormatException`, from either reader.

### A tileset on its own

```dart
final terrain = TileMapParser.parseTileset(tsxText); // .tsx
final props = TmjParser.parseTileset(tsjText);       // .tsj
```

### Where external files come from

The parsers load external tilesets and templates through a `TsxProvider`. Without one, an external tileset is left with only its `firstGid` and `source`.

`DefaultTsxProvider` reads from the asset bundle. Set `basePath` to the map's folder: it joins that and the path as written in the map, collapsing `.` and `..`, so `../tilesets/terrain.tsx` from `assets/maps` loads `assets/tilesets/terrain.tsx`. `resolve(source)` tells you the asset key. For anything else, write your own provider:

```dart
import 'dart:io';

class FileTsxProvider implements TsxProvider {
  FileTsxProvider(this.directory);

  final String directory;

  // Asked for .tsx and .tsj files; the parser picks the format by file ending.
  @override
  Future<String> getTsx(String source) =>
      File('$directory/$source').readAsString();

  @override
  Future<String> getTemplate(String source) =>
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

`TileLayer.data` holds ids without flags, with the flips in `flipHorizontal`, `flipVertical` and `flipDiagonal`. The raw ids, all flags included, are in `rawData` (or `rawGidAt(i)` / `rawGids`). A tile object's `gid` is raw too.

Use `TiledGid` to take raw ids apart. It works on unsigned values, so it gives the same answers on the web:

```dart
final raw = layer.rawGidAt(index);
final gid = TiledGid.idOf(raw);
final mirrored = TiledGid.isFlippedHorizontally(raw);
final turned = TiledGid.isRotatedHex120(raw);

final tileset = map.findTilesetForGid(gid);
final localId = gid - tileset!.firstGid;
```

### Infinite maps

A layer of an infinite map holds its tiles in `chunks`, and its `data` is empty:

```dart
for (final layer in map.tileLayers.where((l) => l.isChunked)) {
  for (final chunk in layer.chunks) {
    for (var i = 0; i < chunk.data.length; i++) {
      final gid = TiledGid.idOf(chunk.data[i]);
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

Call `invalidate()` after changing a layer's tiles; the next `render` recompiles it.

When you're done, dispose each atlas once (`TextureAtlas.dispose()`, or `TextureAtlasCollection.dispose()` for a list). `TileMapRenderer.dispose()` disposes its atlas's images too, so don't call it on renderers that share an atlas.

### 3. Draw in a `CustomPainter`

`render` doesn't move the canvas: translate it to your camera first (its `cameraOffset` argument isn't used). `visibleBounds` is the part of the world on screen: only the tiles that can show inside it are drawn, still in one call. Pass `null` to draw every tile.

```dart
@override
void paint(Canvas canvas, Size size) {
  canvas.save();
  canvas.translate(-camera.dx, -camera.dy);
  final visible = camera & size; // world space

  for (final renderer in renderers) {
    renderer.render(canvas, camera, visible);
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

## Spatial hash grid

```dart
final grid = SpatialHashGrid<TiledObject>(cellSize: 128);

for (final obj in map.objectGroups.expand((g) => g.objects)) {
  grid.insert(obj, Rect.fromLTWH(obj.x, obj.y, obj.width, obj.height));
}

final onScreen = grid.query(cameraRect);
final underCursor = grid.queryPoint(cursor);
final inRange = grid.queryRadius(player, 200);
```

`update` (or inserting an item again) moves an item, and `remove` takes it out. Items far larger than a cell, and queries far larger than the occupied cells, are checked directly rather than cell by cell.

---

## Writing files

The writers return text; saving it is up to you.

```dart
final tmx = TmxWriter.write(map, encoding: TmxDataEncoding.base64Zlib);
final tsx = TsxWriter.write(map.tilesets.first);

final tmj = TmjWriter.write(map);                    // tile data as number arrays
final packed = TmjWriter.write(map, base64Zlib: true);
final tsj = TmjWriter.writeTileset(map.tilesets.first);
```

`TmxDataEncoding` is `csv` (the default), `base64`, `base64Zlib` (Tiled's default) or `base64Gzip`.

A tileset with a `source` is written as a reference to its external file; write that file with `TsxWriter` or `TmjWriter.writeTileset`. Files follow the TMX 1.10 format: `type` on tiles and objects, `class` on everything else.

---

## Integration with just_game_engine

The engine's `TiledInterop` turns a parsed map into the engine's own tile map and back, and its editor imports and exports Tiled files with it. A `TileMapComponent` can also name a `.tmx` or `.tmj` file directly.

---

## Supported Tiled features

| Category | Read | Write |
|----------|------|-------|
| Files | TMX, TSX, TX templates (from TMX); TMJ, TSJ | TMX, TSX, TMJ, TSJ |
| Map orientations | Orthogonal, isometric, staggered, hexagonal | Same |
| Layer types | Tile (finite and infinite), object, image, group | Same |
| TMX tile data | CSV, Base64, XML; none, gzip, zlib, [Zstandard in part](#zstandard) | CSV, Base64; none, gzip, zlib |
| TMJ tile data | Arrays, Base64; none, gzip, zlib, [Zstandard in part](#zstandard) | Arrays, Base64 with zlib |
| Tilesets | Embedded, external, several per map, image collections | Same |
| Tile flags | Horizontal, vertical, diagonal, hexagonal 120° | Same |
| Tiles | Properties, animation, own images, collision shapes | Same |
| Wang sets | Corner, edge, mixed; pre-1.5 hex Wang ids | Corner, edge, mixed |
| Objects | Rectangle, ellipse, point, polygon, polyline, tile, text | Same, with template paths |
| Properties | string, int, float, bool, color, file, object; custom enums and classes | Same |
| Layer settings | Opacity, tint, offset, parallax, locked, class | Same |

### Zstandard

Zstandard tile data is unpacked by [`just_zstd`](https://pub.dev/packages/just_zstd), which so far reads only uncompressed Zstandard blocks. Data the zstd library compressed, as Tiled saves it, is refused with a `FormatException` rather than read wrong. Until that changes, save maps with zlib (Tiled's default) or gzip.

---

## Additional information

- **Example:** [example/example.dart](example/example.dart)
- **Changes:** [CHANGELOG.md](CHANGELOG.md)
- **Issues & feature requests:** [GitHub Issues](https://github.com/just-unknown-dev/just-tiled/issues)
- **Contributing:** See [CONTRIBUTING.md](CONTRIBUTING.md)
- **Code of Conduct:** See [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)
- **License:** BSD-3-Clause
