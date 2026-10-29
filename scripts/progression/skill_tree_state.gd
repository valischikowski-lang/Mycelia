class_name SkillTreeState
extends RefCounted
## Unlocked skill nodes across all discipline trees. Tree definitions are
## JSON dictionaries ({"id", "name", "nodes": [{"id","name","description",
## "cost","requires":[],"min_level","bonuses":{},"unlock_spell":""}]}).

signal changed()

var unlocked: PackedStringArray = []


static func find_node(tree: Dictionary, node_id: String) -> Dictionary:
	for n: Variant in tree.get("nodes", []):
		if n is Dictionary and String(n.get("id", "")) == node_id:
			return n
	return {}


func is_unlocked(node_id: String) -> bool:
	return node_id in unlocked


## Returns "" if unlockable, otherwise a human-readable reason.
func check(tree: Dictionary, node_id: String, points: int, level: int) -> String:
	var node := find_node(tree, node_id)
	if node.is_empty():
		return "Unknown skill"
	if is_unlocked(node_id):
		return "Already learned"
	if level < int(node.get("min_level", 1)):
		return "Requires level %d" % int(node.get("min_level", 1))
	for req: Variant in node.get("requires", []):
		if not is_unlocked(String(req)):
			var rn := find_node(tree, String(req))
			return "Requires %s" % String(rn.get("name", req))
	if points < int(node.get("cost", 1)):
		return "Not enough skill points"
	return ""


func unlock(node_id: String) -> void:
	if not is_unlocked(node_id):
		unlocked.append(node_id)
		changed.emit()


func bonuses(trees: Array) -> Dictionary:
	var out: Dictionary = {}
	for tree: Variant in trees:
		for n: Variant in (tree as Dictionary).get("nodes", []):
			var node: Dictionary = n
			if not is_unlocked(String(node.get("id", ""))):
				continue
			var b: Dictionary = node.get("bonuses", {})
			for stat: String in b.keys():
				out[stat] = float(out.get(stat, 0.0)) + float(b[stat])
	return out


func to_dict() -> Dictionary:
	return {"unlocked": Array(unlocked)}


func from_dict(d: Dictionary) -> void:
	unlocked.clear()
	for id: Variant in d.get("unlocked", []):
		unlocked.append(String(id))
	changed.emit()
