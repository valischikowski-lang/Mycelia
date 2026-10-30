class_name CombatManager
extends Node
## Combat director: an explicit finite state machine driving BattleState
## (rules), CombatArena (3D presentation) and CombatHUD (input/UI).
## Logic only advances on explicit transitions, player-action signals and
## awaited presentation — never on arbitrary timers.

signal state_changed(state: int)
signal finished(result: Dictionary)

enum State {
	INITIALIZING, INTRO, TURN_START, PLAYER_TURN, CARD_SELECTION, TARGET_SELECTION,
	SPELL_RESOLUTION, STATUS_EFFECT_RESOLUTION, ENEMY_TURN, VICTORY, DEFEAT, EXITING,
}

var game_root: Node
var state_id: State = State.EXITING
var battle: BattleState
var arena: CombatArena
var hud: CombatHUD
var encounter: EncounterData
var source: Node
var _layer: CanvasLayer
var _pending: Dictionary = {}
var _result: Dictionary = {}
var _level_before: int = 1
var _music_before: String = ""
## Records every state visited (used by tests and debugging).
var history: Array[int] = []


func is_active() -> bool:
	return state_id != State.EXITING


func _set_state(s: State) -> void:
	state_id = s
	history.append(s)
	state_changed.emit(s)


## Runs a full encounter. Awaitable; returns after exploration resumes.
func start_encounter(encounter_id: String, src: Node) -> void:
	encounter = Database.encounter(encounter_id)
	if encounter == null or Game.profile == null:
		push_error("CombatManager: unknown encounter '%s'" % encounter_id)
		if src and src.has_method("on_combat_result"):
			src.call("on_combat_result", false, true)
		return
	source = src
	history.clear()
	Game.in_combat = true
	EventBus.combat_started.emit(encounter_id)
	AudioManager.play_sfx("enemy_attack", -4.0)
	await SceneFlow.fade_out(0.55)
	_set_state(State.INITIALIZING)
	_initialize()
	await SceneFlow.fade_in(0.45)
	await _run()
	finished.emit(_result)


func _initialize() -> void:
	var prof := Game.profile
	_level_before = prof.stats.level
	var snapshot := {
		"name": prof.display_name, "level": prof.stats.level,
		"health": prof.stats.health, "max_health": prof.stats.max_health(),
		"mana": prof.stats.mana, "max_mana": prof.stats.max_mana(),
		"defense": prof.stats.get_stat("defense"), "spell_power": prof.stats.get_stat("spell_power"),
		"magic_power": prof.stats.get_stat("magic_power"), "crit_chance": prof.stats.get_stat("crit_chance"),
		"bonuses": prof.stats.bonuses.duplicate(), "deck": prof.spellbook.build_deck_list(),
	}
	battle = BattleState.create(encounter, snapshot, int(Time.get_ticks_usec() & 0x7fffffff),
		func(id: String) -> SpellData: return Database.spell(id),
		func(id: String) -> StatusEffectData: return Database.status_effect(id))
	arena = CombatArena.new()
	arena.name = "CombatArena"
	add_child(arena)
	var hat := Color(0.5, 0.2, 0.85)
	var hat_id: String = prof.inventory.equipment.get("hat", "")
	if hat_id != "" and Database.item(hat_id):
		hat = Database.item(hat_id).icon_color
	var robe := Color(0.22, 0.25, 0.6)
	var robe_id: String = prof.inventory.equipment.get("robe", "")
	if robe_id != "" and Database.item(robe_id):
		robe = Database.item(robe_id).icon_color.darkened(0.45)
	arena.build(battle, {"hat_color": hat, "robe_color": robe})
	_layer = CanvasLayer.new()
	_layer.layer = 20
	add_child(_layer)
	hud = CombatHUD.new()
	_layer.add_child(hud)
	hud.setup(battle, arena)
	if game_root and game_root.get("region"):
		(game_root.get("region") as Node3D).visible = false
	arena.activate()
	_music_before = AudioManager._music_current
	AudioManager.play_music(encounter.music, 0.6)
	AudioManager.duck_ambience(true)
	for e: Combatant in battle.enemies:
		if Game.profile.world.see_creature(e.data.id):
			EventBus.notify("New creature recorded in your Bestiary: %s" % e.data.display_name, "lore")


