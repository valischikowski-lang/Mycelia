# Changelog

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
