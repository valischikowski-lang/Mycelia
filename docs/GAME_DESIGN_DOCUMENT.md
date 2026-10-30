# MYCELIA — Game Design Document (living)

## Pillars

1. **Curiosity is rewarded.** Light beams, floating islands, vine curtains and singing crystals all lead to something worth finding.
2. **A coherent dream.** Every system reinforces the same idea: the Mycelium, a living network that connects everything in the world.
3. **Readable tactics.** Every decision in combat should be meaningful: one spell per turn, plus mana, elements, statuses and telegraphed threats.

## Core loop

Explore → discover → collect → encounter → fight → earn rewards → progress → unlock new areas.

## Story (Act 1: The Sporelands)

The Mycelium is being **unwoven**: not cut, but gently pulled apart from somewhere far below.

1. **The First Awakening.** You wake in the Dreaming Meadow. Umbel the Mushroom Keeper sends you for three Spore Fragments, then teaches you Fungal magic. A hollow-eyed sporeling attacks you, and where it falls, a grey **Mycelial Rift** opens.
2. **The Hum Beneath.** You inspect the rift and attune the Rootstone Circle. Its startled Bloom Guardian wakes and you must calm it.
3. **The Sealed Gate.** You reach the Northern Gate, which won't open. You then wake the Ancient Spore Golem at the Hollow Gate. It gives you its heartspore, and the story hook points to the Whispering Forest.

Mysteries are revealed slowly through lore stones. The Dreamers' Shrine holds your own name, written in your own handwriting.

## Combat

- Your deck has 6–20 cards, with at most 3 copies of each spell. You draw up to 4 cards each turn and cast **one** spell.
- Mana starts at your maximum and regenerates 2 per turn, plus any skill bonuses. **Meditate** restores 3 mana instead of casting.
- Once per turn, **Swap** discards one card and draws a new one for free.
- Elements form a cycle: Fungal → Nature → Crystal → Cosmic → Fungal. Hitting the element you beat deals ×1.5 damage; the reverse deals ×0.75. Chaos deals ×1.1 against everything except itself.
- Statuses: damage over time, healing over time, shield, stun (Rooted), weaken, vulnerable, empower, evasion, armor, summon.
- Enemy AI scores each available ability by health, shields, existing statuses, elemental advantage and cooldowns, then weights that by personality: Aggressive, Defensive, Tactical, Boss or Trickster.
- The boss changes phase at 50% health and charges a large attack over a full turn. You can **interrupt** the charge with Rootbind or absorb it with Prism Ward.

### Spells (14)

| Discipline | Spells |
|---|---|
| Fungal | Sporeburst, Mycelial Mend, Puffcap Cascade, Spore Sentinel (skill), Rot Bloom (skill) |
| Crystal | Prism Ward, Shardstorm |
| Nature | Thornlash (0 mana), Rootbind, Wild Bloom |
| Cosmic | Gravity Well, Starfall Seed |
| Chaos | Kaleidoscope Rift, Paradox Gift |

### Creatures

| Creature | Element | Personality | Notes |
|---|---|---|---|
| Sporeling | Fungal | Aggressive | |
| Hollow-Eyed Sporeling | Chaos | Aggressive | Story fight |
| Crystal Beetle | Crystal | Defensive | |
| Dream Fox | Cosmic | Tactical | Neutral; challenge it to fight |
| Bloom Guardian | Nature | Tactical | Quest boss |
| Ancient Spore Golem | Fungal | Boss | Two phases |

## Progression

- **XP needed per level:** `40·L^1.6 + 20`.
- **Per level:** +14 health, +0.5 mana, +2 magic power, +1 defense, +0.4% critical chance, +3 spell power, and 1 skill point.
- **Spells learned by level:** 2 Rootbind, 3 Shardstorm, 4 Gravity Well, 5 Starfall Seed, 6 Kaleidoscope Rift.
- **Fungal skill tree:** four branches (Spore Damage, Defense, Healing, Summoning), three tiers each.

## Art direction (Dreaming Meadow palette)

- **Sky:** violet → magenta → warm orange horizon, with turquoise aurora ribbons and a ringed moon.
- **Ground:** teal grass, violet moss and coral paths, with a cyan Mycelium vein network pulsing outward from the circle.
- **Focal points:** the orange Lantern Cap, violet giant caps with cyan gills, a turquoise lake against violet rock, and golden lore bands.
- **Shapes:** organic, bent and asymmetric. Nothing is perfectly straight.

## Regions (planned)

1. **Dreaming Meadow** (done)
2. **Whispering Forest:** spiral trees, roots that move
3. **Crystal Marsh:** glowing water, reflections
4. **Floating Gardens:** vertical exploration, sky temples
5. **Forgotten Caves:** fungal networks, bosses
