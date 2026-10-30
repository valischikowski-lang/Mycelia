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
