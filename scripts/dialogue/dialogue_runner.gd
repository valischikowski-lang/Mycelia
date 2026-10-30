class_name DialogueRunner
extends RefCounted
## Walks a JSON dialogue tree. UI-agnostic: the DialogueBox listens to
## `line` and calls choose().
##
## Format:
## {"id", "speaker", "entry": [{"if": [...], "goto": "node"}],
##  "nodes": {"node": {"text", "speaker"?, "actions": [...],
##            "options": [{"text", "goto", "if": [...], "actions": [...]}],
##            "next": "node"}}}
## goto "end" closes the conversation.

signal line(speaker: String, text: String, options: Array)
signal finished(dialogue_id: String)

var dialogue_id: String = ""
var data: Dictionary = {}
var profile: PlayerProfile
var node_id: String = ""
var _visible_options: Array = []
var active: bool = false


func start(id: String, p: PlayerProfile) -> bool:
	data = Database.dialogue(id)
	if data.is_empty():
		push_error("DialogueRunner: missing dialogue '%s'" % id)
		return false
	dialogue_id = id
	profile = p
	active = true
	var entry := "end"
	for e: Variant in data.get("entry", []):
		var ed: Dictionary = e
		if DialogueLogic.check_all(ed.get("if", []), profile):
			entry = String(ed.get("goto", "end"))
			break
	_show(entry)
	return true


func choose(index: int) -> void:
	if not active or index < 0 or index >= _visible_options.size():
		return
	var opt: Dictionary = _visible_options[index]
	for a: Variant in opt.get("actions", []):
		DialogueLogic.run(String(a), profile)
	_show(String(opt.get("goto", "end")))


func _show(id: String) -> void:
	if not active:
		return
	var nodes: Dictionary = data.get("nodes", {})
	if id == "end" or not nodes.has(id):
		if id != "end":
			push_warning("DialogueRunner: missing node '%s' in %s" % [id, dialogue_id])
		_finish()
		return
	node_id = id
	var node: Dictionary = nodes[id]
	for a: Variant in node.get("actions", []):
		DialogueLogic.run(String(a), profile)
	# Actions may end the conversation (e.g. start_encounter).
	if not active:
		return
	profile.world.mark_dialogue(dialogue_id, id)
	_visible_options.clear()
	for o: Variant in node.get("options", []):
		var od: Dictionary = o
		if DialogueLogic.check_all(od.get("if", []), profile):
			var copy := od.duplicate()
			copy["seen"] = od.has("goto") and profile.world.has_seen(dialogue_id, String(od["goto"]))
			_visible_options.append(copy)
	if _visible_options.is_empty():
		if node.has("next"):
			_visible_options.append({"text": "…", "goto": node["next"]})
		else:
			_visible_options.append({"text": "Farewell.", "goto": "end"})
	var speaker := String(node.get("speaker", data.get("speaker", "")))
	line.emit(speaker, format_text(String(node.get("text", ""))), _visible_options)


func format_text(t: String) -> String:
	if profile == null:
		return t
	return t.replace("{player}", profile.display_name) \
		.replace("{fragments}", str(profile.inventory.count("spore_fragment"))) \
		.replace("{motes}", str(profile.inventory.count("dream_mote")))


func close() -> void:
	_finish()


func _finish() -> void:
	if not active:
		return
	active = false
	finished.emit(dialogue_id)
