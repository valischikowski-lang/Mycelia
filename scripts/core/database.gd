extends Node
## Read-only registry of authored content (Resources + JSON) indexed by id.
## Scans resources/ at startup; handles exported builds where .tres become
## .res or carry a .remap suffix.

const DIRS: Dictionary = {
	"items": "res://resources/items",
	"spells": "res://resources/spells",
	"creatures": "res://resources/creatures",
	"encounters": "res://resources/encounters",
	"quests": "res://resources/quests",
	"status_effects": "res://resources/status_effects",
	"biomes": "res://resources/biomes",
	"classes": "res://resources/classes",
	"abilities": "res://resources/abilities",
}
const DIALOGUE_DIR := "res://resources/dialogue"
const SKILL_DIR := "res://resources/skills"
const SHOP_DIR := "res://resources/shops"

## Region id -> scene. Regions not listed are not yet built.
const REGIONS: Dictionary = {
	"dreaming_meadow": {"name": "The Dreaming Meadow", "scene": "res://scenes/world/dreaming_meadow.tscn", "available": true},
	"whispering_forest": {"name": "The Whispering Forest", "scene": "", "available": false},
	"crystal_marsh": {"name": "The Crystal Marsh", "scene": "", "available": false},
	"floating_gardens": {"name": "The Floating Gardens", "scene": "", "available": false},
	"forgotten_caves": {"name": "The Forgotten Caves", "scene": "", "available": false},
}

var _tables: Dictionary = {}
var _dialogues: Dictionary = {}
var _skill_trees: Dictionary = {}
var _shops: Dictionary = {}


func _ready() -> void:
	reload()


func reload() -> void:
	_tables.clear()
	for table: String in DIRS.keys():
		_tables[table] = _scan_resources(DIRS[table])
	_dialogues = _scan_json(DIALOGUE_DIR)
	_skill_trees = _scan_json(SKILL_DIR)
	_shops = _scan_json(SHOP_DIR)


func item(id: String) -> ItemData:
	return _lookup("items", id) as ItemData


func spell(id: String) -> SpellData:
	return _lookup("spells", id) as SpellData


func creature(id: String) -> CreatureData:
	return _lookup("creatures", id) as CreatureData


func encounter(id: String) -> EncounterData:
	return _lookup("encounters", id) as EncounterData


func quest(id: String) -> QuestData:
	return _lookup("quests", id) as QuestData


func player_class(id: String) -> ClassData:
	return _lookup("classes", id) as ClassData


func ability(id: String) -> AbilityData:
	return _lookup("abilities", id) as AbilityData


func biome(id: String) -> BiomeData:
	return _lookup("biomes", id) as BiomeData


func status_effect(id: String) -> StatusEffectData:
	return _lookup("status_effects", id) as StatusEffectData


func dialogue(id: String) -> Dictionary:
	return _dialogues.get(id, {})


func skill_tree(id: String) -> Dictionary:
	return _skill_trees.get(id, {})


func shop(id: String) -> Dictionary:
	return _shops.get(id, {})


func all(table: String) -> Array:
	return (_tables.get(table, {}) as Dictionary).values()


func ids(table: String) -> Array:
	return (_tables.get(table, {}) as Dictionary).keys()


func skill_tree_ids() -> Array:
	return _skill_trees.keys()


## Adds or replaces a resource at runtime (used by tests and dev tools; a
## reload() restores the on-disk content).
func register(table: String, res: Resource) -> void:
	if not _tables.has(table):
		_tables[table] = {}
	(_tables[table] as Dictionary)[String(res.get("id"))] = res


func _lookup(table: String, id: String) -> Resource:
	var t: Dictionary = _tables.get(table, {})
	if not t.has(id):
		if id != "":
			push_warning("Database: unknown %s id '%s'" % [table, id])
		return null
	return t[id]


func _scan_resources(dir_path: String) -> Dictionary:
	var out: Dictionary = {}
	for file: String in _list_files(dir_path):
		var clean := file.trim_suffix(".remap")
		if not (clean.ends_with(".tres") or clean.ends_with(".res")):
			continue
		var res: Resource = load(dir_path.path_join(clean))
		if res == null:
			push_error("Database: failed to load %s" % clean)
			continue
		var rid: String = String(res.get("id"))
		if rid == "":
			rid = clean.get_basename()
		out[rid] = res
	return out


func _scan_json(dir_path: String) -> Dictionary:
	var out: Dictionary = {}
	for file: String in _list_files(dir_path):
		if not file.ends_with(".json"):
			continue
		var text := FileAccess.get_file_as_string(dir_path.path_join(file))
		var parsed: Variant = JSON.parse_string(text)
		if parsed is Dictionary:
			var d: Dictionary = parsed
			out[String(d.get("id", file.get_basename()))] = d
		else:
			push_error("Database: invalid JSON in %s" % file)
	return out


func _list_files(dir_path: String) -> PackedStringArray:
	var files := PackedStringArray()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return files
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if not dir.current_is_dir():
			files.append(f)
		f = dir.get_next()
	dir.list_dir_end()
	files.sort()
	return files
