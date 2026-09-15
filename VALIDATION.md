# Validation — Nocturne 0.6.0 (8)

## Asset and surface checks completed

- Latest supplied GLB checksum retained in `castle-direct-import.json`. Its
  source assembly contains 308 primitives and 86,730 triangles.
- Runtime asset: 336 meshes, 86,681 triangles, 21,094,843 bytes. Geometry count
  changes are due to deliberate doorway/interior cuts and 34 added interior
  pieces, including floors, liners, ceilings, workbenches and stone thresholds.
- Corrected 17,732 face windings. Open shells are also authored double-sided,
  with a RealityKit PBR face-culling override at load time.
- Regenerated mapping on 49,970 faces, covering missing/collapsed UVs and
  consistent world-scale stone masonry. Existing source images are reused.
- All 336 meshes have a material and surface shader. No white fallback material
  remains. Intentionally solid-colour bars, flags, dark window recesses and
  window panes remain distinct from textured surfaces.
- All 219 image references resolve. UV readers resolve to matching mesh data;
  points, normals and UV values are finite. Nondegenerate textured triangles
  have noncollapsed UV area.
- Thirty embedded JPEGs remain at up to 1024px; moderate JPEG compression keeps
  the runtime USDZ below 25MB. The package uses 64-byte-aligned stored entries.
- Source and runtime checksums are recorded; navigation's runtime checksum
  matches the shipped asset.

## Navigation checks completed

- Both original courtyard spawns, mirrored gate orientations and level approach
  positions are retained. Spawn/respawn still share `applySpawn()`.
- 1,163 merged collision boxes per castle are regenerated from the final model.
- Both gate-to-valley movement replays pass at player radius 0.38m. The narrowest
  gate-route centre clearance is 0.45m.
- Flood-fill from the courtyard spawn reaches the east workshop, west study
  and north timber hall using a padded 0.40m footprint.
- Six team/room entry-and-exit replays pass, including axis-separated movement
  through the angled study doorway. Native regression tests cover these routes.
- Upper floors and tower rooms are not supported; this remains planar movement.
  Collision heights remain conservative for projectile collision.

## Source and visual checks completed

- Swift grammar: 25 files; zero syntax errors. Project: 93 objects with resolved
  references and shared scheme. Asset, audio, permissions and version checks pass.
- Reviewed offline renders of outer rock terraces, the castle exterior, courtyard,
  workshop entrance and study interior. Found and corrected oversized masonry
  mapping and bare threshold patches during review.
- These are separate offline material/geometry reviews, not iPhone gameplay
  captures. The optional renderer is included in `Tools/preview_castle.py`.
- `git diff --check` passes. Packaging verifies ZIP integrity and required files.

## Not executed here

Xcode Swift type checking, Metal compilation, linking, native XCTest, signing,
iPhone RealityKit rendering, memory/frame-rate profiling and microphone testing.
There is no Xcode/Apple SDK in this environment. Build the IPA on GitHub and
verify build 0.6.0 (8) on the phone. No multiplayer is introduced in this release.
