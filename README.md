# Nocturne — The Hollow Court

A native iOS first-person wizard training prototype. Dark fantasy main menu, real scene-loading screen, and a procedural 3D courtyard under a moonlit, star-filled sky.

## Run on your iPhone

1. Open `Nocturne.xcodeproj` in **Xcode 16 or newer on a Mac**. No package manager or third-party dependency is needed.
2. Select the **Nocturne** target → Signing & Capabilities → choose your development team. Change `com.example.NocturnePrototype` to your own unique bundle identifier if needed.
3. Connect your iPhone running **iOS 18 or later**, select it as the run destination, and press Run. Enable Developer Mode/trust the computer if iOS requests it.
4. Play in landscape. Choose an order and select **Enter the court**. Allow Microphone and Speech Recognition when prompted.
5. Move with the left thumbstick; drag the right half of the display to look. Speak **“Fireball”**, then briefly pause. No touch or controller button fires a spell.

The project includes source, artwork and audio. It is **not an installable IPA or a TestFlight build**. This environment cannot sign, compile or run native iOS applications. Opening the ZIP on an iPhone alone will not install the game. Xcode/device build validation remains required.

## What is implemented

- Dark, gold-accented SwiftUI main menu with moonlit gothic artwork, floating embers, functioning class selection, grimoire and settings.
- Real loading progress through scene creation, rig creation and effect preparation.
- First-person RealityKit world: stone court, arch, pillars, distant towers, full moon, stars and ambient violet wisps.
- Camera-attached open 3D book with generated incantation textures; gloved right hand, charge effect and casting animation.
- Touch movement/look and hardware `GCController` stick mapping. A custom SwiftUI touch joystick shares the same input router with physical controllers.
- Apple's `SFSpeechRecognizer` and `AVAudioEngine`, with required on-device recognition, silence-based utterance finalization, replay suppression, task rotation and microphone controls.
- Fireball cooldown and windup; pooled fireballs and impact bursts; swept projectile collisions; five sentinels that require two hits, fire dodgeable violet bolts and respawn.
- Class-specific health, movement and cooldowns. All three classes practice Fireball in this prototype.
- Ten-sentinel training goal, health, hit feedback, death/respawn, pause/resume, menu return, sensitivity, invert-Y, sound and reduced-motion settings.
- Bundled generated sound effects, with no spoken incantations in the audio assets.

## Scope and current limitations

This is a **solo training slice**. There is no connected GameKit multiplayer, ranked progression, save-game persistence, additional spells or Volcano/Ice/Swamp map implementation in this build. Those remain in the previously supplied architecture. The sentinels are local practice enemies, not networked players.

The 3D assets are intentionally procedural prototype art. The menu backdrop is generated environmental artwork; it is not a screenshot of the native arena. `Preview/menu-preview.html` provides an interactive menu/loading design preview, not a second implementation of the gameplay. It can be opened in a desktop browser and does not use the microphone.

The prototype runs simulation and presentation on the main actor at fixed 60 Hz steps, with a bounded catch-up window and pooled effects. It prioritizes a complete small training loop; dedicated simulation execution, world mesh batching, adaptive quality and measured minimum-device thermal budgets remain production work. Long suspension pauses gameplay rather than catching up hidden combat.

On-device Speech support depends on the device, locale and available speech resources. The prototype uses `en-US` and refuses cloud fallback. You can explore the court if recognition is unavailable; casting remains unavailable. On a real device, test short, clearly spoken incantations and a brief pause. Speaker audio/noise can cause recognition mistakes; headphones help. The two-and-a-half-second final-audio freshness limit is a prototype latency policy, not proof of speaker identity.

Recognition deliberately has a short gap while finalizing each utterance. If audio routing changes or an interruption occurs, tap the microphone to reconnect. When the player dies, recognition stops and must be explicitly rearmed so an old utterance cannot fire after respawn.

## Validation

`Tests/` contains XCTest cases for voice-only gating, duplicate/stale utterances, cooldown handling, projectile sweeps and movement collision. Run with **Product → Test** using a supported iOS simulator/device. These tests were authored but could not be executed in this environment.

Local checks cover Swift grammar parsing, plist/asset validity, Xcode source/resource references and archive integrity. An HTML visual preview was rendered separately to inspect the menu/loading design. It does not validate SwiftUI layout or RealityKit performance.

For the final release gate, build with Xcode on the deployment SDK, run a real iPhone voice test, test Bluetooth/controller hot-plug and microphone route changes, and profile a sustained training session. This source has not been certified production-ready or App Store-ready.

## Project organization

| Folder | Contents |
|---|---|
| `Nocturne/App` | SwiftUI application lifecycle |
| `Nocturne/Game` | Training loop, collision math, scene and rig construction |
| `Nocturne/Gameplay` | Adapted voice-gated SpellEngine and core models from the blueprint |
| `Nocturne/Platform` | Apple Speech/audio lifecycle and controller/touch input |
| `Nocturne/UI` | Menu, loading screen, grimoire, settings, HUD and pause screen |
| `Nocturne/Resources` | Bundled artwork, audio and launch color |
| `Tests` | Native XCTest regression cases |
| `Preview` | Browser-based menu/loading visual reference |

## Framework references

- [Apple: non-AR ARView initialization](https://developer.apple.com/documentation/realitykit/arview/init(frame:cameramode:automaticallyconfiguresession:))
- [Apple: recognizing speech in live audio](https://developer.apple.com/documentation/speech/recognizing-speech-in-live-audio)
- [Apple: on-device recognition requirement](https://developer.apple.com/documentation/speech/sfspeechrecognitionrequest/requiresondevicerecognition)
