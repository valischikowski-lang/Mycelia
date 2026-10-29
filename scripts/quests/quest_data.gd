class_name QuestData
extends Resource
## Static definition of a quest. Runtime state lives in QuestLog.

enum Category { MAIN, SIDE, EXPLORATION, COLLECTION, COMBAT, DISCOVERY, DUNGEON }
enum State { LOCKED, AVAILABLE, ACTIVE, COMPLETED, FAILED }

@export var id: String = ""
@export var title: String = ""
@export_multiline var description: String = ""
@export var category: Category = Category.SIDE
@export var prerequisites: PackedStringArray = []
@export var min_level: int = 1
@export var objectives: Array[QuestObjectiveData] = []
## If true objectives must be completed in order; only the current one tracks.
@export var sequential: bool = true
## Start automatically once prerequisites are met.
@export var auto_start: bool = false
@export var reward_xp: int = 0
@export var reward_glimmer: int = 0
@export var reward_items: Dictionary = {}
@export var reward_spells: PackedStringArray = []
@export var reward_skill_points: int = 0
@export_multiline var completion_text: String = ""


func get_objective(objective_id: String) -> QuestObjectiveData:
	for o: QuestObjectiveData in objectives:
		if o.id == objective_id:
			return o
	return null


func category_name() -> String:
	return String(Category.keys()[category]).capitalize()
