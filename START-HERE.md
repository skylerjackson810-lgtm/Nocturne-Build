# Install Nocturne 0.5 from Windows

This ZIP is the complete source project, including the earlier gameplay features.
It is not an IPA.

1. Extract `Nocturne-Moonlit-Valley-Complete.zip`.
2. Replace the matching folders/files at the top level of your `Nocturne-Build`
   repository. Preserve the folder structure; do not upload the ZIP itself or
   put everything inside an extra parent folder. Include the new Game Swift files,
   `Resources/Castle.usdz`, `Resources/TerrainRock.jpg`, `Nocturne.xcodeproj`,
   `Info.plist` and the updated `.github/workflows` files. Keep a backup of your
   working commit and merge any separate edits of your own.
3. Commit, then open Actions → Build unsigned iOS IPA for that new commit. The
   workflow runs on pushes to main and can also be started manually.
4. Download `Nocturne-unsigned-IPA` from the successful run's Artifacts section.
   Extract the artifact and install the IPA with the same Sideloadly setup that
   worked previously.
5. Verify the menu says **v0.5** and Settings → Build says **0.5.0 (6)**.

## What to check

- Select The Cinder Caldera and Ember Keep. You start on a safe forecourt facing
  the arena; turn around to view your castle. Its structure should match the
  supplied GLB/render, at a larger scale than the old miniature version.
- Choose Moon Keep and repeat. It is the other starting team in the same map.
- Inspect stonework, roofs, courtyard buildings and cliffs from outside. The
  castle's interior is not yet navigable; coarse castle collision is retained.
- Look for the dark sky, stars, moon, layered cliffs, winding lava and mist near
  the outer valley. Cross the lava on one of the three broad stone bridges.
- Check the smaller book, distinct pages, glove fingers, cuffs and casting curl.
  Flip pages with arrows/emblems or controller LB/RB; speak to cast.
- Speak Fireball, Ice Shards, Mud Blast and Shadow Bolt with a pause and cooldown
  between casts. Check menu music and spell sounds. Death still disarms speech;
  re-arm the microphone after respawning.
- Revisit the original Hollow Court to confirm it still opens.

**Leave Settings → Volcano graphics → Legacy pixel filter OFF initially.** It
starts off in this release even if the older version's filter was enabled. The
main visual update works without it. Enabling it applies coarse processing on
the next entry and can obscure material detail.

## If something fails

For build errors, share the first actual Swift/Metal error from Build unsigned
iPhone application, not only the final exit-code line. Native compilation could
not be performed in this environment.

For a device crash, note the build version, selected team, whether the legacy
filter was on, and attach the newest Nocturne crash report if available.
For visual issues, send a screenshot from the castle forecourt with the castle
in view. Device rendering and performance still need verification.

For speech issues, Settings → The sound of magic retains the full speech status,
diagnostic code, Test sound and permission link. The compact gameplay HUD uses a
microphone icon; it does not remove the underlying diagnostics.
