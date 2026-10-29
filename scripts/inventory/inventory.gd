class_name Inventory
extends RefCounted
## Slot-based inventory with stacking, equipment slots and currency.
## Item definitions are resolved through a lookup Callable so the model can be
## tested without the Database autoload.

signal changed()
signal equipment_changed()
signal currency_changed(amount: int)

const DEFAULT_CAPACITY := 36

var capacity: int = DEFAULT_CAPACITY
## Array of {"id": String, "count": int}
var slots: Array[Dictionary] = []
## slot name -> item id
var equipment: Dictionary = {}
var glimmer: int = 0
var _lookup: Callable


func _init(item_lookup: Callable = Callable()) -> void:
	_lookup = item_lookup


func _def(id: String) -> ItemData:
	if _lookup.is_valid():
		return _lookup.call(id) as ItemData
	return null


func _stack_limit(id: String) -> int:
	var d := _def(id)
	return maxi(1, d.max_stack) if d else 99


## Adds up to `amount`; returns how many were actually added.
func add(id: String, amount: int = 1) -> int:
	if amount <= 0 or id == "":
		return 0
	var limit := _stack_limit(id)
	var remaining := amount
	for s: Dictionary in slots:
		if remaining <= 0:
			break
		if s["id"] == id and int(s["count"]) < limit:
			var room: int = limit - int(s["count"])
			var put := mini(room, remaining)
			s["count"] = int(s["count"]) + put
			remaining -= put
	while remaining > 0 and slots.size() < capacity:
		var put := mini(limit, remaining)
		slots.append({"id": id, "count": put})
		remaining -= put
	var added := amount - remaining
	if added > 0:
		changed.emit()
	return added


## Removes up to `amount`; returns how many were removed.
func remove(id: String, amount: int = 1) -> int:
	var remaining := amount
	for i in range(slots.size() - 1, -1, -1):
		if remaining <= 0:
			break
		var s: Dictionary = slots[i]
		if s["id"] != id:
			continue
		var take := mini(int(s["count"]), remaining)
		s["count"] = int(s["count"]) - take
		remaining -= take
		if int(s["count"]) <= 0:
			slots.remove_at(i)
	var removed := amount - remaining
	if removed > 0:
		changed.emit()
	return removed


func count(id: String) -> int:
	var n := 0
	for s: Dictionary in slots:
		if s["id"] == id:
			n += int(s["count"])
	return n


func has(id: String, amount: int = 1) -> bool:
	return count(id) >= amount


func is_full() -> bool:
	return slots.size() >= capacity


func add_glimmer(amount: int) -> void:
	glimmer = maxi(0, glimmer + amount)
	currency_changed.emit(glimmer)


func spend_glimmer(amount: int) -> bool:
	if amount > glimmer:
		return false
	glimmer -= amount
	currency_changed.emit(glimmer)
	return true


## Moves an item from the bag into its equipment slot. Returns true on success.
func equip(id: String) -> bool:
	var d := _def(id)
	if d == null or not d.is_equipment() or d.equip_slot == "" or not has(id):
		return false
	var previous: String = equipment.get(d.equip_slot, "")
	remove(id, 1)
	if previous != "":
		add(previous, 1)
	equipment[d.equip_slot] = id
	equipment_changed.emit()
	changed.emit()
	return true


func unequip(slot: String) -> bool:
	var id: String = equipment.get(slot, "")
	if id == "" or is_full():
		return false
	equipment.erase(slot)
	add(id, 1)
	equipment_changed.emit()
	return true


func equipment_bonuses() -> Dictionary:
	var out: Dictionary = {}
	for slot: String in equipment.keys():
		var d := _def(String(equipment[slot]))
		if d == null:
			continue
		for stat: String in d.stat_bonuses.keys():
			out[stat] = float(out.get(stat, 0.0)) + float(d.stat_bonuses[stat])
	return out


func to_dict() -> Dictionary:
	return {"slots": slots.duplicate(true), "equipment": equipment.duplicate(), "glimmer": glimmer, "capacity": capacity}


func from_dict(d: Dictionary) -> void:
	slots.clear()
	capacity = maxi(8, int(d.get("capacity", DEFAULT_CAPACITY)))
	var raw: Variant = d.get("slots", [])
	if raw is Array:
		for s: Variant in raw:
			if s is Dictionary and (s as Dictionary).has("id"):
				var id := String(s["id"])
				var c := int((s as Dictionary).get("count", 1))
				if id != "" and c > 0 and (not _lookup.is_valid() or _def(id) != null):
					slots.append({"id": id, "count": c})
	equipment.clear()
	var eq: Variant = d.get("equipment", {})
	if eq is Dictionary:
		for slot: String in (eq as Dictionary).keys():
			if slot in ItemData.EQUIP_SLOTS:
				equipment[slot] = String(eq[slot])
	glimmer = maxi(0, int(d.get("glimmer", 0)))
	changed.emit()
	equipment_changed.emit()
