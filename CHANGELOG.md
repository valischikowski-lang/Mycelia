# Changelog

## [0.3.0] — 2026-10-30: the Deep Fantasy revolution

### Fixed

- **Critical:** the quest tracker could cover the jump/sprint buttons on touch screens. Godot's emulated mouse click then opened the journal and froze the controls. The tracker is now display-only, height-capped and kept clear of every touch control. Non-button HUD elements ignore input, and the touch controls swallow emulated clicks from their own fingers. A regression test covers six screen sizes and every quest state.

### Added

- **Four callings:** Assassin, Spirit, Wizard and Grimlet. The Fourfold Threshold selection is shown on new games and for old saves. Each calling has:
  - its own avatar
  - 5 signature items with weapon stats and specials
  - 5 real-time abilities
  - stat modifiers
- **Real-time combat** (`scripts/combat/realtime/`):
  - player actions: light combos, heavy attacks, dodge, block and parry
  - bow with ember, frost and spore arrows
  - weapon switching, lock-on and an over-the-shoulder combat camera (can be turned off in Settings)
  - stamina and mana regeneration
  - death and respawn without losing anything
  - enemy patterns are data (`resources/combat/enemy_profiles.json`): telegraphed melee, leaps, projectiles, area attacks, zones, shockwaves, summons, blinks, heals, stealth and shields
  - enemy weak spots, statuses, packs, and boss phases
- **Learning Paths:** 20 paths with 80 steps (`tools/build_learning_paths.py`). Mana Essence is the new currency for them.
- **Grimoire:** new Abilities and Learning Paths tabs.
- **Treasure:** 11 chests in the meadow, plus Class Seals (shadow, astral, echo, rune, root, mycelium), the Wanderkey and faction vaults.
- **Factions:**
  - reputation with five tiers
  - four settlements with mentors, merchants, guards and villagers
  - disguises, goodwill tasks, faction signets, four class quests and four guard types

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
