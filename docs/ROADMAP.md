# Roadmap

## Phases A–G (foundation through polish): done for the vertical slice

See DEVELOPMENT_STATUS.md for what has been verified.

## Next: Phase G2, device polish

- Profile on an Android mid-range device and tune scatter counts per preset.
- Tune touch look sensitivity and button sizes; add an option to adjust the touch layout.
- Add haptics on hits and level-up.
- Add a navigation mesh for world creatures.
- Do an audio mixing pass.

## Phase H: expansion

- **Whispering Forest:** a new `BiomeData` and region script, spiral-tree forests, moving roots, shrines.
- **New disciplines' skill trees:** Crystal, Nature, Cosmic and Chaos JSON trees, which the Grimoire already supports.
- **More spells (target 20+) and creatures**, through `tools/build_content.gd`.
- **Dungeons:** the Forgotten Caves, with chunked region streaming only once measurements justify it.

## Phase I: release preparation

- App icon variants (from `icon.svg`), a splash screen, signing and store metadata.
- Android AAB export via Gradle builds; iOS export through Xcode on macOS.
- A release checklist: run the tests, export on each platform, and run the performance logs.

## Long term: online (architecture-ready)

- Server-authoritative combat. `BattleState` can run on the server, with clients replaying its events.
- Player identity, replicated positions in shared regions, parties, and shared dungeon instances.
