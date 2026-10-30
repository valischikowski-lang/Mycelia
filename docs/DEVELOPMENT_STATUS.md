# Development status (v0.3)

## Directive 4.0 — phase status

| Phase | Status |
|---|---|
| 1 Quest-UI bug | **Done.** Root cause fixed; regression tests cover 6 screen sizes, every quest state and every touch input. |
| 2 Classes | **Done.** 4 callings, selection screen, avatars, 20 items, stats, save compatibility. In-world *trials* are presented as text in the selection screen, not as playable mini-levels yet. |
| 3 Real-time combat | **Done for the slice.** Weapons, shields, bows, dodge, parry, abilities, enemy AI for 12 creature types, Spore Golem boss with phases, combat camera, touch controls. Not yet: dedicated weapon animations beyond procedural swings, hit-stop, gamepad aim assist tuning. |
| 4 Factions & villages | **Done in a compact form.** Four small settlements in the meadow (not separate large regions), reputation, guards, merchants, mentors, vaults, disguises. Not yet: day/night schedules, faction dungeons, faction bosses. |
| 5 Open world | **Partly.** Treasure chests and Class Seals added. Not yet: new regions, dungeons, random events, destructible objects. |
| 6 Story & quests | **Partly.** Four class quests and the mythology (Ysmera, the Hollowing, the four Keys) exist. Not yet: restructured main story chapters, quest-log categories for class quests. |
| 7 Learning Paths & Mana | **Done.** 20 paths, Mana Essence economy, ability upgrades, world talents. |
| 8 Visual revolution | **Partly** (dark-fantasy pass from v0.2). Not yet: chromatic-aberration/dream-distortion post-effects with quality levels, new audio. |
| 9 QA | Ongoing: 79 automated tests (2,500+ checks) run headless on every change. |

## What was tested and how

- Automated: `godot --headless --fixed-fps 60 res://tests/test_runner.tscn`
  (79 tests: quest UI/touch input, classes, real-time combat incl. every
  ability, bosses, packs, treasure and seals, learning paths, factions,
  plus the earlier suites).
- Visual: screenshots with Xvfb + OpenGL compatibility renderer
  (`tools/dev/capture_*.tscn`).
- **Not tested on a real phone or iPad** in this environment. Frame rates
  measured here use a software renderer and say nothing about devices.

# Development Status

_Last updated: 2026-10-30, v0.1.0 vertical slice_

## Verified in this environment

The environment was a Linux container with Godot 4.3-stable and no GPU.

- **Rendering:** rendered through Xvfb, llvmpipe and the OpenGL3 (Compatibility) renderer. The Mobile (Vulkan) renderer could not run here because Vulkan was unavailable.
- **Scripts:** all 98 compile (`tools/dev/check_scripts.tscn`).
- **Tests:** `tests/test_runner.tscn` reports **51 run, 0 failed, 278 checks**. The tests cover:
  - inventory, progression, skills and the deck
  - quests and dialogue conditions
  - combat rules, AI, boss phases and determinism
  - save roundtrip, slot files, corruption fallback and v1→v3 migration
  - player movement, jump, collision, pitch limits, touch input and disabled input
  - the full combat state machine with one enemy and with two enemies (targeting)
- **Screenshots** of every major screen were captured and reviewed:
  - main menu, meadow (twelve viewpoints), dialogue
  - every Grimoire tab
  - combat: cards, targeting, spell effects and victory
- **Meadow build time:** about 1.0–1.4 s on the desktop CPU. It is generated procedurally from a fixed seed.

## Status of the vertical-slice checklist

| # | Requirement | State |
|---|---|---|
| 1 | Main menu | ✅ |
| 2 | New Game | ✅ |
| 3 | First-person movement | ✅ tested |
| 4 | Mobile control architecture | ✅ implemented and logic-tested; ⚠ not tried on a real touchscreen |
| 5 | Detailed Dreaming Meadow | ✅ |
| 6 | Procedural mushrooms | ✅ 7 shapes plus clusters, floating and twisted variants |
| 7 | Custom materials | ✅ 6 spatial shaders, 1 sky shader, 3 canvas shaders |
| 8 | Environmental particles | ✅ |
| 9 | Interaction | ✅ |
| 10 | Mushroom Keeper NPC | ✅ |
| 11 | Dialogue | ✅ 3 dialogue trees |
| 12 | Spore Fragments | ✅ |
| 13 | First quest | ✅ covered by a test that plays it through the dialogue |
| 14 | ≥5 working spells | ✅ 14 |
| 15 | Tactical combat | ✅ |
| 16 | ≥2 enemy types | ✅ 6 |
| 17 | XP and rewards | ✅ |
| 18 | Inventory | ✅ |
| 19 | Save/load | ✅ |
| 20 | Return from combat to exploration | ✅ |

## Exact next actions

1. Export to an Android device: install the Godot 4.3 export templates and the Android SDK, then set up a keystore. Measure FPS on the Low and Medium presets with the F3 overlay and `user://perf_log.csv`, and tune scatter counts.
2. Play the whole main story by hand, end to end, in the editor. Tests cover the logic, but a person has not yet played through all three main quests.
3. Navigation for world creatures: they currently move straight towards targets and can pass through props.
4. Expand to the Whispering Forest: add its `BiomeData`, a region script and a `Database.REGIONS` entry, then mark the northern gate `available`.

## File map for continuation

| What | Where |
|---|---|
| Content definitions | `tools/build_content.gd`, `resources/dialogue/*.json`, `resources/skills/*.json`, `resources/shops/*.json` |
| Region layout | `scripts/world/meadow/dreaming_meadow.gd` (layout constants at the top), `meadow_landmarks.gd` |
| Combat | `scripts/combat/` (rules: `battle_state.gd`; state machine: `combat_manager.gd`; visuals: `combat_arena.gd`, `scripts/effects/spell_vfx.gd`) |
| Visual QA tools | `tools/dev/capture_tour.tscn`, `capture_ui.tscn`, `capture_menu.tscn`, `preview_generators.tscn` |
