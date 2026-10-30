class_name ClassData
extends Resource
## One of the four Dreamer callings chosen at the Fourfold Threshold.

@export var id: String = ""
@export var display_name: String = ""
@export var tagline: String = ""
@export_multiline var lore: String = ""
## The trial the Threshold Stone sets for this calling.
@export_multiline var trial: String = ""
@export var faction_id: String = ""
@export var color: Color = Color.WHITE
@export var glyph: String = "✦"
## Added to PlayerStats (e.g. {"max_health": 20, "defense": 3}).
@export var stat_mods: Dictionary = {}
## Movement / combat feel: {"move": 1.0, "dodge": 1.0, "stamina": 100, "regen": 0}.
@export var feel: Dictionary = {}
## Items given and equipped at the start.
@export var start_items: PackedStringArray = []
## Ability ids, in hotbar order.
@export var abilities: PackedStringArray = []
## Learning-path ids (resources/skills/<id>.json).
@export var learning_paths: PackedStringArray = []
## Avatar rig kind and options for CreatureBuilder.
@export var rig_kind: String = "dreamer"
@export var rig_opts: Dictionary = {}
