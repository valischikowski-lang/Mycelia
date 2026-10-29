class_name WorldState
extends RefCounted
## Persistent world facts: flags, collected world objects, discoveries, lore
## and dialogue history. Regions query this when they build.

signal flag_changed(flag: String, value: Variant)

var flags: Dictionary = {}
## world object id -> true (picked-up collectibles, opened chests...)
var consumed: Dictionary = {}
var discovered_areas: PackedStringArray = []
var lore: PackedStringArray = []
var dialogue_seen: Dictionary = {}
var won_encounters: Dictionary = {}
var creatures_seen: PackedStringArray = []


func set_flag(flag: String, value: Variant = true) -> void:
	if flags.get(flag) == value:
		return
	flags[flag] = value
	flag_changed.emit(flag, value)


func get_flag(flag: String, default: Variant = false) -> Variant:
	return flags.get(flag, default)


func has_flag(flag: String) -> bool:
	return bool(flags.get(flag, false))


func consume(object_id: String) -> void:
	consumed[object_id] = true


func is_consumed(object_id: String) -> bool:
	return consumed.has(object_id)


## Returns true if newly discovered.
func discover(area_id: String) -> bool:
	if area_id in discovered_areas:
		return false
	discovered_areas.append(area_id)
	return true


func is_discovered(area_id: String) -> bool:
	return area_id in discovered_areas


func add_lore(lore_id: String) -> bool:
	if lore_id in lore:
		return false
	lore.append(lore_id)
	return true


func see_creature(creature_id: String) -> bool:
	if creature_id in creatures_seen:
		return false
	creatures_seen.append(creature_id)
	return true


func mark_dialogue(dialogue_id: String, node_id: String) -> void:
	var seen: Array = dialogue_seen.get(dialogue_id, [])
	if not node_id in seen:
		seen.append(node_id)
	dialogue_seen[dialogue_id] = seen


func has_seen(dialogue_id: String, node_id: String) -> bool:
	return node_id in (dialogue_seen.get(dialogue_id, []) as Array)


func to_dict() -> Dictionary:
	return {
		"flags": flags.duplicate(true), "consumed": consumed.keys(),
		"discovered_areas": Array(discovered_areas), "lore": Array(lore),
		"dialogue_seen": dialogue_seen.duplicate(true), "won_encounters": won_encounters.keys(),
		"creatures_seen": Array(creatures_seen),
	}


func from_dict(d: Dictionary) -> void:
	var f: Variant = d.get("flags", {})
	flags = (f as Dictionary).duplicate(true) if f is Dictionary else {}
	consumed.clear()
	for id: Variant in d.get("consumed", []):
		consumed[String(id)] = true
	discovered_areas = PackedStringArray(d.get("discovered_areas", []))
	lore = PackedStringArray(d.get("lore", []))
	var ds: Variant = d.get("dialogue_seen", {})
	dialogue_seen = (ds as Dictionary).duplicate(true) if ds is Dictionary else {}
	won_encounters.clear()
	for id: Variant in d.get("won_encounters", []):
		won_encounters[String(id)] = true
	creatures_seen = PackedStringArray(d.get("creatures_seen", []))
