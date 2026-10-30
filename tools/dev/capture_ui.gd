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
	Game.profile.choose_class("wizard")
	Game.profile.add_mana_essence(9)
	Game.profile.unlock_path_node("focused_bolt")
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
	get_tree().quit()
