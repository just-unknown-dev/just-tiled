# Changelog

## [0.5.0] - 2026-11-05

Requires `just_zstd` ^0.3.0 (was ^0.2.0) and adds `meta` ^1.15.0.

### Breaking
- **Renamed**, so every reader, writer and provider is named for what it handles:
  - `TileMapParser` → `TmxParser` (now an `abstract final class`, like `TmjParser`);
  - `TsxProvider` → `TiledFileProvider`, with `getTsx` → `loadTileset` and `getTemplate` → `loadTemplate`;
  - `DefaultTsxProvider` → `AssetTiledFileProvider`;
  - the readers' `tsxProvider:` parameter → `fileProvider:` (`TmxParser.parse`, `TmjParser.parse`, `TmjParser.parseMap`);
  - `TmxDataEncoding` → `TiledDataEncoding`, now taken by both writers.
- **A tile layer stores its tiles once.** `TileLayer.data`, `flipHorizontal`, `flipVertical`, `flipDiagonal`, `rawData`, `rawGidAt` and `rawGids` are replaced by `TileLayer.gids`, a `Uint32List` of raw ids with every flag, and `idAt(index)`, the id without flags. A layer took about 36 bytes a cell in five lists; it takes 4. `TileLayer`'s constructor takes `gids:` and is no longer `const`.
- `TileChunk.data` → `TileChunk.gids`, the same raw ids.
- `TmjWriter.write` and `toJson` take `encoding: TiledDataEncoding` (csv, base64, base64Zlib, base64Gzip) instead of `base64Zlib: bool`.
- `TileMapRenderer.render(canvas, cameraOffset, visibleBounds)` → `render(canvas, visibleBounds)`: the camera offset was never used.
- `TileMapParser.parseWangId` is private: it was a parsing helper.

### Added
- `TiledObject.template`: the template's object, as loaded.
- `TileLayer.idAt`.
- `TmjWriter` writes uncompressed base64 and gzip, as `TmxWriter` does.

### Changed
- **The layout.** `lib/src` is split by feature, in layers: `models/`, then `files/` (the file provider, and the paths, tile data and colour notation both formats share), then `formats/` (`tmx/` and `tmj/`) and `rendering/`, each with one barrel. Internal helpers are `@internal`. The loop between the old `json/` and `parser/` folders is gone; what is left, `tmx/` and `tmj/` using each other's tilesets and templates, is inside `formats/`. `test/library_layout_test.dart` checks it. Files moved: `models/enums.dart` → `tiled_enums.dart`, `gid.dart` → `tiled_gid.dart`, `layer.dart` → `map_layers.dart`, `wang.dart` → `wang_set.dart`, and `TiledProperties` has a file of its own, `tiled_properties.dart`.
- The colour notation is read by one function for both readers.
- The library doc and pubspec description say what the package is: Tiled files, read and written, and drawn; no engine.

### Fixed
- **Maps Tiled saves with Zstandard-compressed layers load.** `just_zstd` 0.2.0 read only uncompressed Zstandard blocks, so every layer Tiled saves as "Base64 (Zstandard compressed)" was refused with a `FormatException` that blamed the file. `just_zstd` 0.3.0 decodes the whole format, and is held to the layer's size: hostile data that would unpack to more is refused as soon as it passes it, before the memory is taken.
- **TMJ maps load object templates.** A templated object in a TMJ map lost everything its template gave it (type, tile, size, properties). Both readers now load each template once per map through the file provider, as TX or TJ, and renumber its tile for the map.
- **Writing a map no longer cuts objects from their templates.** The writers wrote everything an object inherited as its own, so after saving, the objects stopped following their template in Tiled. `TiledObject.template` keeps the template's object, and both writers give back only what the object sets itself, as Tiled writes it.
- **Tile data must hold exactly its layer's tiles.** CSV, XML, uncompressed base64 and TMJ arrays were taken at any length, so a layer could come back short and fail later with a `RangeError`. A finite layer's data must now hold `width × height` ids and each chunk its own size, or the reader throws `FormatException`. A finite layer with no data is all empty cells; an infinite map's layer may have no chunks.
- An object's own shape replaces its template's: an instance made a polygon is no longer also an ellipse.

