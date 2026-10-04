# Changelog

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
  - **Compression**: None, GZIP, Zlib (via `archive`), Zstd (via `just_zstd`).
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

