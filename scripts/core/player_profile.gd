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
## Chosen calling ("assassin", "spirit", "wizard", "grimlet"). "" until the
## Fourfold Threshold has been crossed (old saves load with "").
var class_id: String = ""
## Ability ids slotted on the hotbar (defaults to the class's abilities).
var hotbar: PackedStringArray = []
## Mana Essence: the currency spent on Learning Paths. Earned from quests,
## exploration, chests, bosses and discoveries (not from the combat pool).
var mana_essence: int = 0

signal mana_essence_changed(amount: int)


func add_mana_essence(n: int) -> void:
	mana_essence = maxi(0, mana_essence + n)
	mana_essence_changed.emit(mana_essence)


func spend_mana_essence(n: int) -> bool:
	if n > mana_essence:
		return false
	mana_essence -= n
	mana_essence_changed.emit(mana_essence)
	return true
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
	class_id = ""
	hotbar = PackedStringArray()
	mana_essence = 0
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


func player_class() -> ClassData:
	if class_id == "" or not content.has_method("player_class"):
		return null
	return content.player_class(class_id)


## Crosses the Threshold: sets the calling, grants and equips its kit.
## Returns false if the class doesn't exist or one was already chosen.
func choose_class(id: String) -> bool:
	if class_id != "" or not content.has_method("player_class"):
		return false
	var c: ClassData = content.player_class(id)
	if c == null:
		return false
	class_id = id
	hotbar = c.abilities.duplicate()
	for item_id: String in c.start_items:
		inventory.add(item_id, 1)
		var d: ItemData = content.item(item_id)
		# Equip unless the slot is already taken by an earlier kit item (the
		# grimlet's second weapon stays in the bag for weapon switching).
		if d and d.equip_slot != "" and not inventory.equipment.has(d.equip_slot):
			inventory.equip(item_id)
	if content.item("twig_bow") != null and not inventory.equipment.has("ranged"):
		inventory.add("twig_bow", 1)
		inventory.equip("twig_bow")
	recalculate()
	stats.full_restore()
	return true


## Abilities the player can currently use (class abilities, gated by level).
func usable_abilities() -> Array[AbilityData]:
	var out: Array[AbilityData] = []
	if not content.has_method("ability"):
		return out
	for id: String in hotbar:
		var a: AbilityData = content.ability(id)
		if a and (a.unlock_level <= stats.level or skills.is_unlocked("ability:" + id)):
			out.append(a)
	return out


func recalculate() -> void:
	var b := inventory.equipment_bonuses()
	var pc := player_class()
	if pc:
		for k: String in pc.stat_mods.keys():
			b[k] = float(b.get(k, 0.0)) + float(pc.stat_mods[k])
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
	if int(r.get("mana_essence", 0)) > 0:
		add_mana_essence(int(r.get("mana_essence", 0)))
		summary["mana_essence"] = int(r.get("mana_essence", 0))
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
		"class_id": class_id, "hotbar": Array(hotbar), "mana_essence": mana_essence,
		"stats": stats.to_dict(), "inventory": inventory.to_dict(), "spellbook": spellbook.to_dict(),
		"skills": skills.to_dict(), "quests": quests.to_dict(), "world": world.to_dict(),
	}


func from_dict(d: Dictionary) -> void:
	player_id = String(d.get("player_id", "local"))
	display_name = String(d.get("display_name", "Dreamer"))
	play_time = float(d.get("play_time", 0.0))
	class_id = String(d.get("class_id", ""))
	mana_essence = int(d.get("mana_essence", 0))
	hotbar = PackedStringArray(d.get("hotbar", []))
	if class_id != "" and hotbar.is_empty() and player_class():
		hotbar = player_class().abilities.duplicate()
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
