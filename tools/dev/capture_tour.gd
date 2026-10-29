extends Node
## Dev tool: boots a new game, then teleports the player to viewpoints and
## saves screenshots for visual QA.
##   godot --rendering-driver opengl3 res://tools/dev/capture_tour.tscn -- <out_dir> [shot names...]

const SHOTS := {
	"spawn": [Vector3(0, 0, 92), 0.0, -2.0],
	"spawn_back": [Vector3(4, 0, 80), 2.6, 0.0],
	"meadow_center": [Vector3(-2, 0, 30), 0.3, 2.0],
	"lantern": [Vector3(-14, 0, 14), 0.75, 12.0],
	"keeper": [Vector3(16, 0, -22), 0.15, 6.0],
	"keeper_close": [Vector3(15, 0, -32), 0.0, 2.0],
	"lake": [Vector3(44, 0, 44), -2.2, 2.0],
	"circle": [Vector3(-58, 0, -6), 0.95, 4.0],
	"north": [Vector3(4, 0, -86), 0.0, 6.0],
	"aerial": [Vector3(0, 60, 140), 0.0, -22.0],
	"hollow": [Vector3(-90, 0, 64), 1.3, 0.0],
	"drift": [Vector3(30, 0, -60), -0.9, 22.0],
}

var _out := "user://tour"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var wanted: Array = []
	if args.size() > 0:
		_out = args[0]
		wanted = args.slice(1)
	DirAccess.make_dir_recursive_absolute(_out)
	Game.start_new_game()
	Game.pending_spawn = {"spawn": "default"}
	var game: Node = load("res://scenes/main/game.tscn").instantiate()
	add_child(game)
	var t0 := Time.get_ticks_msec()
	while game.get("player") == null:
		await get_tree().process_frame
	print("region ready in %d ms" % (Time.get_ticks_msec() - t0))
	var player: PlayerController = game.get("player")
	var region: Region = game.get("region")
	for name: String in SHOTS.keys():
		if not wanted.is_empty() and not name in wanted:
			continue
		var s: Array = SHOTS[name]
		var p: Vector3 = s[0]
		if p.y == 0.0:
			p.y = region.ground(p.x, p.z) + 0.1
		player.place_at(p, float(s[1]))
		player.set_physics_process(false)
		player.head.rotation.x = deg_to_rad(float(s[2]))
		for i in 25:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(_out.path_join(name + ".png"))
		print("shot ", name, " fps=", Engine.get_frames_per_second(), " draws=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " prims=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	get_tree().quit()
