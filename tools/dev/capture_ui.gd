extends Node
## Dev tool: screenshots of combat, dialogue and menus in a real session.
##   godot --rendering-driver opengl3 res://tools/dev/capture_ui.tscn -- <out_dir>

var _out := "user://ui_shots"
var game: Node


func _shot(name: String, frames: int = 20) -> void:
	for i in frames:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(_out.path_join(name + ".png"))
	print("shot ", name)


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	Game.start_new_game()
	Game.pending_spawn = {"spawn": "keeper"}
	for id: String in ["sporeburst", "mycelial_mend", "puffcap_cascade", "shardstorm", "starfall_seed"]:
		Game.profile.learn_spell(id)
	Game.profile.inventory.add("dewdrop_tonic", 3)
	Game.profile.inventory.add("keeper_staff", 1)
	game = load("res://scenes/main/game.tscn").instantiate()
	add_child(game)
	while game.get("player") == null:
		await get_tree().process_frame
	await _shot("explore_keeper", 40)
	# Dialogue.
	EventBus.location_visited.emit("awakening_hollow")
	EventBus.location_visited.emit("keeper_grove")
	var keeper: NPC = get_tree().get_first_node_in_group("npc")
	keeper.start_dialogue()
	await _shot("dialogue", 120)
	game.get("dialogue_box").close()
	# Grimoire tabs.
	for tab: String in ["inventory", "spellbook", "skills", "journal", "map", "character"]:
		game.open_grimoire(tab)
		await _shot("grimoire_" + tab, 15)
	game.get("grimoire").close()
	# Combat.
	var cm: CombatManager = game.get("combat")
	var shots := {"card": false, "target": false}
	cm.state_changed.connect(func(s: int) -> void: _auto(cm, s, shots))
	EventBus.combat_requested.emit("enc_sporelings", null)
	while not Game.in_combat:
		await get_tree().process_frame
	while Game.in_combat:
		await get_tree().process_frame
	await _shot("after_combat", 30)
	get_tree().quit()


func _auto(cm: CombatManager, s: int, shots: Dictionary) -> void:
	await get_tree().process_frame
	if cm.hud == null:
		return
	match s:
		CombatManager.State.CARD_SELECTION:
			if not shots["card"]:
				shots["card"] = true
				await _shot("combat_cards", 40)
			var b := cm.battle
			var pick := -1
			for i in b.deck.hand.size():
				if b.can_cast(i) == "" and b.spell(b.deck.hand[i]).base_damage > 0:
					pick = i
			if pick >= 0:
				cm.hud.action.emit({"type": "card", "index": pick})
			else:
				cm.hud.action.emit({"type": "meditate"})
		CombatManager.State.TARGET_SELECTION:
			if not shots["target"]:
				shots["target"] = true
				await _shot("combat_target", 10)
			cm.hud.action.emit({"type": "target", "uid": cm.battle.living_enemies()[0].uid})
		CombatManager.State.SPELL_RESOLUTION:
			await _shot("combat_spell_%d" % cm.battle.round_number, 22)
		CombatManager.State.VICTORY, CombatManager.State.DEFEAT:
			while cm.hud and cm.hud._result_panel == null:
				await get_tree().process_frame
			await _shot("combat_result", 60)
			cm.hud.action.emit({"type": "continue"})