### Removed
- `TileMapRenderer.dispose()`. It disposed the renderer's atlas, and with it the image, which renderers share. A renderer owns nothing to dispose: dispose each `TextureAtlas` once (it owns its image), or a `TextureAtlasCollection`.
- `SpatialHashGrid`, moved to `just_dart` 0.3.0 (`package:just_dart/just_dart.dart`). Nothing here used it.

### Tests
- 169: the tests mirror `lib/src` (`test/models/`, `files/`, `formats/`, `formats/tmx/`, `formats/tmj/`, `rendering/`), plus the layout guard. New: maps Tiled 1.11.2 saved with Zstandard layers (TMX and TMJ, 40 × 30 and a two-block 256 × 160, an infinite map's chunks), a Zstandard RLE bomb refused at the layer size, TMJ and TJ templates, objects written back as their overrides, tile data of the wrong length in every encoding, every writer encoding in TMJ, `invalidate()` after changing tiles in place, and `TextureAtlasCollection`. The `SpatialHashGrid` tests went with it to `just_dart`.

---
## [0.4.1] - 2026-10-15

### Fixed
- **Flipped and turned tiles drew wrong.** `TileMapRenderer` mirrored a tile by reversing its source rectangle, which `drawRawAtlas` doesn't do: a mirrored tile drew unmirrored, a tile away from its cell, and the diagonal flips D+H and D+V turned the wrong way. Every flip and turn now draws as in Tiled, still in one call per layer. A layer with mirrored tiles draws from the new `TextureAtlas.mirroredImage`: the tileset image with a mirrored copy beside it.
- **Tiles are placed as Tiled places them.** A tile larger than the grid stands on its cell's bottom-left corner, moved by the tileset's `tileOffset`; it was drawn from the cell's top-left. Isometric tiles were drawn half a tile to the right.
- **Culling works for every orientation**, not only orthogonal layers of over 10,000 cells. It no longer builds new buffers every frame, keeps the layer's tint (culled layers lost it), and still draws in one call. `drawRawAtlas` gets the tiles' bounds as its cull rectangle, not the view.
- **`DefaultTsxProvider` collapses `.` and `..`**, so a tileset in a folder beside the map's (`../tilesets/terrain.tsx`) loads. `basePath` is the map's folder.
- **A template's tile object kept the template's tile number.** A template numbers its tile from its own tileset; the gid is now renumbered to the map's first gid for that tileset, flags kept.
- **Properties of Tiled's custom types (1.8+) lost their type.** A property's `propertytype`, the enum's or class's name, is now read and written back. A `class` property's members were read as a whitespace string and written back as one; they are now nested `TiledProperties`, written back as members.
- **Broken TMJ and TSJ files threw `TypeError`.** They now throw `FormatException`, as broken TMX files do, and `TmjParser.parse` reports invalid JSON through its future rather than throwing at once.
- **Zstandard tile data could be read wrong without an error.** The Zstandard decoder (`just_zstd` 0.2.0) reads only uncompressed blocks and returns wrong bytes for compressed ones. Zstandard data must now unpack to exactly its layer's or chunk's tiles, or throws `FormatException`.
- **`SpatialHashGrid`**: inserting an item again left a stale copy at its old place, which queries kept finding. A query the size of the world, or an item that large, walked every cell inside it; both are now checked directly. Bounds that aren't finite throw `ArgumentError`.
- Polygon and polyline points separated by any whitespace, not just single spaces, are read.

### Added
- `TileMapRenderer` draws infinite maps' chunked layers, draws an orthogonal map's tiles in its render order, and reports `tileCount`.
- `TextureAtlas.mirroredImage` and `getMirroredSourceRect`.
- `TiledProperties.propertyTypeOf` and `getClass`; a `TiledProperties` constructor argument for custom types.
- `DefaultTsxProvider.resolve`, the asset key a path from the map loads from.
- Documentation for every public member, and pubspec topics.

### Changed
- **zlib and gzip now come from `just_deflate`**, a pure Dart package with no dependencies. The `archive` package, and with it `path` and `posix`, is gone. Maps read and write as before. Compressed output is about the same size, but the bytes differ from `archive`'s.
- Compressed tile data may not unpack to more than its layer's or chunk's `width × height` ids. Damaged or hostile data now throws `FormatException` rather than filling memory.
- `xml` may be 6.5 to 7.x. The Flutter floor is 3.41.0, the first with Dart 3.11, which the package already needed.
- The code is `dart format`ted.

### Tests
- 136 in all. New: the renderer drawn into images (every flip and turn, tall tiles and offsets, isometric, chunks, culling against drawing everything in each orientation, tint, render order, the mirrored image), asset paths through a mocked bundle, templates, custom-type properties through every reader and writer, broken files, Zstandard, and the spatial grid at its edges. The renderer tests fail on 0.4.0's renderer.

---
## [0.4.0] - 2026-10-04

### Added
- **Writers.** `TmxWriter.write(map, encoding:)` (CSV, base64, base64+zlib, base64+gzip) and `TsxWriter.write(tileset)` produce TMX 1.10 documents the Tiled editor opens: `type` on tiles and objects, `class` elsewhere, a tileset with a `source` written as a reference to its external file.
- **Tiled's JSON formats.** `TmjParser` / `TmjWriter` read and write TMJ maps and TSJ tilesets into the same models. A TMX map may now refer to a `.tsj` tileset, and a TMJ map to a `.tsx` one.
- **Infinite maps.** `TileLayer.chunks` (`TileChunk{x, y, width, height, data}`) and `TileLayer.isChunked`.
- **Raw ids.** `TileLayer.rawData` keeps every flag, including the hexagonal 120° one; `rawGidAt` / `rawGids`. `TiledGid` holds the flag constants and helpers (`idOf`, `flagsOf`, `compose`, `fromBytes`, `toBytes`) — unsigned throughout, so they behave the same on the web.
- **Wang sets.** `Tileset.wangSets` (`WangSet`, `WangColor`, `WangSetType` corner / edge / mixed), including Tiled's pre-1.5 hex Wang ids (`TileMapParser.parseWangId`).
- Tileset `className`, `objectAlignment`, `tileRenderSize`, `fillMode`, `grid`, `transformations`, `isImageCollection`; layer `className` and `locked`; image layer `repeatX` / `repeatY` and image size; map `className` and `parallaxOriginX` / `parallaxOriginY`.
- `TiledProperties` remembers each property's declared type (`typeOf`), so a `file` or `object` property is written back as one.
- `TileMapParser.parseTileset` reads a standalone TSX document.

### Fixed
- **Infinite maps were read as nonsense.** The parser read the whole `<data>` text as one list, running every `<chunk>` together.
- **The hexagonal 120° rotation flag was left inside the tile id.** The id mask is now `0x0FFFFFFF`; the flag is kept in `rawData`.

### Tests
- 47 more: fixtures in Tiled 1.10's own form for every orientation, finite and infinite, every encoding and flip, Wang sets of each kind, external TSX and TSJ, each round-tripped through every writer (93 total).

---
## [0.3.0] - 2026-04-22

### Breaking
- `Layer.parallelX` / `parallelY` renamed to `parallaxX` / `parallaxY`.

### Fixed
- `TileMapRenderer`: corrected H/V/diagonal tile flip logic in both `compile()` and `_renderCulled()`; `_tileCount` now reflects actual compiled tiles.
- `TileMapParser`: template-load errors now logged in debug mode instead of silently swallowed; `_parsePointsString` uses `tryParse` to avoid crashes on malformed data; `_mergeTemplateObject` respects the Tiled 1.9+ `class` attribute on templates.
- `SpatialHashGrid`: fixed `_hash` bit-shift that caused collisions for symmetric coordinates; `queryRadius` is now O(1) per candidate via a cached bounds map.

### Added
- `TileMapRenderer.dispose()` for releasing the atlas `ui.Image`.

### Tests
- Expanded from 5 to 46 tests.

---

## [0.2.0] - 2026-03-15

### Added
- **Example** (`example/example.dart`) — full Flutter app demonstrating map parsing, texture atlas construction, `TileMapRenderer` usage, object querying, custom property access, and
---

## [0.1.0] - 2026-03-15

### Added

- **TileMapParser** — async TMX/TSX parser built on the `xml` package.
  - `TileMapParser.parse(String tmxXml, {TsxProvider?})` returns a fully-populated `TiledMap`.
  - **Encodings**: CSV, Base64, XML (unencoded).
  - **Compression**: None, GZIP, Zlib (via `archive`; `just_deflate` since 0.4.1), Zstd (via `just_zstd`).
  - Decodes flip bits (horizontal, vertical, diagonal / anti-diagonal) from GIDs and stores them separately.
  - Parses embedded and external tileset references; resolves `.tsx` files via the injected `TsxProvider`.
  - Parses tile animation frame sequences (`<animation>` elements).
  - Parses per-tile collision shapes (polygon / circle objects).
  - Typed custom property system: `string`, `int`, `float`, `bool`, `color`, `file`.
  - Object template inheritance with per-instance property overrides.
  - Tile draw offsets for isometric / staggered alignment.
- **TsxProvider** — dependency injection interface for resolving external assets.
  - `DefaultTsxProvider` implementation loads `.tsx` and template files from the Flutter asset bundle with automatic path normalisation.

- **Data models** — immutable value types covering the full Tiled document graph.
  - `TiledMap` — root document with computed `pixelWidth` / `pixelHeight`, `tileLayers`, `objectGroups`, `imageLayers`, and `findTilesetForGid()`.
  - **Layer hierarchy** — abstract `Layer` base with four concrete types: `TileLayer`, `ObjectGroup`, `ImageLayer`, `GroupLayer` (nestable).
  - Common layer properties: `id`, `name`, `visible`, `opacity`, `offsetX/Y`, `tintColor`, `parallelX/Y` (parallax factors).
  - `Tileset` — `firstGid`, dimensions, spacing, margin, `tileOffset`, image metadata, per-tile map, and `getSourceRect(localId)`.
  - `Tile` — `id`, `type`, `probability`, optional image, collision `objectGroup`, `animation` frames, custom properties.
  - `AnimationFrame` — `tileId` + `duration` (ms).
  - `TiledObject` — rectangle, polygon, polyline, ellipse, point, tile object, text object; `rotation`, `gid`, template path.
  - `TiledProperties` — typed accessors: `getString()`, `getInt()`, `getDouble()`, `getBool()`, `has()`, `operator[]`.
  - **Enums**: `MapOrientation` (orthogonal, isometric, staggered, hexagonal), `RenderOrder`, `StaggerAxis`, `StaggerIndex`, `DrawOrder`, `LayerEncoding`, `LayerCompression`.

- **TextureAtlas / TextureAtlasCollection** — GPU-optimised tile texture mapping.
  - `TextureAtlas` pre-computes source `Rect`s for every tile in a tileset on construction.
  - `TextureAtlasCollection.lookup(gid)` resolves the correct atlas and source rect for any GID across multiple tilesets (sorted by `firstGid`).

- **TileMapRenderer** — hardware-accelerated Canvas renderer.
  - `compile()` converts a tile layer to `Float32List` RSTransform + source-rect buffers for a single `Canvas.drawRawAtlas` call per layer.
  - `render(canvas, cameraOffset, visibleBounds)` renders a compiled layer.
  - **Map orientations**: Orthogonal, Isometric, Staggered (X/Y axis), Hexagonal — full coordinate transformation for each.
  - **Tile flipping**: Horizontal, Vertical, Diagonal encoded into RSTransform (`scos`, `ssin`, `tx`, `ty`).
  - **Layer properties**: opacity, tint colour, layer offset, parallax factors.
  - **Frustum culling**: automatic tile-level culling for maps with > 10 000 tiles.
  - `invalidate()` marks a renderer for recompilation on the next frame.

- **SpatialHashGrid\<T\>** — generic 2-D spatial index.
  - `insert()`, `remove()`, `update()` for dynamic objects.
  - `query(Rect)` AABB query, `queryPoint(Offset)`, `queryRadius(Offset, double)` circular proximity query.
  - O(1) average cell hashing via prime multiplication.

