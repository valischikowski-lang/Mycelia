class_name PlayerProfile
extends RefCounted
## Complete persistent state of one player character. Pure model: no nodes,
## no rendering. A future server can own an identical instance.
##
## `content` is any object exposing Database's lookup API (item(), spell(),
## quest(), ids(), skill_tree(), skill_tree_ids()).

signal leveled_up(new_level: int)
signal spell_learned(spell_id: String)
signal rewards_granted(summary: Dictionary)

const START_SPELLS: PackedStringArray = ["thornlash", "prism_ward"]
const START_DECK: Dictionary = {"thornlash": 3, "prism_ward": 3}

var player_id: String = ""
var display_name: String = "Dreamer"
var stats := PlayerStats.new()
var inventory: Inventory
var spellbook := Spellbook.new()
var skills := SkillTreeState.new()
var quests: QuestLog
var world := WorldState.new()
var play_time: float = 0.0
var content: Object


func _init(content_source: Object) -> void:
	content = content_source
	inventory = Inventory.new(func(id: String) -> ItemData: return content.item(id))
	quests = QuestLog.new(
		func(id: String) -> QuestData: return content.quest(id),
		func() -> Array: return content.ids("quests"),
		func(id: String) -> int: return inventory.count(id),
		func() -> int: return stats.level)
	stats.leveled_up.connect(func(l: int) -> void: leveled_up.emit(l))
	inventory.equipment_changed.connect(recalculate)
	skills.changed.connect(recalculate)


func new_game() -> void:
	player_id = "local_%d" % (Time.get_unix_time_from_system() as int)
	stats.bonuses = {}
	stats.from_dict({"level": 1, "xp": 0, "skill_points": 0})
	spellbook.known = START_SPELLS.duplicate()
	spellbook.deck = START_DECK.duplicate()
	inventory.from_dict({"glimmer": 15})
	skills.from_dict({})
	world.from_dict({})
	quests.from_dict({})
	recalculate()
	stats.full_restore()
	quests.refresh_availability()


func skill_trees() -> Array:
	var out: Array = []
	for id: Variant in content.skill_tree_ids():
		out.append(content.skill_tree(String(id)))
	return out


func recalculate() -> void:
	var b := inventory.equipment_bonuses()
	var sb := skills.bonuses(skill_trees())
	for k: String in sb.keys():
		b[k] = float(b.get(k, 0.0)) + float(sb[k])
	stats.bonuses = b
	stats.clamp_pools()
	stats.changed.emit()


func learn_spell(id: String) -> bool:
	if content.spell(id) == null:
		return false
	if spellbook.unlock(id):
		spell_learned.emit(id)
		return true
	return false


## Grants a reward bundle: {"xp", "glimmer", "items": {id: n}, "spells": [], "skill_points"}.
func grant_rewards(r: Dictionary) -> Dictionary:
	var summary := {"xp": 0, "glimmer": 0, "items": {}, "spells": [], "levels": 0}
	var glim := int(r.get("glimmer", 0))
	if glim > 0:
		inventory.add_glimmer(glim)
		summary["glimmer"] = glim
	var items: Dictionary = r.get("items", {})
	for id: String in items.keys():
		var added := inventory.add(id, int(items[id]))
		if added > 0:
			summary["items"][id] = added
	for sid: Variant in r.get("spells", []):
		if learn_spell(String(sid)):
			(summary["spells"] as Array).append(String(sid))
	stats.skill_points += int(r.get("skill_points", 0))
	var xp := int(r.get("xp", 0))
	if xp > 0:
		summary["xp"] = xp
		summary["levels"] = stats.add_xp(xp)
	rewards_granted.emit(summary)
	return summary


## Returns a message describing the result, or "" if the item can't be used.
func use_item(id: String) -> String:
	var d: ItemData = content.item(id)
	if d == null or not d.is_usable() or not inventory.has(id):
		return ""
	var fx := d.use_effect
	var parts: PackedStringArray = []
	if fx.has("heal"):
		stats.heal(float(fx["heal"]))
		parts.append("+%d health" % int(fx["heal"]))
	if fx.has("mana"):
		stats.restore_mana(float(fx["mana"]))
		parts.append("+%d mana" % int(fx["mana"]))
	if fx.has("unlock_spell"):
		var sid := String(fx["unlock_spell"])
		if not learn_spell(sid):
			return "You already know this spell."
		parts.append("learned %s" % (content.spell(sid) as SpellData).display_name)
	if fx.has("xp"):
		stats.add_xp(int(fx["xp"]))
		parts.append("+%d XP" % int(fx["xp"]))
	inventory.remove(id, 1)
	return "%s: %s" % [d.display_name, ", ".join(parts)]


func unlock_skill(tree_id: String, node_id: String) -> String:
	var tree: Dictionary = content.skill_tree(tree_id)
	var reason := skills.check(tree, node_id, stats.skill_points, stats.level)
	if reason != "":
		return reason
	var node := SkillTreeState.find_node(tree, node_id)
	stats.skill_points -= int(node.get("cost", 1))
	skills.unlock(node_id)
	var sp := String(node.get("unlock_spell", ""))
	if sp != "":
		learn_spell(sp)
	return ""


func to_dict() -> Dictionary:
	return {
		"player_id": player_id, "display_name": display_name, "play_time": play_time,
		"stats": stats.to_dict(), "inventory": inventory.to_dict(), "spellbook": spellbook.to_dict(),
		"skills": skills.to_dict(), "quests": quests.to_dict(), "world": world.to_dict(),
	}


func from_dict(d: Dictionary) -> void:
	player_id = String(d.get("player_id", "local"))
	display_name = String(d.get("display_name", "Dreamer"))
	play_time = float(d.get("play_time", 0.0))
	inventory.from_dict(d.get("inventory", {}))
	spellbook.from_dict(d.get("spellbook", {}), func(id: String) -> bool: return content.spell(id) != null)
	if spellbook.known.is_empty():
		spellbook.known = START_SPELLS.duplicate()
		spellbook.deck = START_DECK.duplicate()
	skills.from_dict(d.get("skills", {}))
	quests.from_dict(d.get("quests", {}))
	world.from_dict(d.get("world", {}))
	recalculate()
	stats.from_dict(d.get("stats", {}))
	quests.refresh_availability()
