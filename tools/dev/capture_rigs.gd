extends Node3D
## Dev tool: renders creature rigs front-on for visual QA.
##   godot --rendering-driver opengl3 res://tools/dev/capture_rigs.tscn -- <out_dir> kind[:seed] ...

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://rigs"
	DirAccess.make_dir_recursive_absolute(out)
	var biome: BiomeData = load("res://resources/biomes/dreaming_meadow.tres")
	var env := WorldEnvironment.new()
	env.environment = Region.make_environment(biome)
	add_child(env)
	var light := DirectionalLight3D.new()
	light.light_color = biome.sun_color
	light.light_energy = biome.sun_energy
	light.rotation_degrees = biome.sun_rotation_deg
	add_child(light)
	var cam := Camera3D.new()
	add_child(cam)
	for spec: String in args.slice(1):
		var parts := spec.split(":")
		var rig := CreatureBuilder.build(parts[0], Color.WHITE, {"seed": int(parts[1]) if parts.size() > 1 else 0})
		add_child(rig)
		var h := 1.6 if parts[0] != "gremlin" else 1.0
		cam.position = Vector3(0.6, h + 0.2, 3.0)
		cam.look_at(Vector3(0, h, 0))
		for i in 10:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(out.path_join(spec.replace(":", "_") + ".png"))
		rig.queue_free()
		await get_tree().process_frame
	get_tree().quit()
