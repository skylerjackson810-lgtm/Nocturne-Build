# Install Nocturne 0.6 from Windows

This ZIP contains the complete source project and updated castle asset.

1. Extract `Nocturne-Castle-Restored-Complete.zip`.
2. Replace the matching files/folders at the root of your `Nocturne-Build`
   repository. Keep the folder structure and include `Resources/Castle.usdz`,
   `Game/CastleBases.swift`, `Game/CastleLayout.swift`, the Xcode project,
   `Info.plist`, updated tests and workflow files. Do not upload the ZIP itself
   or add another parent folder. Merge any separate changes of your own.
3. Commit and run **Actions → Build unsigned iOS IPA** for that commit.
4. Download **Nocturne-unsigned-IPA** from the successful run's Artifacts.
   Extract it and install the IPA using your working Sideloadly setup.
5. Confirm the menu says **v0.6** and Settings → Build says **0.6.0 (8)**.

## Check on your iPhone

- Enter the volcano with Ember Keep, then repeat with Moon Keep. Spawns stay
  inside the courtyard and both main gates still face the valley.
- Walk outside and inspect the rocks/walls that previously disappeared.
- Inspect the tree's surrounding stones, grass, stepping stones, upper tower
  trim and main entrance: former white fallback pieces should now be textured.
- Enter the east workshop, west study and north timber hall. Walk back out of
  each one. Their ground floors are playable; tower/upper floors are not.
- Check that the main gate remains passable and death returns you to your
  selected castle's courtyard.
- Check voice casting, sound, book controls and the original Hollow Court.

Leave **Legacy pixel filter OFF** while inspecting materials.

If GitHub fails, send the first Swift/Metal error from the build log. If a surface
still looks wrong on the phone, send its screenshot and confirm build **0.6.0 (8)**.
The asset was reviewed in an offline renderer; native RealityKit appearance and
performance still need real-device verification.
