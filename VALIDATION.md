# Validation record — Nocturne 0.4.1 (5)

Completed locally:

- Inspected all three supplied art references.
- Checked the current public repository revision `3c3a4e35fff03c4f53e1ceb72a66976ac3d5c7e7`: its changes since the prior base are the previously delivered low-poly/audio update.
- Swift grammar: 21 Swift files (18 application, 3 XCTest), zero syntax errors.
- Xcode project: 83 objects; source/resource and scheme references resolve.
- Metal source explicitly assigned to the application Compile Sources phase.
- Four WAV resources assigned to Copy Bundle Resources; each is valid non-silent mono 16-bit PCM. Menu track is 32 seconds, with near-zero samples at its loop boundary.
- Opened the supplied USDZ with OpenUSD, inspected geometry/materials, and opened the normalized binary USDZ. It contains 309 retained meshes, about 18 × 10.55 × 13.65 metres, centered on the ground. Seven detached export pieces are omitted only from the runtime copy. The original USDZ had no images; the later GLB supplies 30 embedded texture images.
- Extracted and reduced the GLB textures to at most 512 × 512. Normal maps are renormalized after filtering. Source checksums, material names, texture transforms, packed roughness/metallic channels, and image-origin conversion are recorded in the importer. UV-less geometry retains plain fallback materials.
- Reopened the finished textured USDZ: all 219 texture asset references resolve to its 30 embedded PNG files, and all shader connections and material relationship targets resolve. Confirmed fallback surface outputs point to their own untextured shaders. Inspected a contact sheet of the ten color maps. Runtime castle size: 15,175,663 bytes.
- Original and runtime castle SHA-256 values match the import report. Runtime USDZ integrity and resource inclusion are checked by the validator.
- Version metadata is 0.4.1 (5); permissions and landscape orientation entries remain present.
- `git diff --check` passed.
- Complete-source ZIP CRC and required-file checks are performed by the packaging script.

Added or retained XCTest coverage:

- Partial results cannot cast; duplicate/retired utterances and sessions are rejected.
- Repeated named spells select and cast; page selection alone cannot fire.
- Cooldown speech selects without creating a deferred cast.
- Actual versus output-only route changes and retired observers.
- Empty speech recovery and bounded persistent-error retries.
- Low-poly triangle counts and outward flat normals.
- Lava channels burn; bridge crossings and spawn are safe.
- Projectile sweeps and movement collision.
- Opposing team spawns face the arena, avoid lava and castle blockers, permit movement toward the arena, and leave the original court spawn unchanged.

Not executed locally:

- Native Swift type checking, Metal compilation, linking, signing, or XCTest.
- Native SwiftUI layout and RealityKit visual validation against the references.
- Native RealityKit appearance of the restored texture tiling, normal maps and material channels.
- Real-device repeated speech, speaker/headset routing, interruptions, or controller tests.
- Frame-rate, power, memory, and sustained thermal profiling.

The optional `Run iOS regression tests` workflow is included for native XCTest. It does not verify real microphone input or replace the iPhone checklist in START-HERE.md. Structural checks alone do not establish a successful iOS build or fix the reported device failure conclusively.
