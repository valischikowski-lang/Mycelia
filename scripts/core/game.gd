extends Node
## Session owner: holds the active PlayerProfile, routes gameplay facts from
## EventBus into the quest log, and grants rewards. Exposes a small API used
## by world objects, dialogue and combat.

const QType := QuestObjectiveData.Type
const REGEN_HEALTH_PER_SEC := 1.2
const REGEN_MANA_PER_SEC := 0.2

var profile: PlayerProfile
var current_region: String = "dreaming_meadow"
## Where the next region load should place the player:
## {"spawn": "name"} or {"position": Vector3, "yaw": float}; "intro": true plays wake-up.
var pending_spawn: Dictionary = {}
var in_combat: bool = false
var session_active: bool = false

var _regen_acc: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	EventBus.item_collected.connect(func(id: String, _n: int) -> void: _quest_event(QType.COLLECT, id))
	EventBus.item_removed.connect(func(id: String, _n: int) -> void: _quest_event(QType.COLLECT, id))
	EventBus.npc_talked.connect(func(id: String) -> void: _quest_event(QType.TALK, id))
	EventBus.location_visited.connect(func(id: String) -> void: _quest_event(QType.VISIT, id))
	EventBus.object_activated.connect(func(id: String) -> void: _quest_event(QType.ACTIVATE, id))
	EventBus.area_discovered.connect(func(id: String) -> void:
		_quest_event(QType.DISCOVER, id)
		if profile:
			profile.add_mana_essence(1))
	EventBus.enemy_defeated.connect(func(id: String) -> void: _quest_event(QType.DEFEAT, id))
	EventBus.encounter_won.connect(func(id: String) -> void: _quest_event(QType.DEFEAT, id))


func start_new_game() -> void:
	_bind(PlayerProfile.new(Database))
	profile.new_game()
	current_region = "dreaming_meadow"
	pending_spawn = {"spawn": "awakening", "intro": true}
	session_active = true


func load_profile(data: Dictionary) -> void:
	_bind(PlayerProfile.new(Database))
	profile.from_dict(data.get("profile", {}))
	current_region = String(data.get("region", "dreaming_meadow"))
	if not Database.REGIONS.has(current_region) or not bool(Database.REGIONS[current_region].get("available", false)):
		current_region = "dreaming_meadow"
	var pos: Variant = data.get("position", null)
	if pos is Array and (pos as Array).size() == 3:
		pending_spawn = {"position": Vector3(float(pos[0]), float(pos[1]), float(pos[2])), "yaw": float(data.get("yaw", 0.0))}
	else:
		pending_spawn = {"spawn": "default"}
	session_active = true


func end_session() -> void:
	session_active = false
	in_combat = false
	profile = null


func _bind(p: PlayerProfile) -> void:
	profile = p
	p.leveled_up.connect(_on_level_up)
	p.spell_learned.connect(_on_spell_learned)
	p.quests.state_changed.connect(_on_quest_state)
	p.quests.objective_progress.connect(func(q: String, o: String, c: int, r: int) -> void:
		EventBus.quest_objective_progress.emit(q, o, c, r)
		EventBus.quest_tracker_changed.emit())
	p.quests.objective_completed.connect(_on_objective_completed)
	p.quests.quest_completed.connect(_on_quest_completed)
	p.stats.changed.connect(func() -> void: EventBus.stats_changed.emit())
	p.inventory.changed.connect(func() -> void: EventBus.inventory_changed.emit())
	p.inventory.equipment_changed.connect(func() -> void: EventBus.equipment_changed.emit())
	p.inventory.currency_changed.connect(func(a: int) -> void: EventBus.currency_changed.emit(a))
	p.mana_essence_changed.connect(func(a: int) -> void: EventBus.currency_changed.emit(a))
	p.world.flag_changed.connect(func(f: String, v: Variant) -> void: EventBus.flag_changed.emit(f, v))


func _process(delta: float) -> void:
	if not session_active or in_combat or profile == null:
		return
	profile.play_time += delta
	_regen_acc += delta
	if _regen_acc >= 0.5:
		var s := profile.stats
		if s.health < s.max_health() or s.mana < s.max_mana():
			s.health = minf(s.max_health(), s.health + REGEN_HEALTH_PER_SEC * _regen_acc)
			s.mana = minf(s.max_mana(), s.mana + REGEN_MANA_PER_SEC * _regen_acc)
			s.changed.emit()
		_regen_acc = 0.0


func _quest_event(type: int, target: String) -> void:
	if profile:
		profile.quests.handle_event(type, target)


func grant_xp(amount: int) -> void:
	if profile == null or amount <= 0:
		return
	profile.stats.add_xp(amount)
	EventBus.xp_gained.emit(amount)


func _on_level_up(level: int) -> void:
	EventBus.level_up.emit(level)
	EventBus.notify("Level %d! Your connection to the Mycelium deepens. (+2 Mana Essence)" % level, "level")
	profile.add_mana_essence(2)
	AudioManager.play_sfx("level_up")
	# Level-based spell unlocks keep progression rewarding.
	var unlocks := {2: "rootbind", 3: "shardstorm", 4: "gravity_well", 5: "starfall_seed", 6: "kaleidoscope_rift"}
	if unlocks.has(level):
		profile.learn_spell(String(unlocks[level]))


func _on_spell_learned(id: String) -> void:
	var sp := Database.spell(id)
	EventBus.spell_unlocked.emit(id)
	if sp:
		EventBus.notify("New spell: %s" % sp.display_name, "spell")


func _on_quest_state(qid: String, state: int) -> void:
	EventBus.quest_state_changed.emit(qid, state)
	EventBus.quest_tracker_changed.emit()
	var q := Database.quest(qid)
	if q and state == QuestData.State.ACTIVE:
		EventBus.notify("New quest: %s" % q.title, "quest")
		AudioManager.play_sfx("quest")


func _on_objective_completed(qid: String, oid: String) -> void:
	EventBus.quest_objective_completed.emit(qid, oid)
	var q := Database.quest(qid)
	if q == null:
		return
	var o := q.get_objective(oid)
	if o and profile.quests.current_objective(qid) != null:
		EventBus.notify("✓ %s" % o.description, "objective")
		AudioManager.play_sfx("objective")


func _on_quest_completed(qid: String) -> void:
	var q := Database.quest(qid)
	if q == null:
		return
	var summary := profile.grant_rewards({
		"xp": q.reward_xp, "glimmer": q.reward_glimmer, "items": q.reward_items,
		"spells": Array(q.reward_spells), "skill_points": q.reward_skill_points,
		"mana_essence": 3 + q.reward_skill_points * 2 if q.category == QuestData.Category.MAIN else 2 + q.reward_skill_points,
	})
	if int(summary.get("xp", 0)) > 0:
		EventBus.xp_gained.emit(int(summary["xp"]))
	EventBus.notify("Quest complete: %s  (+%d XP, +%d glimmer)" % [q.title, q.reward_xp, q.reward_glimmer], "quest_complete")
	AudioManager.play_sfx("quest_complete")
	SaveManager.autosave("quest")
