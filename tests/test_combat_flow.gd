extends TestCase
## Runs the real CombatManager state machine end to end with an automated
## "player" that answers HUD prompts. Verifies state transitions, victory,
## rewards and that exploration state is restored.

var _manager: CombatManager


func before_each() -> void:
	Game._bind(PlayerProfile.new(Database))
	Game.profile.new_game()
	Game.session_active = true
	for id: String in ["sporeburst", "mycelial_mend", "puffcap_cascade"]:
		Game.profile.learn_spell(id)


func after_each() -> void:
	if is_instance_valid(_manager):
		_manager.queue_free()
	Game.in_combat = false
	Game.session_active = false
	Game.profile = null


func _autoplay(s: int) -> void:
	# Answer prompts on the next frame so the manager is already awaiting.
	await tree.process_frame
	if not is_instance_valid(_manager) or _manager.hud == null:
		return
	var hud := _manager.hud
	match s:
		CombatManager.State.CARD_SELECTION:
			var b := _manager.battle
			var pick := -1
			for i in b.deck.hand.size():
				if b.can_cast(i) == "":
					var sp := b.spell(b.deck.hand[i])
					if sp.base_damage > 0:
						pick = i
						break
			if pick >= 0:
				hud.action.emit({"type": "card", "index": pick})
			else:
				hud.action.emit({"type": "meditate"})
		CombatManager.State.TARGET_SELECTION:
			hud.action.emit({"type": "target", "uid": _manager.battle.living_enemies()[0].uid})
		CombatManager.State.VICTORY, CombatManager.State.DEFEAT:
			for i in 400:
				await tree.process_frame
				if _manager.hud and _manager.hud._result_panel:
					_manager.hud.action.emit({"type": "continue"})
					return


func test_full_battle_victory() -> void:
	_manager = CombatManager.new()
	host.add_child(_manager)
	_manager.state_changed.connect(func(s: int) -> void: _autoplay(s))
	var xp_before := Game.profile.stats.xp + Game.profile.stats.level * 100000
	var won: Array = []
	EventBus.encounter_won.connect(func(id: String) -> void: won.append(id), CONNECT_ONE_SHOT)
	await _manager.start_encounter("enc_sporeling", null)
	var h := _manager.history
	check(h[0] == CombatManager.State.INITIALIZING, "starts INITIALIZING")
	check(CombatManager.State.INTRO in h, "INTRO visited")
	check(CombatManager.State.TURN_START in h, "TURN_START visited")
	check(CombatManager.State.CARD_SELECTION in h, "CARD_SELECTION visited")
	check(CombatManager.State.SPELL_RESOLUTION in h, "SPELL_RESOLUTION visited")
	check(CombatManager.State.STATUS_EFFECT_RESOLUTION in h, "STATUS_EFFECT_RESOLUTION visited")
	check(CombatManager.State.ENEMY_TURN in h or CombatManager.State.VICTORY in h, "enemy acted or died first")
	eq(h[-1], CombatManager.State.EXITING, "ends EXITING")
	check(CombatManager.State.VICTORY in h, "player wins against a sporeling (history: %s)" % str(h.map(func(x: int) -> String: return CombatManager.State.keys()[x])))
	eq(won, ["enc_sporeling"], "encounter_won emitted")
	check(Game.profile.stats.xp + Game.profile.stats.level * 100000 > xp_before, "xp awarded")
	check(not Game.in_combat, "exploration resumed")
	check(_manager.arena == null, "arena cleaned up")


func test_targeting_with_two_enemies() -> void:
	_manager = CombatManager.new()
	host.add_child(_manager)
	_manager.state_changed.connect(func(s: int) -> void: _autoplay(s))
	await _manager.start_encounter("enc_sporelings", null)
	check(CombatManager.State.TARGET_SELECTION in _manager.history, "multi-enemy fights ask for a target")
	check(CombatManager.State.VICTORY in _manager.history or CombatManager.State.DEFEAT in _manager.history, "battle concluded")
