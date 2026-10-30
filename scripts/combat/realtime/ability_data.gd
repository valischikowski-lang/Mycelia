class_name AbilityData
extends Resource
## A real-time class ability. `kind` selects the behaviour implemented by
## AbilityRunner; the numbers tune it. Abilities may also have a world use
## (`world_tag`) that opens class seals, reveals secrets and so on.

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var class_id: String = ""
@export var glyph: String = "✦"
@export var color: Color = Color.WHITE
@export var mana_cost: float = 1.0
@export var cooldown: float = 4.0
## dash, backstab, smoke, clone, nightfall, soul_pulse, companion, astral,
## shield, echo, bolt, nova, spiral, gravity, rift, snare, burst, barkskin,
## link, colossus
@export var kind: String = ""
@export var power: float = 10.0
@export var radius: float = 3.0
@export var ability_range: float = 8.0
@export var duration: float = 0.0
## Class-seal / world interaction this ability triggers ("" = none).
@export var world_tag: String = ""
## Mana required to learn it in its Learning Path (0 = known from the start).
@export var unlock_level: int = 1