func _run() -> void:
	_set_state(State.INTRO)
	while state_id != State.EXITING:
		match state_id:
			State.INTRO:
				await _state_intro()
			State.TURN_START:
				await _state_turn_start()
			State.PLAYER_TURN:
				_state_player_turn()
			State.CARD_SELECTION:
				await _state_card_selection()
			State.TARGET_SELECTION:
				await _state_target_selection()
			State.SPELL_RESOLUTION:
				await _state_spell_resolution()
			State.STATUS_EFFECT_RESOLUTION:
				await _state_status_resolution()
			State.ENEMY_TURN:
				await _state_enemy_turn()
			State.VICTORY:
				await _state_victory()
			State.DEFEAT:
				await _state_defeat()
			_:
				_set_state(State.EXITING)
	await _state_exiting()


## Returns true (and transitions) if the battle has ended.
func _check_end() -> bool:
	match battle.outcome():
		"victory":
			_set_state(State.VICTORY)
			return true
		"defeat":
			_set_state(State.DEFEAT)
			return true
	return false


func _play(events: Array[Dictionary]) -> void:
	for e: Dictionary in events:
		var line := describe(e)
		if line != "":
			hud.log_line(line, _event_color(e))
	await arena.play_events(events, battle)
	hud.refresh()


# ------------------------------------------------------------------ states
func _state_intro() -> void:
	hud.set_banner(encounter.display_name, UiTheme.ACCENT)
	hud.show_intro(encounter.intro_text)
	await arena.play_intro()
	_set_state(State.ENEMY_TURN if encounter.ambush else State.TURN_START)


func _state_turn_start() -> void:
	var events := battle.start_player_turn()
	hud.set_banner("Your Turn", UiTheme.GLOW)
	AudioManager.play_sfx("turn")
	for e: Dictionary in events:
		if String(e["type"]) == "draw":
			AudioManager.play_sfx("card_draw")
	await _play(events)
	_set_state(State.PLAYER_TURN)


func _state_player_turn() -> void:
	_pending.clear()
	arena.camera_home(0.5)
	hud.set_selected(-1)
	hud.enable_player_input(true)
	_set_state(State.CARD_SELECTION)


func _state_card_selection() -> void:
	var a: Dictionary = await hud.action
	match String(a.get("type", "")):
		"card":
			_select_card(int(a["index"]))
		"meditate":
			_pending = {"kind": "meditate"}
			_set_state(State.SPELL_RESOLUTION)
		"replace":
			var ev := battle.replace_card(int(a["index"]))
			if not ev.is_empty():
				AudioManager.play_sfx("card_draw")
				hud.log_line("You swap a card.", UiTheme.TEXT_DIM)
			hud.refresh()
			hud.enable_player_input(true)
		"flee":
			_pending = {"kind": "flee"}
			_set_state(State.SPELL_RESOLUTION)


func _select_card(index: int) -> void:
	if battle.can_cast(index) != "":
		return
	var sp := battle.spell(battle.deck.hand[index])
	var foes := battle.living_enemies()
	if sp.needs_target_choice() and foes.size() > 1:
		_pending = {"kind": "card", "index": index}
		hud.set_selected(index)
		_set_state(State.TARGET_SELECTION)
		return
	var target := foes[0].uid if sp.is_offensive() and not foes.is_empty() else 0
	_pending = {"kind": "card", "index": index, "target": target}
	_set_state(State.SPELL_RESOLUTION)


