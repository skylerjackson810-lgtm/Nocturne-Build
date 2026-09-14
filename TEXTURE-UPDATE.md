# Textured castle update — 0.4.1 (5)

The supplied `Castle+format+1.glb` contains the missing textures: 30 embedded PNG
images for ten surface sets, including stone, limestone, wood, roof shingles,
grass and bark. Each set includes color, normal and packed roughness/metallic
data. The earlier USDZ contained only material colors and UVs.

## Included changes

- Restored matching GLB materials onto the normalized castle already used by both
  teams. Castle geometry, opposing positions, collision boundaries and respawns
  remain as in 0.4.0; the original Hollow Court remains available.
- The finished model contains 30 embedded images referenced by 73 textured
  materials and is about 15.2 MB. Seventeen UV-less mesh pieces keep plain
  material fallbacks. This reduces asset size; actual GPU memory and frame rate
  still require device profiling.
- Reduced the original 2048/4096-pixel maps to at most 512 pixels per side for
  the intended retro look and a bounded texture budget. Normal vectors are
  renormalized after filtering. No replacement textures were generated.
- Preserved per-texture repeat scales and offsets, color factors, raw normal and
  roughness/metallic sampling, and the GLB's material channel assignments.
- Converted the image-origin convention when applying the GLB coordinates to
  USD materials. The existing geometry and UVs are retained.
- Preserved plain materials on meshes without UV coordinates. Two USD material
  names have no GLB counterpart and retain their existing colors. The two GLB
  material duplicates with invalid texCoord=-1 do not override valid definitions.
- Retained the prior volcano rendering repair, recovery toggle, spells, menu
  music and microphone changes.

## Source and runtime files

`Resources/Castle.usdz` embeds the optimized images and is the only castle file
loaded by the app. Both keeps clone one cached model with shared resources.

`SourceAssets/Castle-original.usdz` remains unchanged. The original 308,514,356-byte
GLB stays separate and is not included in the project ZIP or app. Its filename
and SHA-256 are recorded in `SourceAssets/castle-textures.json`. Keep your original
for future high-resolution exports. All optimized images and material definitions
needed to reproduce this build are included in `SourceAssets`.

Optional offline rebuild (requires `usd-core`, `Pillow`, and `numpy`):

```
python3 Tools/import_castle_textures.py
```

To re-extract from the original GLB, add `--glb PATH`. Running only
`Tools/prepare_castle.py` rebuilds the untextured geometry; run the texture importer
afterward to restore this release's materials. GitHub Actions does not run either
asset conversion script and needs no added dependencies.

## Installation and checks

Follow START-HERE.md to replace the full project, build a new unsigned IPA and
sideload it. Settings should show **0.4.1 (5)**. Enter the volcano, turn toward your
castle and inspect the stone, wood and shingles; repeat from the other team's
start. Try with retro effects off if the fog makes material details hard to see.

Source structure, packaged image data and USD shader references are checked here.
Native Swift/Metal compilation, RealityKit texture rendering, frame rate and
crash resolution still need GitHub/iPhone validation. This is a source update,
not an IPA or evidence of an on-device test.

Material conversion follows the [OpenUSD Preview Surface specification](https://openusd.org/release/spec_usdpreviewsurface.html)
and [glTF 2.0 material/texture definitions](https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html).
