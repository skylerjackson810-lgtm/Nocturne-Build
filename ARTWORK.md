# Artwork and presentation

The bundled `Nocturne/Resources/Assets.xcassets/MoonlitCourt.imageset/moonlit-court.png` is original generated menu/background artwork created with the built-in image generation tool for this project. It is used by the native main menu/loading screen and the browser design preview. The file is not a screenshot of native gameplay.

Prompt:

> Use case: stylized-concept. Asset type: actual landscape background artwork for a dark wizard iOS game's main menu and loading screen, 1536x1024 or wide landscape. Create richly atmospheric high-end dark fantasy environmental game art: an ancient gothic wizard academy and ruined stone archway rising from a rocky island on the RIGHT TWO THIRDS of the composition; a luminous large full moon in upper right center, cold silver moonbeams, a deep midnight navy and near-black star-filled sky, delicate wisps of violet mist, a few magical purple embers. Scene at night, cinematic realistic painterly game art, weathered stone, haunting mysterious scholarly magic, sophisticated muted color, readable silhouettes. The LEFT THIRD and lower left should stay dark and uncluttered with negative space for title and menu buttons to be composited in code. There is a small arcane violet portal within the distant central arch. No text, no lettering, no UI, no logos, no watermark, no characters. This is background art only, not a fake gameplay screenshot.

All native arena meshes, spellbook page textures, glove geometry, projectiles, moon/stars and effect geometry are constructed procedurally by the Swift source. The short sound effects are synthesized by `Tools/generate_project.py`. No purchased asset pack, third-party game engine or external web font is required. Native UI icons use Apple's SF Symbols; typography uses system-available Georgia and system fonts.

`Preview/main-menu.png`, `Preview/loading-screen.png` and `Preview/menu-landscape.png` are captures of the included HTML design reference. They show menu/loading art direction; they do not claim native SwiftUI or RealityKit execution.
