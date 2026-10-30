class_name DialogueLogic
extends RefCounted
## Condition and action vocabulary shared by dialogue (and usable by any
## data-driven trigger). Strings keep the JSON dialogue files readable.
##
## Conditions (prefix "!" negates):
##   flag:<f>  quest_state:<q>:<STATE>  objective_current:<q>:<o>
##   objective_done:<q>:<o>  has_item:<id>:<n>  level:<n>  seen:<dialogue>:<node>
##   quest_completed:<q>  knows_spell:<id>
## Actions:
##   set_flag:<f>  clear_flag:<f>  give_item:<id>:<n>  take_item:<id>:<n>
##   give_glimmer:<n>  give_xp:<n>  learn_spell:<id>  start_quest:<q>
##   activate:<object_id>  heal_full  start_encounter:<encounter_id>
##   open_shop:<shop_id>  lore:<lore_id>  notify:<text>  talk:<npc_id>


static func check_all(conds: Array, profile: PlayerProfile) -> bool:
	for c: Variant in conds:
		if not check(String(c), profile):
			return false
	return true


static func check(cond: String, profile: PlayerProfile) -> bool:
	if profile == null:
		return false
	var negate := cond.begins_with("!")
	if negate:
		cond = cond.substr(1)
	var parts := cond.split(":")
	var result := false
	match parts[0]:
		"flag":
			result = profile.world.has_flag(parts[1])
		"quest_state":
			var want: int = QuestData.State.get(parts[2], -1)
			result = profile.quests.get_state(parts[1]) == want
		"quest_completed":
			result = profile.quests.is_completed(parts[1])
		"objective_current":
			result = profile.quests.is_objective_current(parts[1], parts[2])
		"objective_done":
			result = profile.quests.is_objective_done(parts[1], parts[2])
		"has_item":
			result = profile.inventory.has(parts[1], int(parts[2]) if parts.size() > 2 else 1)
		"level":
			result = profile.stats.level >= int(parts[1])
		"seen":
			result = profile.world.has_seen(parts[1], parts[2])
		"knows_spell":
			result = profile.spellbook.knows(parts[1])
		_:
			push_warning("DialogueLogic: unknown condition '%s'" % cond)
	return result != negate


static func run(action: String, profile: PlayerProfile) -> void:
	if profile == null:
		return
	var parts := action.split(":", true, 2)
	match parts[0]:
		"set_flag":
			profile.world.set_flag(parts[1], true)
		"clear_flag":
			profile.world.set_flag(parts[1], false)
		"give_item":
			var n := int(parts[2]) if parts.size() > 2 else 1
			var added := profile.inventory.add(parts[1], n)
			if added > 0:
				var d := Database.item(parts[1])
				EventBus.notify("Received %s ×%d" % [d.display_name if d else parts[1], added], "item")
				EventBus.item_collected.emit(parts[1], added)
		"take_item":
			var n2 := int(parts[2]) if parts.size() > 2 else 1
			var removed := profile.inventory.remove(parts[1], n2)
			if removed > 0:
				EventBus.item_removed.emit(parts[1], removed)
		"give_glimmer":
			profile.inventory.add_glimmer(int(parts[1]))
			EventBus.notify("+%s glimmer" % parts[1], "item")
		"give_xp":
			Game.grant_xp(int(parts[1]))
		"learn_spell":
			profile.learn_spell(parts[1])
		"start_quest":
			profile.quests.refresh_availability()
			profile.quests.start(parts[1])
		"activate":
			EventBus.object_activated.emit(parts[1])
		"heal_full":
			profile.stats.full_restore()
		"start_encounter":
			EventBus.combat_requested.emit(parts[1], null)
		"open_shop":
			EventBus.shop_requested.emit(parts[1])
		"lore":
			if profile.world.add_lore(parts[1]):
				EventBus.lore_discovered.emit(parts[1])
		"notify":
			EventBus.notify(parts[1], "info")
		"talk":
			EventBus.npc_talked.emit(parts[1])
		_:
			push_warning("DialogueLogic: unknown action '%s'" % action)
