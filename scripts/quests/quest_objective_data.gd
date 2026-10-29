class_name QuestObjectiveData
extends Resource
## One objective inside a QuestData.

enum Type { TALK, COLLECT, DEFEAT, VISIT, ACTIVATE, DISCOVER }

@export var id: String = ""
@export var description: String = ""
@export var type: Type = Type.VISIT
## npc id, item id, creature/encounter id, location id, object id or area id.
@export var target_id: String = ""
@export var required_amount: int = 1
## Optional world-space hint shown on the map (Vector3.ZERO = none).
@export var map_hint: Vector3 = Vector3.ZERO
@export var hint_region: String = ""
