class_name QuestLog
extends RefCounted
## Runtime quest state. Independent of NPC scripts: anything that emits a
## gameplay fact calls handle_event(), and quests advance from that.

signal state_changed(quest_id: String, state: int)
signal objective_progress(quest_id: String, objective_id: String, current: int, required: int)
signal objective_completed(quest_id: String, objective_id: String)
signal quest_completed(quest_id: String)

const State := QuestData.State
const Type := QuestObjectiveData.Type

var states: Dictionary = {}
var progress: Dictionary = {}
var tracked: String = ""

var _lookup: Callable
var _all_ids: Callable
var _count_item: Callable
var _level: Callable


func _init(quest_lookup: Callable, all_ids: Callable, count_item: Callable, level: Callable) -> void:
	_lookup = quest_lookup
	_all_ids = all_ids
	_count_item = count_item
	_level = level


func quest(id: String) -> QuestData:
	return _lookup.call(id) as QuestData


func get_state(id: String) -> int:
	return int(states.get(id, State.LOCKED))


func is_active(id: String) -> bool:
	return get_state(id) == State.ACTIVE


func is_completed(id: String) -> bool:
	return get_state(id) == State.COMPLETED


func active_quests() -> Array[String]:
	var out: Array[String] = []
	for id: String in states.keys():
		if int(states[id]) == State.ACTIVE:
			out.append(id)
	return out


func get_progress(qid: String, oid: String) -> int:
	return int((progress.get(qid, {}) as Dictionary).get(oid, 0))


func is_objective_done(qid: String, oid: String) -> bool:
	var q := quest(qid)
	if q == null:
		return false
	var o := q.get_objective(oid)
	return o != null and get_progress(qid, oid) >= o.required_amount


## First unfinished objective, or null.
func current_objective(qid: String) -> QuestObjectiveData:
	var q := quest(qid)
	if q == null:
		return null
	for o: QuestObjectiveData in q.objectives:
		if get_progress(qid, o.id) < o.required_amount:
			return o
	return null


func is_objective_current(qid: String, oid: String) -> bool:
	if not is_active(qid):
		return false
	var o := current_objective(qid)
	return o != null and o.id == oid


## Promotes LOCKED quests whose prerequisites are met. Auto-start quests begin.
func refresh_availability() -> void:
	for id: Variant in _all_ids.call():
		var qid := String(id)
		if get_state(qid) != State.LOCKED:
			continue
		var q := quest(qid)
		if q == null or int(_level.call()) < q.min_level:
			continue
		var ok := true
		for pre: String in q.prerequisites:
			if not is_completed(pre):
				ok = false
				break
		if not ok:
			continue
		_set_state(qid, State.AVAILABLE)
		if q.auto_start:
			start(qid)


func start(qid: String) -> bool:
	var q := quest(qid)
	if q == null:
		return false
	var s := get_state(qid)
	if s == State.ACTIVE or s == State.COMPLETED:
		return false
	if not progress.has(qid):
		progress[qid] = {}
	_set_state(qid, State.ACTIVE)
	if tracked == "" or not is_active(tracked):
		tracked = qid
	_sync_collect(qid)
	_check_complete(qid)
	return true


func fail(qid: String) -> void:
	if is_active(qid):
		_set_state(qid, State.FAILED)


## Core entry point. `amount` is ignored for COLLECT (inventory count is used).
func handle_event(type: int, target: String, amount: int = 1) -> void:
	for qid: String in active_quests():
		var q := quest(qid)
		if q == null:
			continue
		var candidates: Array[QuestObjectiveData] = []
		if q.sequential:
			var cur := current_objective(qid)
			if cur:
				candidates.append(cur)
		else:
			candidates.assign(q.objectives)
		for o: QuestObjectiveData in candidates:
			if o.type != type or o.target_id != target:
				continue
			var before := get_progress(qid, o.id)
			if before >= o.required_amount:
				continue
			var value: int
			if type == Type.COLLECT:
				value = int(_count_item.call(target))
			else:
				value = before + maxi(1, amount)
			_set_progress(qid, o, value)
		_check_complete(qid)


## Forces an objective complete (used by scripted moments).
func complete_objective(qid: String, oid: String) -> void:
	var q := quest(qid)
	if q == null or not is_active(qid):
		return
	var o := q.get_objective(oid)
	if o:
		_set_progress(qid, o, o.required_amount)
		_check_complete(qid)


func _set_progress(qid: String, o: QuestObjectiveData, value: int) -> void:
	var p: Dictionary = progress.get(qid, {})
	var clamped := clampi(value, 0, o.required_amount)
	if clamped == int(p.get(o.id, 0)):
		return
	p[o.id] = clamped
	progress[qid] = p
	objective_progress.emit(qid, o.id, clamped, o.required_amount)
	if clamped >= o.required_amount:
		objective_completed.emit(qid, o.id)
		_sync_collect(qid)


## When a COLLECT objective becomes relevant, count what the player already has.
func _sync_collect(qid: String) -> void:
	var q := quest(qid)
	if q == null:
		return
	var candidates: Array[QuestObjectiveData] = []
	if q.sequential:
		var cur := current_objective(qid)
		if cur:
			candidates.append(cur)
	else:
		candidates.assign(q.objectives)
	for o: QuestObjectiveData in candidates:
		if o.type == Type.COLLECT:
			var have := int(_count_item.call(o.target_id))
			if have > get_progress(qid, o.id):
				_set_progress(qid, o, have)


func _check_complete(qid: String) -> void:
	if not is_active(qid):
		return
	if current_objective(qid) != null:
		return
	_set_state(qid, State.COMPLETED)
	if tracked == qid:
		tracked = ""
		var act := active_quests()
		if not act.is_empty():
			tracked = act[0]
	quest_completed.emit(qid)
	refresh_availability()


func _set_state(qid: String, s: int) -> void:
	if get_state(qid) == s:
		return
	states[qid] = s
	state_changed.emit(qid, s)


func to_dict() -> Dictionary:
	return {"states": states.duplicate(), "progress": progress.duplicate(true), "tracked": tracked}


func from_dict(d: Dictionary) -> void:
	states.clear()
	progress.clear()
	var st: Variant = d.get("states", {})
	if st is Dictionary:
		for id: String in (st as Dictionary).keys():
			if quest(id) != null:
				states[id] = clampi(int(st[id]), State.LOCKED, State.FAILED)
	var pr: Variant = d.get("progress", {})
	if pr is Dictionary:
		for id: String in (pr as Dictionary).keys():
			if pr[id] is Dictionary and quest(id) != null:
				var clean: Dictionary = {}
				for oid: String in (pr[id] as Dictionary).keys():
					clean[oid] = int(pr[id][oid])
				progress[id] = clean
	tracked = String(d.get("tracked", ""))
	if tracked != "" and not is_active(tracked):
		tracked = ""