func _state_target_selection() -> void:
	var valid: Array = []
	for e: Combatant in battle.living_enemies():
		valid.append(e.uid)
	hud.begin_targeting(valid)
	var a: Dictionary = await hud.action
	hud.end_targeting()
	match String(a.get("type", "")):
		"target":
			var uid := int(a["uid"])
			if uid in valid:
				_pending["target"] = uid
				_set_state(State.SPELL_RESOLUTION)
		"card":
			var idx := int(a["index"])
			hud.set_selected(-1)
			if idx == int(_pending.get("index", -1)):
				_set_state(State.CARD_SELECTION)
			else:
				_select_card(idx)
				if state_id == State.TARGET_SELECTION:
					return
		"cancel":
			hud.set_selected(-1)
			hud.enable_player_input(true)
			_set_state(State.CARD_SELECTION)


func _state_spell_resolution() -> void:
	hud.enable_player_input(false)
	var events: Array[Dictionary] = []
	match String(_pending.get("kind", "")):
		"card":
			var sp := battle.spell(battle.deck.hand[int(_pending["index"])])
			hud.log_line("You cast %s." % sp.display_name, ElementChart.color(sp.element))
			events = battle.cast(int(_pending["index"]), int(_pending.get("target", 0)))
		"meditate":
			events = battle.meditate()
		"flee":
			events = battle.try_flee()
	hud.set_selected(-1)
	await _play(events)
	for e: Dictionary in events:
		if String(e["type"]) == "flee":
			if bool(e["success"]):
				_result = {"outcome": "fled"}
				hud.show_hint("You slip away into the dream...")
				AudioManager.play_sfx("miss")
				_set_state(State.EXITING)
				return
			hud.show_hint("You stumble — no escape this turn!", true)
	if _check_end():
		return
	_set_state(State.STATUS_EFFECT_RESOLUTION)


func _state_status_resolution() -> void:
	await _play(battle.tick_statuses(battle.player))
	if _check_end():
		return
	_set_state(State.ENEMY_TURN)


func _state_enemy_turn() -> void:
	hud.set_banner("Enemy Turn", UiTheme.DANGER)
	await arena.camera_home(0.4)
	for e: Combatant in battle.enemies:
		if not e.is_alive():
			continue
		var ticks := battle.tick_statuses(e)
		if not ticks.is_empty():
			await _play(ticks)
		if not e.is_alive():
			if _check_end():
				return
			continue
		await _play(battle.enemy_turn(e))
		if _check_end():
			return
	_set_state(State.TURN_START)


func _state_victory() -> void:
	var prof := Game.profile
	var rewards := battle.compute_rewards(prof.stats.level)
	prof.stats.health = battle.player.hp
	prof.stats.mana = battle.mana
	var summary := prof.grant_rewards(rewards)
	EventBus.xp_gained.emit(int(summary.get("xp", 0)))
	for e: Combatant in battle.enemies:
		EventBus.enemy_defeated.emit(e.data.id)
	if encounter.unique:
		prof.world.won_encounters[encounter.id] = true
	EventBus.encounter_won.emit(encounter.id)
	for id: String in (summary.get("items", {}) as Dictionary).keys():
		EventBus.item_collected.emit(id, int(summary["items"][id]))
	_result = {"outcome": "victory", "rewards": summary}
	hud.set_banner("Victory", UiTheme.GOLD)
	AudioManager.play_music("", 0.5)
	AudioManager.play_sfx("victory")
	await arena.play_victory()
	hud.show_result(true, summary, _level_before)
	await _await_continue()
	_set_state(State.EXITING)


func _state_defeat() -> void:
	var prof := Game.profile
	var lost := int(prof.inventory.glimmer * 0.1)
	prof.inventory.spend_glimmer(lost)
	prof.stats.full_restore()
	_result = {"outcome": "defeat", "glimmer_lost": lost}
	hud.set_banner("Defeat", UiTheme.DANGER)
	AudioManager.play_music("", 0.5)
	AudioManager.play_sfx("defeat")
	await arena.play_defeat()
	hud.show_result(false, {}, _level_before)
	await _await_continue()
	_set_state(State.EXITING)


