extends Node
## Local save system (user://saves). JSON per slot, atomic writes with a
## .bak of the previous file, schema migration and validation on load.

const DIR := "user://saves"
const SLOTS: PackedStringArray = ["auto", "slot1", "slot2", "slot3"]
const AUTOSAVE_MIN_INTERVAL := 8.0
const PERIODIC_AUTOSAVE := 150.0

var _last_autosave: float = -100.0
var _periodic: float = 0.0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)


func _process(delta: float) -> void:
	if not Game.session_active or Game.in_combat:
		return
	_periodic += delta
	if _periodic >= PERIODIC_AUTOSAVE:
		_periodic = 0.0
		autosave("timer")


func slot_path(slot: String) -> String:
	return DIR.path_join(slot + ".json")


## Snapshot of the running session.
func build_snapshot() -> Dictionary:
	var d := SaveSchema.defaults()
	d["saved_at"] = int(Time.get_unix_time_from_system())
	d["region"] = Game.current_region
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player:
		var p := player.global_position
		d["position"] = [p.x, p.y + 0.1, p.z]
		d["yaw"] = player.rotation.y
	d["profile"] = Game.profile.to_dict()
	return d


func save_game(slot: String) -> bool:
	if Game.profile == null or not slot in SLOTS:
		return false
	if Game.in_combat:
		EventBus.notify("You can't save during combat.", "warning")
		return false
	var data := build_snapshot()
	var ok := write_slot(slot, data)
	if ok:
		EventBus.game_saved.emit(slot)
	return ok


func write_slot(slot: String, data: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(DIR)
	var path := slot_path(slot)
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("SaveManager: cannot write %s (%s)" % [tmp, error_string(FileAccess.get_open_error())])
		EventBus.notify("Saving failed!", "error")
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path + ".bak")
		DirAccess.rename_absolute(path, path + ".bak")
	var err := DirAccess.rename_absolute(tmp, path)
	if err != OK:
		push_error("SaveManager: rename failed (%s)" % error_string(err))
		return false
	return true


func autosave(reason: String = "") -> void:
	if not Game.session_active or Game.in_combat or Game.profile == null:
		return
	var now := Time.get_ticks_msec() * 0.001
	if now - _last_autosave < AUTOSAVE_MIN_INTERVAL and reason != "force":
		return
	_last_autosave = now
	if save_game("auto"):
		EventBus.notify("Progress saved", "save")


## Returns validated, migrated save data or {} (falls back to .bak).
func read_slot(slot: String) -> Dictionary:
	var path := slot_path(slot)
	for candidate: String in [path, path + ".bak"]:
		if not FileAccess.file_exists(candidate):
			continue
		var text := FileAccess.get_file_as_string(candidate)
		var parsed: Variant = JSON.parse_string(text)
		var data := SaveSchema.upgrade(parsed)
		if not data.is_empty():
			return data
		push_warning("SaveManager: %s is corrupt, trying backup" % candidate)
	return {}


func load_game(slot: String) -> bool:
	var data := read_slot(slot)
	if data.is_empty():
		EventBus.notify("That save could not be loaded.", "error")
		return false
	Game.load_profile(data)
	EventBus.game_loaded.emit(slot)
	return true


func has_any_save() -> bool:
	return latest_slot() != ""


func latest_slot() -> String:
	var best := ""
	var best_t := -1
	for s: String in SLOTS:
		var info := slot_info(s)
		if not info.is_empty() and int(info["saved_at"]) > best_t:
			best_t = int(info["saved_at"])
			best = s
	return best


func slot_info(slot: String) -> Dictionary:
	if not FileAccess.file_exists(slot_path(slot)):
		return {}
	var data := read_slot(slot)
	if data.is_empty():
		return {}
	var prof: Dictionary = data["profile"]
	var stats: Dictionary = prof.get("stats", {})
	return {
		"saved_at": int(data["saved_at"]),
		"region": String(data["region"]),
		"level": int(stats.get("level", 1)),
		"play_time": float(prof.get("play_time", 0.0)),
	}


func delete_slot(slot: String) -> void:
	for suffix: String in ["", ".bak", ".tmp"]:
		var p := slot_path(slot) + suffix
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
