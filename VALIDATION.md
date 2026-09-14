# Validation — Nocturne 0.5.0 (6)

Completed locally:

- Inspected the user's rendered Blender reference and latest GLB geometry.
- Directly converted the latest 37,653,912-byte GLB, not the previous material-less
  USDZ. Source SHA-256 is recorded in `SourceAssets/castle-direct-import.json`.
- Retained assembly: 308 mesh primitives, 86,730 triangles. Zero triangles removed
  from retained meshes; only the explicitly reported detached debris is excluded.
- Uniform normalization to 52 × 28.3196 × 38.6410 metres. Position round-trip
  error is below 0.000001 source units. Original triangle indices, transformed
  normals, material indices and per-slot texture coordinates are retained.
- Finished USDZ: 24,043,990 bytes, 64-byte aligned uncompressed entries, root USD
  first. All 30 embedded JPEGs decode and are at most 1024 pixels per side.
- All 219 shader asset references resolve. Shader connections resolve, and every
  bound UV reader has the corresponding mesh primvar.
- Swift grammar: 24 files (21 application, 3 XCTest), zero syntax errors.
- Xcode project: 91 objects; references and scheme resolve. Castle, terrain rock,
  music and effect resources are assigned to Copy Bundle Resources; Metal source
  remains in Compile Sources. Permissions and landscape settings remain present.
- Version metadata: 0.5.0 (6). Audio/resource validation and `git diff --check` pass.
- Packaging script checks the full source ZIP's CRC and required files.

Updated native regression coverage:

- Both keep spawns are safe, face the arena and move one metre without being
  clamped back to the old court boundary. Original court spawn remains unchanged.
- Winding channels burn; bridge centers and the approach corridor remain safe.
- Existing casting, speech retry, geometry and collision tests are retained.

Not executed here:

- Xcode Swift type checking, Metal compilation, linking, signing or XCTest.
- Native RealityKit visual inspection, texture/normal appearance and UI layout.
- iPhone memory, frame rate, thermals, input and repeated microphone testing.

The environment has no Xcode/Apple SDKs. No real-device gameplay screenshot is
included for this revision, and no claim of an exact lighting match is made.
The game remains a solo prototype with non-navigable castle interiors. The user
reported that the previous Ember crash stopped reproducing; no crash report was
received and the underlying cause has not been established.