func _await_continue() -> void:
	while true:
		var a: Dictionary = await hud.action
		if String(a.get("type", "")) == "continue":
			return


func _state_exiting() -> void:
	await SceneFlow.fade_out(0.5)
	var outcome := String(_result.get("outcome", "fled"))
	if outcome == "fled" and Game.profile:
		Game.profile.stats.health = battle.player.hp
		Game.profile.stats.mana = battle.mana
		Game.profile.stats.changed.emit()
	if game_root and game_root.get("region"):
		(game_root.get("region") as Node3D).visible = true
	var player: PlayerController = game_root.get("player") if game_root else null
	if player:
		player.camera.current = true
		if outcome == "defeat":
			var region: Region = game_root.get("region")
			var sp := region.get_spawn("awakening")
			player.place_at(sp["position"], float(sp["yaw"]))
	if source and is_instance_valid(source) and source.has_method("on_combat_result"):
		source.call("on_combat_result", outcome == "victory", outcome == "fled")
	if is_instance_valid(arena):
		arena.queue_free()
	if is_instance_valid(_layer):
		_layer.queue_free()
	arena = null
	hud = null
	Game.in_combat = false
	AudioManager.play_music(_music_before if _music_before != "" else "music_meadow", 1.0)
	AudioManager.duck_ambience(false)
	EventBus.combat_finished.emit(_result)
	await SceneFlow.fade_in(0.6)
	match outcome:
		"victory":
			SaveManager.autosave("force")
		"defeat":
			EventBus.notify("You wake in the Awakening Hollow. (-%d glimmer)" % int(_result.get("glimmer_lost", 0)), "warning")


# ------------------------------------------------------------------ log text
func describe(e: Dictionary) -> String:
	var n := func(uid: int) -> String:
		var c := battle.get_combatant(uid)
		return "You" if uid == 0 else (c.display_name if c else "?")
	match String(e["type"]):
		"cast":
			if int(e["caster"]) != 0 and String(e.get("name", "")) != "":
				return "%s uses %s." % [n.call(int(e["caster"])), e["name"]]
		"damage":
			var t := "%s take%s %d damage" % [n.call(int(e["target"])), "" if int(e["target"]) == 0 else "s", int(e["amount"])]
			if bool(e.get("crit", false)):
				t += " (critical!)"
			if float(e.get("mult", 1.0)) > 1.01:
				t += " — super effective"
			elif float(e.get("mult", 1.0)) < 0.99:
				t += " — resisted"
			return t + "."
		"heal":
			return "%s recover%s %d health." % [n.call(int(e["target"])), "" if int(e["target"]) == 0 else "s", int(e["amount"])]
		"miss":
			return "%s missed!" % n.call(int(e["source"]))
		"status_applied":
			return "%s: %s." % [n.call(int(e["target"])), e["name"]]
		"interrupted":
			return "%s's charge is interrupted by %s!" % [n.call(int(e["target"])), e["name"]]
		"status_tick":
			return "%s: %s (%+d)." % [n.call(int(e["target"])), e["name"], int(e["amount"])]
		"status_expired":
			return "%s fades from %s." % [e["name"], n.call(int(e["target"]))]
		"death":
			return "%s %s." % [n.call(int(e["target"])), "fall" if int(e["target"]) == 0 else "is defeated"]
		"stunned":
			return "%s is rooted and cannot act!" % n.call(int(e["target"]))
		"charge_start", "phase", "text":
			return String(e.get("text", ""))
		"charge_release":
			return "%s unleashes %s!" % [n.call(int(e["source"])), e["name"]]
	return ""


func _event_color(e: Dictionary) -> Color:
	match String(e["type"]):
		"damage":
			return Color(1.0, 0.6, 0.6) if int(e["target"]) == 0 else Color(1.0, 0.9, 0.6)
		"heal":
			return UiTheme.SUCCESS
		"charge_start", "phase":
			return Color(1.0, 0.6, 0.3)
	return UiTheme.TEXT_DIM
