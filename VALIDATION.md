# Validation record — Nocturne 0.3.0 (3)

Completed locally:

- Inspected all three supplied art references.
- Checked the current public repository revision `3c3a4e35fff03c4f53e1ceb72a66976ac3d5c7e7`: its changes since the prior base are the previously delivered low-poly/audio update.
- Swift grammar: 19 Swift files (17 application, 2 XCTest), zero syntax errors.
- Xcode project: 77 objects; source/resource and scheme references resolve.
- Metal source explicitly assigned to the application Compile Sources phase.
- Four WAV resources assigned to Copy Bundle Resources; each is valid non-silent mono 16-bit PCM. Menu track is 32 seconds, with near-zero samples at its loop boundary.
- Version metadata is 0.3.0 (3); permissions and landscape orientation entries remain present.
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

Not executed locally:

- Native Swift type checking, Metal compilation, linking, signing, or XCTest.
- Native SwiftUI layout and RealityKit visual validation against the references.
- Real-device repeated speech, speaker/headset routing, interruptions, or controller tests.
- Frame-rate, power, memory, and sustained thermal profiling.

The optional `Run iOS regression tests` workflow is included for native XCTest. It does not verify real microphone input or replace the iPhone checklist in START-HERE.md. Structural checks alone do not establish a successful iOS build or fix the reported device failure conclusively.
