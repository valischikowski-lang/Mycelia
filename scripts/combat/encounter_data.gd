class_name EncounterData
extends Resource
## Configuration for one combat: which creatures, where, and what it rewards.

@export var id: String = ""
@export var display_name: String = ""
@export var enemies: Array[CreatureData] = []
@export var arena_theme: String = "meadow"
@export var music: String = "combat"
@export var can_flee: bool = true
## If true, enemies act before the player in round one.
@export var ambush: bool = false
@export var bonus_xp: int = 0
@export var bonus_glimmer: int = 0
## Extra guaranteed items, {"item_id": count}
@export var bonus_items: Dictionary = {}
@export_multiline var intro_text: String = ""
## Encounter can only be won once (story fights).
@export var unique: bool = false
