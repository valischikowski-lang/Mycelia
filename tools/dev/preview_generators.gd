extends Node
## Dev tool: renders a lineup of every procedural generator for visual QA.
## Run (needs a display): godot --rendering-driver opengl3 res://tools/dev/preview_generators.tscn -- <out_dir>

func _ready() -> void:
	var out_dir := "user://preview"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	await get_tree().process_frame
	var biome: BiomeData = load("res://resources/biomes/dreaming_meadow.tres")
	var world := Region.new()
	world.biome_id = "dreaming_meadow"
	add_child(world)
	print("building region")
	await world.build()
	print("region built")
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	# Ground disc.
	var g := PlaneMesh.new()
	g.size = Vector2(200, 200)
	g.subdivide_width = 40
	g.subdivide_depth = 40
	var gk := MeshKit.new()
	var mi_g := MeshInstance3D.new()
	var tmat := MaterialLib.ground(biome)
	var t := DreamTerrain.new()
	t.biome = biome
	t.size = 120
	t.rim_start = 1000
	t.setup(3)
	t.paths = [{"points": PackedVector2Array([Vector2(-50, 10), Vector2(0, 5), Vector2(50, 12)]), "width": 3.0}]
	world.add_child(t)
	t.build(tmat)
	var x := -24.0
	for cls: String in ["small", "medium", "giant", "twisted", "floating"]:
		for i in 3:
			var p := MushroomGenerator.random_params(rng, biome, cls)
			var info := MushroomGenerator.build(p)
			var mi := MeshInstance3D.new()
			mi.mesh = info["mesh"]
			var z := -10.0 - i * 8.0
			if cls == "giant":
				z = -40.0 - i * 18.0
			mi.position = Vector3(x + i * 3.0, t.height_at(x, z) + (3.0 if cls == "floating" else 0.0), z)
			world.add_child(mi)
		x += 11.0
	for i in 3:
		var tr := TreeGenerator.build(rng, biome, 9.0, 0.6, i)
		var mi := MeshInstance3D.new()
		mi.mesh = tr["mesh"]
		mi.position = Vector3(-30 + i * 9.0, t.height_at(-30 + i * 9.0, -24), -24)
		world.add_child(mi)
	var cr := CrystalGenerator.build(rng, biome, 3.0, 0.5, 6)
	var cmi := MeshInstance3D.new()
	cmi.mesh = cr["mesh"]
	cmi.position = Vector3(8, t.height_at(8, -2), -2)
	world.add_child(cmi)
	var isl := IslandGenerator.build(rng, biome, 6.0, 5.0, {"waterfall": true, "fall_height": 12.0})
	var imi := MeshInstance3D.new()
	imi.mesh = isl["mesh"]
	imi.position = Vector3(16, 14, -30)
	world.add_child(imi)
	var wf := MeshInstance3D.new()
	wf.mesh = isl["waterfall_mesh"]
	imi.add_child(wf)
	for i in 4:
		var fl := FlowerGenerator.build(rng, biome, 1.4, 0.7)
		fl.position = Vector3(-6 + i * 2.2, t.height_at(-6 + i * 2.2, -3), -3)
		world.add_child(fl)
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.position = Vector3(0, 6, 14)
	cam.look_at(Vector3(0, 4, -20))
	cam.fov = 70
	cam.current = true
	await _shot(out_dir + "/lineup_wide.png")
	cam.position = Vector3(-8, 2.2, 4)
	cam.look_at(Vector3(-6, 1, -8))
	await _shot(out_dir + "/lineup_close.png")
	cam.position = Vector3(20, 8, -8)
	cam.look_at(Vector3(16, 12, -30))
	await _shot(out_dir + "/island.png")
	get_tree().quit()


func _shot(path: String) -> void:
	for i in 12:
		await get_tree().process_frame
		print("frame ", i, " ", Time.get_ticks_msec())
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("saved ", path)
