# Changelog

## [0.2.0] — 2026-10-30: the dark turn

### Changed

- The Dreaming Meadow is now a dark-fantasy night, with:
  - a near-black indigo sky with a slowly turning galaxy vortex, a ghost-light ribbon, and an amber moon with a sleeping face that sometimes opens its eyes
  - a darker palette, lower light and denser fog; only windows and lanterns stay warm
  - cobblestone paths
- The distant village of Sporehaven was replaced by the Nightspire, a dark castle of leaning witch-hat and mushroom-cap towers beyond the Northern Gate.
- The main-menu title uses sickly green, violet and amber, and a crone joins the menu diorama.

### Added

- Crookhollow: a hamlet of crooked, half-timbered witch houses with blue pointed roofs, glowing windows and a bubbling cauldron, reached by a branch path west of the main road.
- Bent iron lantern posts along the main path and the Crookhollow path. Their lights are off on Low quality.
- New enemies:
  - Hollow Crone and Cackling Crone: witches with two or three crooked teeth that hex, cackle, bite and brew
  - Gnasher Gremlin: goggles, propeller, wrench and spark bombs
- Encounters `enc_crone`, `enc_coven` (two crones), `enc_gremlin` and `enc_gremlin_gang`.
- Status effects Hexed, Bitter Brew and Giggling.
- Items: Crone's Tooth, Gremlin Cog, Toadstool Tea, Bottled Night and the Crooked Witch Hat.
- Mother Grizzleroot, a witch NPC in Crookhollow. She has her own dialogue, a brew shop, and a reward for crone teeth.
- Dev tool `tools/dev/capture_rigs.tscn` renders creature rigs for visual QA.

### Fixed

- Combat targeting with several enemies: tapping a card now hides the hand, makes every valid enemy pulse gold, and shows a target-button row. Tapping an enemy in the arena works too.
- Bounce mushrooms are now aimed with a ballistic solver, and the player keeps air momentum. Every hop on the Drift route and the Keeper's cap lands on its target, which `tests/test_bounce_route.gd` checks with real physics.

## [0.1.0] — 2026-10-30: first playable vertical slice

### Added

- Godot 4.3 project targeting the Mobile renderer, with a runtime input map and settings stored in `user://settings.cfg`.
- Procedural generators for mushrooms (7 cap shapes), trees, crystals, floating islands, flowers and terrain, plus scattering, LOD and static batching.
- The Dreaming Meadow region, with:
  - Umbel's house and the Lantern Cap
  - the Rootstone Circle and Glimmermere lake with its shrine
  - the Hidden Hollow and the Drift Isle bounce route
  - the Northern Gate and the Hollow Gate
  - the distant village of Sporehaven, the sky river and sky drifters
- A first-person controller for PC, gamepad and multi-touch; an interaction framework; NPCs and dialogue.
- Quests: three main and three side quests. Also inventory, equipment, XP and levels, the Fungal skill tree and deck building.
- Tactical card combat: 14 spells, 6 creatures, a boss with phases and charge attacks, per-discipline VFX, and a finite state machine.
- The Grimoire (character, inventory, spellbook, skills, journal, map, settings), a shop, the pause menu and the main menu.
- Save system: four slots, versioned format v3 with migration, backup fallback and autosave.
- Synthesized original audio: 43 sound effects, 1 ambience loop and 4 music loops (menu, exploration, combat, boss).
- A test harness with 51 tests, plus visual-QA capture tools.
