# Nocturne 0.6 — Restored Castle and Interiors

Complete native iOS source project. Follow **START-HERE.md** to build the unsigned
IPA on GitHub and install it using your existing Sideloadly setup from Windows.
This archive contains source and ready-to-use assets, not an IPA.

## Castle restoration

- Reuses the supplied castle's actual stone, rock, wood, roof, grass and path
  texture sets. There are no generic white fallback materials on castle meshes.
- Assigns matching textured materials to the 94 originally unassigned primitives,
  plus the invalid grass, wood and path material references. Entrance masonry,
  window surrounds, tower trim and small facade blocks use the existing stone set.
- Regenerates collapsed UV mappings and gives masonry a consistent world-scale
  texture mapping. Correct texture coordinates replace stretched lines and flat
  colour samples. Thirty embedded images remain at up to 1024 pixels.
- Repairs inward-facing triangle winding. All castle meshes are authored as
  double-sided; imported RealityKit PBR materials also disable face culling.
- Preserves the working castle rotations, courtyard spawn/respawn positions and
  flat gate approaches from 0.5.1. The original Hollow Court remains selectable.

## Enterable buildings

Three ground-floor spaces are accessible from each castle's courtyard:

- **East workshop:** through the doorway facing the courtyard; stone floor,
  textured interior walls, ceiling and a workbench.
- **West study:** a ground-floor doorway in the angled building, with a level
  interior, stone walls, ceiling and workbench.
- **North timber hall:** an open entrance, wooden floor and workbench.

The importer cuts real openings in the visible geometry and removes internal
caps/floor slabs that obstruct the new rooms. Stone thresholds bridge the
openings to the new floors. Collision is regenerated from that finished asset;
this does not merely turn wall collision off. Upper floors and tower interiors
are not part of this update, and locomotion remains on level ground.

## Gameplay retained

Four voice-only spells, book page switching, touch/controller input, menu music,
spell sounds, speech recovery, classes, practice targets, pause and health/respawn
are retained. Ember Keep and Moon Keep remain opposing starts in the volcano map.
The game is a solo prototype; live GameKit multiplayer is not implemented.

## Build and assets

The Xcode project targets iOS 18+; the GitHub workflow selects Xcode 16.4.
The supplied USDZ and generated Swift collision data are ready to build. No
Blender, Python or conversion packages are needed for the GitHub IPA build.

Optional asset regeneration, using the latest original GLB kept separately:

```sh
python Tools/build_castle_from_glb.py PATH_TO_LATEST_CASTLE.glb
python Tools/build_castle_navigation.py
python Tools/validate_castle.py
```

These tools require numpy, Pillow, usd-core, trimesh and networkx. Run both
conversion steps together; changing the USDZ alone would leave stale collision.
`Tools/castle_repairs.py` records the material choices, door cuts and room layouts.
`SourceAssets/castle-direct-import.json` records the source/runtime checksums,
geometry counts and per-piece repairs. Original source assets remain included.

`Tools/generate_project.py` regenerates Xcode metadata and procedural audio.
`Tools/preview_castle.py OUTPUT_DIRECTORY` is an optional offline asset reviewer,
using pyrender and PyOpenGL >=3.1.10. It is not a RealityKit gameplay renderer.
Older update documents describe previous releases; this README and VALIDATION.md
are authoritative for 0.6.

## Verification

Asset bindings, texture references, Swift grammar, Xcode project references and
both teams' gate routes pass local checks. All three interiors are reachable
from spawn, and entry/exit movement replays pass for both teams. Offline renders
were reviewed for surface coverage and the new openings. Native Xcode compilation,
iPhone rendering and frame-rate testing still require the GitHub/device build.
