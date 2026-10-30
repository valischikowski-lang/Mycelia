extends Node
## Dev tool: real-time combat screenshots in the meadow (touch UI forced on).
##   godot --rendering-driver opengl3 res://tools/dev/capture_combat.tscn -- <out_dir> <class>

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://combat"
	var cls := args[1] if args.size() > 1 else "grimlet"
	DirAccess.make_dir_recursive_absolute(out)
	Settings.force_touch_controls = true
	Game.start_new_game()
	Game.profile.choose_class(cls)
	Game.pending_spawn = {"position": Vector3(-50, 0, 38), "yaw": 2.2}
	var game: Node = load("res://scenes/main/game.tscn").instantiate()
	add_child(game)
	while game.get("player") == null:
		await get_tree().process_frame
	var player: PlayerController = game.get("player")
	var region: Region = game.get("region")
	var p := Vector3(-52, 0, 44)
	p.y = region.ground(p.x, p.z) + 0.2
	player.place_at(p, 0.0)
	for i in 30:
		await get_tree().process_frame
	# Face the nearest crone and start fighting.
	var foe := RtFx.nearest(get_tree(), player.global_position, Vector3.FORWARD, RtFx.ENEMY_GROUP, 60.0, -1.0)
	if foe:
		var to := foe.global_position - player.global_position
		player.rotation.y = atan2(-to.x, -to.z)
		foe.call("notice")
		player.combat.lock_target = foe
	for i in 50:
		await get_tree().process_frame
	_shot(out, "1_engaged")
	player.combat.light_attack()
	for i in 6:
		await get_tree().process_frame
	_shot(out, "2_attack")
	var list := Game.profile.usable_abilities()
	if list.size() > 1:
		player.combat.cast_ability(list[1])
	for i in 10:
		await get_tree().process_frame
	_shot(out, "3_ability")
	for i in 120:
		await get_tree().process_frame
	_shot(out, "4_later")
	get_tree().quit()


func _shot(out: String, name: String) -> void:
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("shot ", name, " fps=", Engine.get_frames_per_second())
