extends Node
## Global, decoupled game events.
##
## Gameplay systems emit facts ("an item was collected") and other systems
## (quests, UI, audio, achievements) react. Nothing here holds state.

# --- World / exploration ---------------------------------------------------
signal item_collected(item_id: String, amount: int)
signal item_removed(item_id: String, amount: int)
signal npc_talked(npc_id: String)
signal location_visited(location_id: String)
signal object_activated(object_id: String)
signal area_discovered(area_id: String)
signal lore_discovered(lore_id: String)
signal flag_changed(flag: String, value: Variant)

# --- Combat ----------------------------------------------------------------
signal combat_requested(encounter_id: String, source: Node)
signal combat_started(encounter_id: String)
signal combat_finished(result: Dictionary)
signal enemy_defeated(creature_id: String)
signal encounter_won(encounter_id: String)

# --- Progression -----------------------------------------------------------
signal xp_gained(amount: int)
signal level_up(new_level: int)
signal spell_unlocked(spell_id: String)
signal stats_changed()
signal currency_changed(amount: int)
signal inventory_changed()
signal equipment_changed()
signal skill_unlocked(skill_id: String)
signal class_chosen(class_id: String)

# --- Quests ----------------------------------------------------------------
signal quest_state_changed(quest_id: String, state: int)
signal quest_objective_progress(quest_id: String, objective_id: String, current: int, required: int)
signal quest_objective_completed(quest_id: String, objective_id: String)
signal quest_tracker_changed()

# --- Dialogue / UI ---------------------------------------------------------
signal dialogue_requested(npc: Node, dialogue_id: String)
signal dialogue_started(dialogue_id: String)
signal dialogue_finished(dialogue_id: String)
signal shop_requested(shop_id: String)
signal notification_requested(text: String, kind: String)
signal interaction_target_changed(prompt: String, has_target: bool)
signal menu_requested(tab: String)
signal pause_requested()
signal input_mode_changed(is_touch: bool)

# --- Persistence -----------------------------------------------------------
signal game_saved(slot: String)
signal game_loaded(slot: String)


func notify(text: String, kind: String = "info") -> void:
	notification_requested.emit(text, kind)
