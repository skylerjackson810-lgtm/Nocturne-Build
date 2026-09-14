# Validation — Nocturne 0.5.1 (7)

Completed locally:

- Located the actual entrance at asset-local X=-2.55, Z≈-11.5. Confirmed the
  separate `Plane.062` mesh closed the gate while `Plane.063` supplied its stone
  arch. Rotated the leaf inward 90 degrees without removing its triangles.
- All 308 shipped meshes now have a bound material and connected surface shader.
  This includes 94 primitives whose source GLB specified no material. Those use
  explicit neutral white rough surfaces. No claim is made that missing texture
  artwork was recovered for those primitives.
- All 219 texture asset references resolve. Each bound UV reader resolves to a
  mesh primvar with the correct vertex count. Thirty JPEG maps remain at up to
  1024 pixels. Original GLB texture assignments remain unchanged.
- 86,730 triangles retained. Source normalization round-trip error remains below
  0.000001 before the documented door-pose edit. Original source checksum and the
  updated runtime checksum are recorded in `SourceAssets/castle-direct-import.json`.
- Castle courtyard height 4.72m is translated to world ground Y=0; the island
  foundation is buried below the valley. The castle architecture is not flattened.
  A flat grass approach spans the actual gate and the existing valley road.
- Navigation is baked from the final USDZ, rather than hand-written collision
  guesses. 20cm raster cells sample the body slab 0.35–1.45m above courtyard
  ground, allowing low stepping stones beneath the player's body. Matching runs
  merge into 1,178 boxes per castle, with conservative obstacle heights.
- Both mirrored spawn-to-valley routes pass offline geometric clearance checks
  with a 0.38m player radius. The narrowest measured center-to-obstacle clearance
  is 0.45m. Each team also passes a 440-step, 4cm movement replay through the gate.
- Initial spawn and death/respawn both call the existing central `applySpawn()`.
  The selected team's courtyard position is now used by that function.
- Volcano X bounds stay ±52m; Z bounds extend to ±80m so rear courtyards are not
  clamped to the previous arena extent. Original court bounds remain unchanged.
- Swift grammar: 25 files, zero syntax errors. Xcode project: 93 objects, all file
  references and scheme links resolve. Generated castle collision is included
  in Compile Sources. Existing asset/audio/permission checks pass.
- Version 0.5.1 (7); `git diff --check` passes. Packaging verifies required files
  and ZIP CRC before atomically creating the final source archive.

Native regression tests supplied, not executed here:

- Both teams spawn behind their own gate and traverse the complete approach.
- Castle wall collision remains active while the gateway is passable.
- Movement behind the old depth boundary no longer clamps toward the arena.
- Original court spawn remains independent of selected team.
- Existing spell, speech recovery, audio policy and collision tests are retained.

Limitations:

This environment has no Xcode/Apple SDKs, so Swift type checking, linking, native
XCTest and RealityKit rendering were not run. The updated IPA still needs a
GitHub build and iPhone verification, particularly material appearance and frame
rate with the new collision data. Navigation is for level ground/courtyards;
upper terraces, stairs and building interiors are not supported walking routes.
Collision heights are conservative rather than exact per-triangle projectile
surfaces. No multiplayer or vertical locomotion is introduced by this revision.
