# Nocturne 0.3 — The Cinder Caldera

A native iOS first-person wizard practice game. This complete source project includes the original Hollow Court, a new volcano arena, a four-spell grimoire, menu music, and revised microphone recovery.

Start with **START-HERE.md** for the Windows → GitHub Actions → Sideloadly installation steps. This ZIP is source, not an IPA. No remote repository changes or builds were submitted from this workspace.

## Playable features

- **The Cinder Caldera:** red atmospheric distance/height fog, low-resolution pixel/dither/grain treatment, bright textured lava, basalt paths and safe bridges, jagged spires, ruined towers, a distant volcano, and ashwarden practice targets. Lava deals 24 damage per second; bridge crossings are safe.
- **The Hollow Court:** the original moonlit test arena remains selectable in the main menu. Its layout is preserved and the new retro postprocess is limited to the volcano.
- First-person open book and casting hand; four original spell emblems are drawn in code and reused in the HUD, grimoire, and preloaded page textures.
- Page arrows, spell-emblem taps, and controller LB/RB select spells without firing. Speaking any known spell selects its page and casts it when ready.
- 32-second original ambient menu music, a music toggle, cast/impact/damage sounds, and a sound-output diagnostic.
- Touch joystick/look and physical controllers; class stats; pooled projectiles and impacts; five attacking targets; ten-target trial; respawn; pause/resume.

| Spoken spell | Behavior | Damage | Base cooldown |
| --- | --- | --- | --- |
| Fireball | Straight orange orb | 50 | 2.0 seconds |
| Ice Shards | Three fast cyan shards in a narrow spread | 24 per shard | 2.8 seconds |
| Mud Blast | Large, slower arcing projectile | 75 | 3.2 seconds |
| Shadow Bolt | Fast violet projectile | 35 | 1.6 seconds |

All orders can use all four spells in practice. Class cooldown modifiers apply. Recovery is shared across spells, so switching pages does not bypass it. An utterance spoken during cooldown can select a page but is consumed, never queued for later firing.

## Audio changes

The earlier error after a cast cannot be conclusively diagnosed without its exact current message and device logs. This revision addresses the following observed code weaknesses:

- Cast noise by itself no longer finalizes an empty speech task: a partial transcript is required before silence-based finalization.
- Completed recognition requests are retired without cancellation; a brief scheduled gap separates successive requests.
- Empty/no-speech tasks and transient failures reconnect automatically. Persistent errors stop after a bounded retry budget, while permission revocation stops immediately.
- Capture-engine stoppage has bounded recovery; microphone-input changes rebuild capture; output-only notifications and retired-session callbacks are ignored.
- The shared game audio session stays active when speech stops. Microphone meter, full status, raw diagnostic domain/code, and Test sound are available in Settings.

Only final recognized phrases can cast. Old sessions/utterances, stale audio, partial results, and page-button events cannot fire. English (US) on-device recognition remains required. No cloud transcription or audio upload was added. A short phrase, a brief silence, and waiting for cooldown give the most reliable input. Headphones are useful when testing speaker feedback. After death, re-arm the microphone explicitly.

## Build and validation

The included project targets iOS 18+, uses Xcode 16.4 in the existing macOS GitHub build workflow, and has no third-party runtime dependencies. The Metal shader is in Compile Sources and menu.wav is in Copy Bundle Resources. Use the included project rather than regenerating paths manually.

`Tools/generate_project.py` deterministically recreates the project and original synthesized audio. `Tools/validate_project.py` checks Swift grammar, project references, resources, music boundaries, and version metadata. `Tools/package_project.py` creates the complete source ZIP.

The normal GitHub build produces an unsigned IPA. The separately selectable **Run iOS regression tests** workflow runs XCTest on an installed iOS 18 simulator. Neither workflow was run from this workspace. Native Swift/Metal compilation, XCTest execution, actual iPhone rendering, microphone behavior, and performance remain unverified for this revision.

## Project layout

- `App/`: application lifecycle.
- `Game/`: gameplay session, spell definitions, map builders, rig and emblem rendering, retro Metal postprocessing.
- `Gameplay/`: domain models and voice-gated casting.
- `Platform/`: Speech/audio lifecycle and touch/controller routing.
- `UI/`: menu, map selector, loading, HUD, grimoire, settings, pause.
- `Resources/`: original menu artwork, synthesized sound effects and menu music.
- `Tests/`: casting, geometry, route/retry policy, and lava/bridge XCTest coverage.
- `Tools/`: project/audio generation, structural validation, source packaging.
- `Preview/`: historical v0.1 browser menu references, not screenshots of v0.3 or native gameplay.

## Scope

This is still a solo practice prototype, not a finished PvP game. GameKit multiplayer, progression, Ice/Swamp maps, enemy navigation, and status effects are not implemented. The reference images guided the retro art direction; no game assets or UI images were copied from them. The existing illustrated menu backdrop is retained and tinted for the volcano selection.

A full-frame Metal pass samples a coarser logical grid to achieve the pixelated look; it is not an internally low-resolution 3D renderer. Shader/draw-call cost and device thermals need profiling. Fog reconstructs positions from the actual projection/depth buffer and varies with distance, height, and location; it is not a flat translucent overlay. Rendering uses original procedural geometry/textures and is not guaranteed to exactly match the supplied reference screenshots before device tuning.

## Apple references

- [RealityKit postprocess context](https://developer.apple.com/documentation/realitykit/arview/postprocesscontext)
- [Postprocess output texture formats](https://developer.apple.com/documentation/realitykit/checking-the-pixel-format-of-a-postprocess-effect-s-output-texture)
- [Live audio speech recognition](https://developer.apple.com/documentation/speech/recognizing-speech-in-live-audio)
