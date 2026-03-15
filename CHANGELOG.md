# Changelog

All notable changes to `just_tiled` will be documented in this file.

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

