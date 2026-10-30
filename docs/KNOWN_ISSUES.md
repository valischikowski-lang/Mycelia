# Known Issues

## Not verified on target hardware

- **Mobile renderer.** The Mobile renderer was never run, because the development container had no Vulkan. All screenshots come from the Compatibility (OpenGL) renderer on llvmpipe, and some shading may differ slightly on Vulkan Mobile. No Android or iOS build has been made: the export templates are not installed. `export_presets.cfg` is prepared.
- **Performance.** Performance was measured only as primitive and draw-call counts on desktop software rendering. On Medium the meadow is roughly 150k–550k primitives and 190–680 draw calls depending on the view. Device FPS is unknown. The Low preset reduces scatter density to 45%, turns off shadows and glow, and renders at 70% scale.
- **Touch controls.** These are tested through `TouchInput` logic but not on a physical touchscreen. The feel of look sensitivity still needs tuning on a device.
- **Audio.** All sounds are synthesized and play through the dummy audio driver in CI. Their mix and levels have not been reviewed by ear.

## Gameplay

- World creatures have no navigation mesh. They walk straight towards targets and can clip through rocks and stems.
- Ordinary creatures respawn 150 s after being defeated, but only while the player is more than 45 m away. Unique and story creatures never respawn.
- Ollo's shop lets you buy equipment you already own.
- The Hollow Gate golem can be challenged at any level. This is intentionally optional, but it is very hard below level 4.
- The Whispering Forest and Forgotten Caves gates show "sealed" messages. They are placeholders for future regions.

## Technical

- The test runner prints "ObjectDB instances leaked at exit" warnings. These come from autoload and RefCounted cycles at shutdown and don't affect gameplay.
- The headless dummy renderer logs `mesh_get_surface_count` errors during combat tests. This is harmless.
- Flowers switch to their merged far mesh at 26 m, and the swap can be visible as a small pop.
- The cap colliders on giant mushrooms are convex hulls of the cap's outer surface, so they are approximate near wavy rims.
