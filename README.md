# Nocturne 0.5.1 — Open Castle Courtyards

Complete native iOS source project. Start with **START-HERE.md** to build an IPA
on GitHub and install it from Windows. This deliverable is source, not an IPA.

## Castle access fixes

- Corrected both keep orientations: the real gate now faces the valley road.
- Placed the courtyard at valley ground level by burying the rocky island footing.
  A flat grass approach joins the gate to the road; the castle itself is not flattened.
- Swung the separate closed gate leaf inward 90 degrees. Stone arch, towers,
  buildings and original texture bindings remain intact.
- Added explicit neutral white, rough materials to 94 primitives with no source
  material assignment. These replace the unbound surfaces responsible for the
  magenta fallback; they do not invent missing painted texture maps.
- Replaced the whole-castle collision box with a baked ground-level footprint
  derived from the shipped geometry. Both teams start and respawn inside their
  courtyard, looking toward the open gate. Map depth includes both courtyards.

## Visual update retained

- Castle imported directly from the latest `Castle+format+1(2).glb`. Its retained
  assembly has 308 mesh primitives and 86,730 triangles, with no decimation.
  Original part proportions, normals, material indices and texture tiling are
  preserved, except the deliberate open-door pose. A uniform scale makes it 52 metres
  wide. The previous 18-metre miniature scale is gone.
- Thirty textures at up to 1024 pixels replace the earlier 512-pixel material
  retargeting. Each GLB material slot uses its own baked UV coordinates. Detached
  export debris is excluded, with the exact list in the import report.
- Larger volcanic valley with textured terrain, winding lava channels, three
  weathered bridge crossings, stone approach roads, layered cliffs, broken ruins,
  an irregular crater mountain, stars, a cratered moon and localized mist.
- Moonlight with shadows, cool fill light, warm lava light and colored keep lights.
  The old full-screen pixel filter is OFF by default in this version. It is an
  optional legacy setting, not required for stars, mist or lighting.
- Detailed procedural gloved hands: rounded finger segments, finger-curl animation,
  seam stitches, inset knuckle panels, cuff hardware, gemstone and folded sleeves.
- Smaller spellbook: leather covers, layered page edges, stitched binding, brass
  corners, spine bands, ribbon and 512 × 640 page artwork. Study notes and active
  spell occupy different pages. Compact HUD clears more of the viewport.

## Gameplay retained

Ember Keep and Moon Keep select opposing start/respawn courtyards in the same
volcano map. The original Hollow Court remains selectable. Four voice-only spells,
page switching, controller/touch input, menu music, sound effects, speech recovery,
practice targets, class stats, pause and health/respawn remain available.

The larger valley has its own movement boundary; the original court retains its
old boundary. The visible winding lava and its hazard checks share the same
layout function. All three bridges, the approach road and team spawns are safe.

This is still solo practice. Live GameKit multiplayer is not implemented. Castle
ground-level courtyards and gates are navigable. Building interiors, stairs and
upper floors do not have supported vertical locomotion. The
new source matches the supplied castle assembly structurally; a pixel-identical
Blender lighting result is not claimed.

## Building and assets

The included Xcode project targets iOS 18+, and the GitHub workflow selects Xcode
16.4. `Castle.usdz`, `TerrainRock.jpg`, four WAVs, the asset catalog and compiled
Metal library are included in the app. No conversion packages are needed in CI.

`Tools/generate_project.py` regenerates project metadata and synthesized audio.
`Tools/build_castle_from_glb.py PATH.glb` recreates the current castle using
`numpy`, `Pillow` and `usd-core`. Retain the latest GLB separately for that optional
step, followed by `python Tools/build_castle_navigation.py` to regenerate the
matching collision data. Do not replace the USDZ without regenerating navigation.
The original GLB is not duplicated in the source archive or app. The runtime USDZ is ready
to build. Older conversion scripts/documents remain historical and should not
be used to overwrite this release's castle.

Original source assets are retained. `SourceAssets/castle-direct-import.json`
records the current source checksum, retained triangle count, omitted debris,
normalization and texture sizes. The terrain rock texture is taken from the
supplied castle's rock material; no external game assets were copied.

## Verification limits

Source grammar, project references, asset decoding, USD material/UV references,
geometry fidelity and archive integrity were checked. Native Xcode compilation,
RealityKit appearance, on-device frame rate/memory, repeated speech and the
optional XCTest workflow have not been run here. See **VALIDATION.md**. No remote
repository commit or GitHub build was submitted from this workspace.

The user reported the earlier Ember crash stopped reproducing before this update.
Its cause remains unknown. This release defaults to clean rendering and retains
the previous recovery path; it is not evidence that the crash has been diagnosed.
