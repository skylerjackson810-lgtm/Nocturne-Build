# Install Nocturne 0.3 from Windows

**This is the complete project, including original files and the new features. It is not an IPA.**

1. Extract `Nocturne-Cinder-Caldera-Complete.zip` on Windows.
2. In your existing `Nocturne-Build` repository, open **Code → Add file → Upload files**.
   Upload the extracted contents at the repository's top level, replacing matching
   paths. Preserve the folders. Do not upload the ZIP itself or add another parent
   folder around the contents. Include `Nocturne.xcodeproj`, `Game`, `Resources`,
   and `Info.plist` as well as the other source folders: this update has new files.
   Keep a copy/commit of your working version; merge any edits you made separately.
3. Commit the upload. The existing **Build unsigned iOS IPA** workflow starts on
   a push to main. You can also run it manually from Actions.
4. Open the successful run for that new commit, download **Nocturne-unsigned-IPA**,
   extract it, and install the new IPA with Sideloadly using the same signing setup
   as your working installation.
5. Confirm the main menu says **v0.3** and Settings → Build says **0.3.0 (3)**.
   If not, you installed an old artifact or did not replace the project files.

The included build workflow additionally checks that menu.wav and default.metallib
are inside the built app. No new Apple credentials or package dependencies are needed
to build the unsigned IPA. No remote files or Actions runs were changed here.

## What to try first

1. Listen for the new menu music. Settings has a Menu music toggle and Test sound.
2. Use **SELECT MAP** to choose **The Cinder Caldera** or **The Hollow Court**.
   The first is the new red-fog volcano; the second preserves the original test map.
3. Enter the realm. In the volcano, cross lava using the three stone bridges.
   Walking directly into lava damages you; the spawn and central path are safe.
4. Say **Fireball**, pause briefly, and wait for the cooldown. Repeat five times.
5. Say **Ice Shards**, **Mud Blast**, then **Shadow Bolt**, waiting for recovery
   each time. The book should change pages automatically; each spell has distinct
   color, speed, damage, and projectile behavior.
6. Tap the page arrows or spell emblems, or press controller LB/RB. The book should
   turn pages without firing. Say the selected spell to cast; saying a different
   known spell also selects and casts it when ready.
7. Toggle the mic off/on, pause/resume, and try a headset connection change.
   Game sounds should not disappear just because speech stops. Death intentionally
   disarms speech; tap the mic after respawning.

## If the microphone still stops

The exact post-cast error from your newest installation has not yet been captured.
This revision adds recovery and better diagnostics but still requires a real-phone
test. Open **Pause → Settings → The sound of magic** and send:

- The full speech status and **Last speech diagnostic** text (including error code).
- Whether the mic level bars move when you speak.
- Whether the problem happens on the first cast or after several casts.
- Your iPhone model/iOS version and whether headphones are connected.
- Confirmation that Settings shows **0.3.0 (3)**.

Try it in the original Hollow Court as well. That distinguishes a speech problem
from anything specific to the new map. On-device English (US) recognition remains
required; the app does not silently switch to cloud speech.

## Verification status

Source grammar, project references, music resources, and archive integrity were
checked here. Native Xcode/Metal compilation, XCTest, real iPhone audio, and the
rendered art style have not been verified in this Linux workspace. Build the new
IPA and use the device checklist above. The optional **Run iOS regression tests**
workflow can run the included XCTest suite on GitHub's macOS runner.

The map is original procedural retro-style art inspired by your screenshots,
not a copy of their assets or a promise of an exact visual match before device
tuning. README.md and VALIDATION.md describe the implementation and limits.
The older GITHUB-FIX.md and LOWPOLY-AUDIO-UPDATE.md describe historical releases;
use this guide for the current complete project.
