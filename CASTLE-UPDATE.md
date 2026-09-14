# Castle and volcano stability update — 0.4.0 (4)

Historical 0.4.0 notes: **TEXTURE-UPDATE.md** documents the current 0.4.1 build,
which restores textures from the subsequently supplied GLB. The missing-texture
description below refers only to the earlier USDZ upload.

This complete project includes the earlier maps, spells, book controls, menu music,
and speech recovery changes. The reported device crash has no crash report yet;
the rendering changes below address concrete risks found in the source, but have
not been compiled or run on an iPhone in this environment.

## Volcano rendering

- Register a nonisolated rendering method directly with RealityKit, avoiding a
  callback closure that inherits the game session's MainActor isolation.
- Replace compute writes and pixel-format reinterpretation of the output texture
  with a fullscreen render pass using the actual device, attachment format, and
  sample count supplied by RealityKit.
- Match depth sampling to the source depth texture format; unsupported formats
  disable the custom effect. Surface pipeline/GPU errors in graphics diagnostics.
- Add a persistent retro-effects toggle. An unexpected exit during a foreground
  volcano session with effects enabled turns effects off on the next launch.
  A foreground force-quit can also trigger this conservative recovery behavior.
  Normal backgrounding and returning to the menu clear the marker.

Turning effects off skips custom fog, grain, glow and pixel processing. It does
not remove the castles, lava, lighting or map. A model-loading error returns to
the menu with an error message when RealityKit reports a catchable error.

## Supplied castle

`SourceAssets/Castle-original.usdz` is your original upload, unchanged. It is kept
in this source distribution but excluded from the app bundle. The game loads
`Resources/Castle.usdz`, a normalized binary USDZ derived from that upload.

The source contained 316 meshes. Most were about 1,450 units above ground; six
detached pieces were near zero and one was far outside the castle. The runtime
copy excludes those seven pieces, centers the remaining castle on the ground,
and scales its footprint to 18 metres wide. The import report records removed
prim paths, bounds, scale and checksums. Material bindings and UVs are preserved.

The upload contained material colors but **no texture images or texture-file
references**. Missing painted textures cannot be reconstructed from this file;
provide a USDZ with embedded textures or the original images to add those.

The optional `Tools/prepare_castle.py` reproduces this conversion with OpenUSD
(`pip install usd-core`). The checked-in runtime model is ready to build and
GitHub Actions does not need OpenUSD.

## Team bases and respawning

Ember Keep and Moon Keep occupy the south and north ends of the volcano. The
model is loaded once asynchronously and cloned with shared mesh/material
resources. Team-colored banners mark the two spawn forecourts. Each keep has a
coarse collision boundary instead of hundreds of mesh collision shapes.

Select a keep in the main menu. Both the initial spawn and death respawn use
`TeamBases.spawn(map:team:)`, facing the arena from the selected castle entrance
forecourt. Health resets and old projectiles clear through the existing respawn
path. Re-arm the microphone after death. The original Hollow Court is preserved.

Castle interiors and upper floors are not traversable: the current controller
moves on a flat ground plane. These are local team assignments in the solo
practice prototype. GameKit matchmaking, remote teammates, team combat rules and
authoritative network respawn remain unimplemented.

## Device checks

1. Verify Settings shows 0.4.0 (4).
2. Open Hollow Court, then enter the volcano with each team selected.
3. Confirm two opposing castles and safe starts facing the arena.
4. Take lethal damage and verify return to the selected forecourt.
5. Test with retro effects enabled and disabled; record the graphics status if
   the app closes or the effect disables itself.
6. Check repeated voice casts and sound playback, which still need device testing.

Swift grammar, project/resource references, USD structure and archive integrity
can be checked here. Native Swift/Metal compilation, XCTest, memory, frame rate,
the rendered appearance and actual crash resolution require the GitHub build and
an iPhone run. No IPA or remote build was produced here.
