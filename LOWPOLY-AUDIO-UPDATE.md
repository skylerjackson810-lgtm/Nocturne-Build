# Nocturne: low-poly graphics and audio repair

This is a source update for `skylerjackson810-lgtm/Nocturne-Build`, based on
commit `8761f8c99a93bc8bfc9682aacb6561d2042418ec`. It is not an IPA.
No GitHub files or Actions runs were changed remotely.

## Install this update from Windows

1. Extract `Nocturne-LowPoly-Audio-Update.zip`.
2. Open your existing GitHub repository's **Code** tab at its top level.
   Choose **Add file → Upload files**. Drag the extracted `Game`, `Gameplay`,
   `Platform`, `UI`, `Tests`, and `Tools` folders into the upload area, preserving
   their folder paths. Upload this guide as well if desired. Commit the update.
   Do not upload the ZIP itself or put the folders inside another parent folder.
   These files replace matching paths; they do not replace your entire project.
   If you have edited these same files since the base commit, merge those edits
   instead of overwriting them.
3. Your existing push workflow builds the new IPA. In **Actions**, open the run
   for your new commit, wait for success, and download `Nocturne-unsigned-IPA`.
   Extract that download and install the new `.ipa` with Sideloadly as before.

The working Xcode project, bundle identifier, workflow, and existing resource
files are unchanged. You do not need to regenerate the project.

## What changed

- The actual 3D arena uses cached, flat-shaded polygon meshes: 48-triangle orbs,
  8-triangle stars, hexagonal tapered pillars, pointed tower roofs, angular rocks,
  and robed sentinels wearing pointed wizard hats. Hands and spell effects inherit
  the faceted orb meshes. The moon, stars, dark palette, and first-person rig remain.
  The existing illustrated menu background is unchanged.
- Normal audio-category/output notifications no longer automatically disable
  speech. A changed microphone input/format rebuilds capture and discards the
  interrupted phrase. Queued notifications from a retired session are ignored.
  Calls and audio-service resets still stop casting with an explanatory message.
- Stopping speech no longer deactivates the game sound session. Game playback is
  activated independently, uses default audio mode instead of measurement mode,
  and keeps the built-in speaker as the default when recording without headphones.
- Spell effect volume is increased. Missing assets and playback failures are
  reported rather than silently skipped. This prototype still has no music or
  continuous ambient soundtrack: its sounds are casting, impacts, and damage.
- A live input-level meter appears below the microphone button. Game Settings
  includes **Test sound**, the selected output route/volume after a successful
  test, and the full speech status. Test sound previews one effect, even if the
  effects toggle is off; it never fires a projectile or bypasses voice activation.
- Permission/on-device-recognition errors are more specific. Recognized quiet
  speech is no longer discarded solely because its amplitude missed a threshold.

## Test on your iPhone

1. Open the game's Settings and press **Test sound** with iPhone media volume up.
   Check the output name shown; disconnect headphones if testing the phone speaker.
2. Enter the court. Grant both Microphone and Speech Recognition access if asked.
   Say “Fireball,” then pause briefly. The meter should move, the transcript should
   appear, and an accepted cast should produce a visible projectile and sound.
3. Toggle the microphone off. Enemy damage effects should still be audible.
4. Turn it back on. Connect/disconnect a headset while playing: capture should
   reconnect if a microphone is available. Repeat the whole spell after switching.
5. Pause/resume and leave/re-enter several times. Confirm no spurious “Audio
   changed” shutdown occurs and no old phrase fires after resuming.
6. If a call interrupts the game, end the call and resume. Re-arm the microphone
   if prompted. If an error persists, send the full Settings speech status,
   Test sound result, your iPhone model/iOS version, and whether the meter moves.

Voice firing still requires English (US) on-device recognition; no cloud or
button-firing fallback has been added. This remains the existing solo practice
arena, not completed multiplayer or the three planned elemental maps.

## Verification and limits

Local Swift grammar validation passed for all 16 Swift files. Project references,
asset/plist/scheme structure, and inclusion plus non-silent PCM contents of all
three WAV files were checked. `git diff --check` passed.

Regression XCTest cases were added for bounded mesh geometry, outward flat normals,
unchanged audio input, actual input changes, and stale-session route notifications.
The existing voice-only casting tests remain unchanged. Xcode compilation, XCTest
execution, visual rendering, and real-device microphone/speaker behavior could not
be tested in this Linux workspace. The existing GitHub workflow builds the app but
does not run XCTest; its successful new build and the device checks above remain
necessary before treating this as verified on your phone.

Apple references: [audio route notifications](https://developer.apple.com/documentation/avfaudio/avaudiosession/routechangenotification)
and [RealityKit mesh descriptors](https://developer.apple.com/documentation/realitykit/meshdescriptor).
