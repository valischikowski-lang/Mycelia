class_name CreatureData
extends Resource
## Static definition of a creature: stats, abilities, AI and rewards.

enum Personality { AGGRESSIVE, DEFENSIVE, TACTICAL, BOSS, TRICKSTER }

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var element: String = "fungal"
@export var level: int = 1
@export var max_health: int = 30
@export var defense: int = 0
## Percent damage bonus applied to the creature's abilities.
@export var power: int = 0
@export var speed: int = 10
@export var abilities: Array[SpellData] = []
@export var personality: Personality = Personality.AGGRESSIVE
## Health fractions at which a boss enters its next phase, e.g. [0.5].
@export var phase_thresholds: PackedFloat32Array = []
@export var xp_reward: int = 20
@export var glimmer_min: int = 2
@export var glimmer_max: int = 5
## Array of {"item_id": String, "chance": float, "min": int, "max": int}
@export var loot_table: Array[Dictionary] = []
## Key used by CreatureBuilder to assemble the procedural model.
@export var visual_kind: String = "sporeling"
@export var visual_scale: float = 1.0
@export var tint: Color = Color(1, 1, 1)
## Exploration behaviour: "hostile" approaches, "neutral" wanders, "shy" flees.
@export var world_behavior: String = "hostile"
@export var lore: String = ""
