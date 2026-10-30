class_name DreamingMeadow
extends Region
## THE DREAMING MEADOW — first playable region of the Sporelands.
## A violet valley ringed by mountains: the player wakes in the south, the
## Mushroom Keeper lives at the heart, Glimmermere glows in the east, the
## Rootstone Circle hums in the west and the sealed Northern Gate looks
## towards the distant village of Sporehaven.

# --- Layout (x = east, z = south) -------------------------------------------
const SPAWN := Vector2(0, 92)
const KEEPER := Vector2(12, -46)
const KEEPER_NPC := Vector2(15, -37)
const LANTERN := Vector2(-30, -2)
const CIRCLE := Vector2(-74, -20)
const LAKE := Vector2(68, 14)
const LAKE_R := 30.0
const SHRINE := Vector2(72, 20)
const HOLLOW := Vector2(-98, 66)
const HOLLOW_ENTRANCE := Vector2(-84, 60)
const NORTH_GATE := Vector2(0, -126)
const HOLLOW_GATE := Vector2(-62, -100)
const DRIFT_START := Vector2(38, -72)
const DRIFT_ISLE := Vector3(58, 30, -94)
const OLLO_POS := Vector2(-9, 30)
const PETALUNE_POS := Vector2(48, 46)
const SIGHTING := Vector2(-16, -62)
const CRYSTAL_GROVE := Vector2(98, -26)
const CROOK := Vector2(-36, 54)
const GRIZZLE_POS := Vector2(-31, 56)
## Treasure nooks: [position, chest id, loot, grade, seal tag ("" = none), echo text]
const TREASURES := [
	[Vector2(-90, -42), "chest_shadow_nook", {"items": {"ember_arrow": 10, "dewdrop_tonic": 2}, "glimmer": 40, "mana_essence": 3}, "rare", "shadow", ""],
	[Vector2(84, 36), "chest_astral_shrine", {"items": {"night_ink": 2, "frost_arrow": 10}, "glimmer": 35, "mana_essence": 3}, "rare", "astral", ""],
	[Vector2(22, -104), "chest_rune_north", {"items": {"scroll_paradox_gift": 1, "spore_arrow": 8}, "glimmer": 45, "mana_essence": 3}, "rare", "rune", ""],
	[Vector2(-50, 70), "chest_root_gate", {"items": {"toadstool_tea": 2, "gremlin_cog": 3}, "glimmer": 40, "mana_essence": 3}, "rare", "root", ""],
	[Vector2(40, 72), "chest_mycelium", {"items": {"mana_moss": 3, "lumen_ring": 1}, "glimmer": 30, "mana_essence": 4}, "rare", "mycelium", ""],
	[Vector2(-64, -8), "chest_circle_echo", {"items": {"dream_mote": 2}, "glimmer": 25, "mana_essence": 5}, "rare", "echo",
		"[i]The stones remember a night of falling stars. Four figures stood here — one in shadow, one in lantern-light, one wreathed in runes, one with a cap like a little red moon. They each pressed a hand to a stone, and the meadow fell asleep around them so the Root could keep dreaming.[/i]\n\nSomeone has been pulling those hands away, one by one."],
	[Vector2(-104, 74), "chest_hidden_hollow", {"items": {"dreamsteel_sword": 1, "dewdrop_tonic": 2}, "glimmer": 50, "mana_essence": 2}, "common", "", ""],
	[Vector2(102, -30), "chest_crystal_grove", {"items": {"beetle_shard": 3, "frost_arrow": 6}, "glimmer": 30, "mana_essence": 2}, "common", "", ""],
	[Vector2(26, -50), "chest_keeper_garden", {"items": {"gnarlwood_shield": 1, "ember_arrow": 6}, "glimmer": 20, "mana_essence": 1}, "common", "", ""],
	[Vector2(-30, 62), "chest_crookhollow_cellar", {"items": {"crooked_hat": 1}, "glimmer": 15, "mana_essence": 2}, "rare", "", ""],
]
const MAIN_PATH := [Vector2(0, 92), Vector2(-6, 72), Vector2(4, 50), Vector2(-4, 26), Vector2(-14, 8), Vector2(-6, -14), Vector2(8, -30), Vector2(15, -35)]

var ground_material: ShaderMaterial
var circle_node: Node3D
var _rift: Node3D
var _ambient_motes: CPUParticles3D
var _player: Node3D
var _respawns: Array[Dictionary] = []
var _spawned_quest_nodes: Dictionary = {}


func _init() -> void:
	region_id = "dreaming_meadow"
	biome_id = "dreaming_meadow"
	world_seed = 20261029


func _build_content() -> void:
	await report(0.05, "Listening to the ground hum...")
	_build_terrain()
	await report(0.18, "Filling Glimmermere with light...")
	MeadowLandmarks.lake(self, LAKE, LAKE_R)
	MeadowLandmarks.lily_path(self, Vector2(64, 42), Vector2(70, 26.5), 7)
	await report(0.26, "Growing the giants...")
	_build_landmarks()
	await report(0.42, "Planting a forest of mushrooms...")
	_build_mushroom_forest()
	await report(0.56, "Twisting the trees...")
	_build_trees_and_crystals()
	await report(0.66, "Teaching the flowers to breathe...")
	_build_flowers()
	_build_ground_cover()
	await report(0.78, "Raising islands into the sky...")
	_build_sky_pieces()
	await report(0.86, "Waking the creatures...")
	_build_life()
	_build_interactables()
	_build_treasures()
	_build_npcs()
	_build_creatures()
	await report(0.96, "The meadow is dreaming of you...")
	_setup_quest_hooks()
	add_spawn("awakening", Vector3(SPAWN.x, ground(SPAWN.x, SPAWN.y) + 0.2, SPAWN.y), 0.0)
	add_spawn("default", Vector3(SPAWN.x, ground(SPAWN.x, SPAWN.y) + 0.2, SPAWN.y - 2.0), 0.0)
	add_spawn("keeper", Vector3(KEEPER_NPC.x, ground(KEEPER_NPC.x, KEEPER_NPC.y + 6) + 0.2, KEEPER_NPC.y + 6), 0.0)
	AudioManager.play_music(biome.music)
	AudioManager.play_ambience(biome.ambience)


# ------------------------------------------------------------------ terrain
func _build_terrain() -> void:
	terrain = DreamTerrain.new()
	terrain.name = "Terrain"
	terrain.biome = biome
	terrain.size = 320.0
	terrain.cell = 2.0
	terrain.chunks = 5
	terrain.rim_start = 118.0
	terrain.rim_end = 158.0
	terrain.rim_height = 46.0
	terrain.setup(world_seed)
	terrain.rim_passes = [Vector3(0.0, 0.32, 0.12), Vector3(-0.55, 0.12, 0.55)]
	terrain.hills = [
		Vector4(CIRCLE.x, CIRCLE.y, 26, 4.5),
		Vector4(-95, 25, 22, 7.0), Vector4(-112, 70, 20, 9.0), Vector4(-82, 92, 18, 8.0),
		Vector4(-105, 48, 14, 6.0), Vector4(105, 75, 30, 9.0), Vector4(30, 100, 20, 4.0),
		Vector4(95, -60, 25, 8.0), Vector4(-40, -90, 20, 6.0), Vector4(SHRINE.x, SHRINE.y, 7, 3.4),
		Vector4(-60, -100, 20, 10.0),
	]
	terrain.flats = [
		Vector4(SPAWN.x, SPAWN.y, 13, 0.6), Vector4(KEEPER.x, KEEPER.y, 26, 0.4),
		Vector4(HOLLOW.x, HOLLOW.y, 14, 1.2), Vector4(NORTH_GATE.x, NORTH_GATE.y + 4, 12, 2.5),
		Vector4(HOLLOW_GATE.x, HOLLOW_GATE.y + 6, 10, 3.0), Vector4(DRIFT_START.x, DRIFT_START.y, 8, 0.5),
		Vector4(CIRCLE.x, CIRCLE.y, 14, 4.0), Vector4(OLLO_POS.x, OLLO_POS.y, 7, 0.2),
		Vector4(CROOK.x, CROOK.y, 20, 0.8),
	]
	terrain.basins = [Vector4(LAKE.x, LAKE.y, LAKE_R, 2.8)]
	terrain.paths = [
		{"points": PackedVector2Array([SPAWN, Vector2(-6, 72), Vector2(4, 50), Vector2(-4, 26), Vector2(-14, 8), Vector2(-6, -14), Vector2(8, -30), Vector2(KEEPER_NPC.x, KEEPER_NPC.y + 2)]), "width": 3.2},
		{"points": PackedVector2Array([Vector2(-4, 26), Vector2(18, 30), Vector2(36, 38), Vector2(PETALUNE_POS.x + 4, PETALUNE_POS.y - 2)]), "width": 2.6},
		{"points": PackedVector2Array([Vector2(-14, 8), Vector2(-40, -4), Vector2(-60, -14)]), "width": 2.6},
		{"points": PackedVector2Array([Vector2(KEEPER.x - 4, KEEPER.y - 14), Vector2(6, -76), Vector2(2, -100), Vector2(NORTH_GATE.x, NORTH_GATE.y + 6)]), "width": 3.0},
		{"points": PackedVector2Array([Vector2(-6, -14), Vector2(-30, -58), Vector2(HOLLOW_GATE.x, HOLLOW_GATE.y + 8)]), "width": 2.2},
		{"points": PackedVector2Array([Vector2(6, -76), Vector2(26, -74), Vector2(DRIFT_START.x - 2, DRIFT_START.y)]), "width": 2.0},
		{"points": PackedVector2Array([Vector2(1, 58), Vector2(-14, 56), Vector2(CROOK.x, CROOK.y)]), "width": 2.8},
	]
	terrain.water_level = -0.9
	add_child(terrain)
	ground_material = MaterialLib.ground(biome)
	set_meta("ground_material", ground_material)
	terrain.build(ground_material)


# ------------------------------------------------------------------ landmarks
func _build_landmarks() -> void:
	MeadowLandmarks.keeper_house(self, KEEPER)
	MeadowLandmarks.lantern_cap(self, LANTERN)
	circle_node = MeadowLandmarks.rootstone_circle(self, CIRCLE)
	MeadowLandmarks.lake_shrine(self, SHRINE)
	MeadowLandmarks.north_gate(self, NORTH_GATE)
	MeadowLandmarks.hollow_gate(self, HOLLOW_GATE)
	MeadowLandmarks.hidden_hollow(self, HOLLOW, HOLLOW_ENTRANCE)
	MeadowLandmarks.dark_castle(self, Vector2(10, -270))
	MeadowLandmarks.crookhollow(self, CROOK)
	MeadowLandmarks.lantern_row(self, PackedVector2Array(MAIN_PATH), 15.0, 2.6)
	MeadowLandmarks.lantern_row(self, PackedVector2Array([Vector2(1, 58), Vector2(-14, 56), Vector2(-24, 55)]), 9.0, 2.2)
	_build_awakening_hollow()
	_build_drift_route()


func _build_awakening_hollow() -> void:
	var root := Node3D.new()
	root.name = "AwakeningHollow"
	add_child(root)
	root.position = Vector3(SPAWN.x, ground(SPAWN.x, SPAWN.y), SPAWN.y)
	# Moss bed the player wakes on.
	var bed := MeshKit.new()
	var noise := FastNoiseLite.new()
	noise.seed = 3
	bed.ellipsoid(Vector3(0, -0.15, 0.4), Vector3(1.8, 0.35, 2.4), Color("#6a3fc0"), 6, 14, Basis.IDENTITY, noise, 0.15,
		func(d: Vector3) -> Color:
			var c := Color("#6a3fc0").lerp(Color("#36fff0"), clampf(d.y, 0.0, 1.0) * 0.35)
			c.a = 0.3 * clampf(d.y, 0.0, 1.0)
			return c)
	var bmi := MeshInstance3D.new()
	bmi.mesh = bed.commit(MaterialLib.plant())
	root.add_child(bmi)
	# A fairy ring of glowing mushrooms.
	var kit := MeshKit.new()
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 11
	for i in 16:
		var a := TAU * i / 16.0
		var p := MushroomGenerator.random_params(rng2, biome, "small")
		p.glow_color = Color("#36fff0")
		p.emission_intensity = 1.0
		var s := rng2.randf_range(1.4, 2.4)
		p.stem_height *= s
		p.cap_radius *= s
		p.cap_height *= s
		p.stem_width *= s
		var pos := Vector3(cos(a) * 7.0, ground(SPAWN.x + cos(a) * 7.0, SPAWN.y + sin(a) * 7.0) - root.position.y - 0.05, sin(a) * 7.0)
		MushroomGenerator.build_into(kit, p, Transform3D(Basis(Vector3.UP, rng2.randf() * TAU), pos))
	var kmi := MeshInstance3D.new()
	kmi.mesh = kit.commit(MaterialLib.mushroom())
	root.add_child(kmi)
	MeadowLandmarks.glow_light(root, Vector3(0, 2.0, 0), Color(0.4, 1.0, 0.9), 1.5, 12.0)
	var motes := SpellFX.ambient_motes(Color(0.5, 1.0, 0.9), 40, Vector3(7, 2, 7), 0.12)
	motes.position = Vector3(0, 1.5, 0)
	root.add_child(motes)


func _build_drift_route() -> void:
	var base := Vector3(DRIFT_START.x, ground(DRIFT_START.x, DRIFT_START.y), DRIFT_START.y)
	var holder := Node3D.new()
	holder.name = "DriftRoute"
	add_child(holder)
	holder.global_position = base
	# Ground pad -> floating cap 1 -> floating cap 2 -> Drift Isle. Every pad is
	# aimed at a landing spot beside the next pad, so each hop is reliable.
	var tops: Array[Vector3] = [Vector3(0, 0, 0), Vector3(6, 9, -7), Vector3(12, 18.5, -13), DRIFT_ISLE + Vector3(0, 0.1, 0) - base]
	for i in 3:
		var here := tops[i]
		var nxt := tops[i + 1]
		var dir := Vector3(nxt.x - here.x, 0, nxt.z - here.z).normalized()
		if i > 0:
			_floating_platform(holder, here)
		var pad_pos := here + dir * (0.0 if i == 0 else 1.6) + (Vector3(0, -0.4, 0) if i == 0 else Vector3(0, 0.3, 0))
		var bm := MeadowLandmarks.bounce_mushroom(holder, pad_pos, Vector3.UP * 15.0, Color("#ffe14f") if i == 0 else Color("#36fff0"), 1.2)
		var pad := bm.get_node("Pad") as BouncePad
		pad.has_target = true
		# Land on the near side of the next platform, away from its own pad.
		var next_dir := dir if i == 2 else Vector3(tops[i + 2].x - nxt.x, 0, tops[i + 2].z - nxt.z).normalized()
		if i < 2:
			pad.target_point = base + nxt - next_dir * 1.2 + Vector3(0, 0.4, 0)
			pad.clearance = 2.5
		else:
			# The isle is wide: arc high and land well inside so the rise clears its rim.
			pad.target_point = DRIFT_ISLE + Vector3(0, 0.5, 0) - next_dir * 4.0
			pad.clearance = 5.0
	var isle := MeadowLandmarks.floating_island(self, DRIFT_ISLE, 9.0, 7.0, {"walkable": true, "mushrooms": 5, "drift": false, "waterfall": true, "fall_height": 26.0})
	isle.name = "DriftIsle"
	landmarks["drift_isle_top"] = DRIFT_ISLE + Vector3(0, 0.6, 0)


func _floating_platform(parent: Node3D, local_pos: Vector3) -> void:
	var p := MushroomParams.new()
	p.seed = int(local_pos.y * 100)
	p.cap_shape = MushroomParams.CapShape.PARASOL
	p.floating = true
	p.stem_height = 0.3
	p.stem_width = 0.3
	p.cap_radius = 3.4
	p.cap_height = 0.9
	p.tendrils = 7
	p.cap_color = Color("#9b2cf0")
	p.cap_top_color = Color("#ff5fc8")
	p.glow_color = Color("#36fff0")
	p.spot_color = Color("#ffe14f")
	p.spots = 7
	p.emission_intensity = 1.0
	var info := MushroomGenerator.build(p)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.position = local_pos - Vector3(0, 1.0, 0)
	var mi := MeshInstance3D.new()
	mi.mesh = info["mesh"]
	body.add_child(mi)
	Props.add_cylinder(body, Vector3(0, 1.0, 0), 3.2, 0.6)
	parent.add_child(body)


# ------------------------------------------------------------------ vegetation
func _scatter() -> Scatter:
	var s := Scatter.new(terrain, rng)
	# Keep landmarks, plazas and quest spaces readable.
	s.exclude_circle(Vector3(SPAWN.x, 0, SPAWN.y), 9.0)
	s.exclude_circle(Vector3(KEEPER.x, 0, KEEPER.y), 21.0)
	s.exclude_circle(Vector3(LANTERN.x, 0, LANTERN.y), 9.0)
	s.exclude_circle(Vector3(CIRCLE.x, 0, CIRCLE.y), 15.0)
	s.exclude_circle(Vector3(LAKE.x, 0, LAKE.y), LAKE_R + 2.0)
	s.exclude_circle(Vector3(HOLLOW.x, 0, HOLLOW.y), 9.0)
	s.exclude_circle(Vector3(HOLLOW_ENTRANCE.x, 0, HOLLOW_ENTRANCE.y), 5.0)
	s.exclude_circle(Vector3(NORTH_GATE.x, 0, NORTH_GATE.y), 12.0)
	s.exclude_circle(Vector3(HOLLOW_GATE.x, 0, HOLLOW_GATE.y), 10.0)
	s.exclude_circle(Vector3(DRIFT_START.x + 6, 0, DRIFT_START.y - 6), 10.0)
	s.exclude_circle(Vector3(OLLO_POS.x, 0, OLLO_POS.y), 5.0)
	s.exclude_circle(Vector3(PETALUNE_POS.x, 0, PETALUNE_POS.y), 5.0)
	s.exclude_circle(Vector3(SIGHTING.x, 0, SIGHTING.y), 8.0)
	s.exclude_circle(Vector3(CROOK.x, 0, CROOK.y), 19.0)
	for t: Array in TREASURES:
		var tp: Vector2 = t[0]
		s.exclude_circle(Vector3(tp.x, 0, tp.y), 5.0)
	s.exclude_circle(Vector3(DRIFT_ISLE.x, 0, DRIFT_ISLE.z), 4.0)
	return s


var _scatter_main: Scatter


func _build_mushroom_forest() -> void:
	_scatter_main = _scatter()
	var s := _scatter_main
	var density := Settings.scatter_density()
	# Giant mushrooms in groves (forests), each unique with walkable caps.
	var groves: Array[Vector4] = [
		Vector4(-55, 45, 30, 7), Vector4(30, 72, 26, 5), Vector4(-45, -45, 22, 4), Vector4(55, -40, 26, 5),
		Vector4(-100, -10, 18, 3), Vector4(95, 50, 18, 3), Vector4(-70, 85, 20, 4), Vector4(30, -105, 16, 3),
	]
	var giant_count := 0
	for g: Vector4 in groves:
		var xforms := s.place({"center": Vector3(g.x, 0, g.y), "radius": g.z, "count": int(g.w), "spacing": 13.0, "max_slope": 0.35, "path_margin": 6.0})
		for x: Transform3D in xforms:
			var p := MushroomGenerator.random_params(rng, biome, "giant")
			if rng.randf() < 0.3:
				p.cap_color = Color("#ff7a1f")
				p.cap_top_color = Color("#ffc23a")
				p.glow_color = Color("#ffe14f")
			MeadowLandmarks.mushroom_from_params(self, p, Vector2(x.origin.x, x.origin.z), rng.randf() * TAU)
			giant_count += 1
	# Twisted mushrooms (unique meshes, collision).
	var twisted := s.place({"count": int(26 * density), "spacing": 7.0, "area": Rect2(-120, -120, 240, 240), "max_slope": 0.4, "path_margin": 3.0, "max_height": 8.0, "min_height": -0.2})
	for x: Transform3D in twisted:
		var p := MushroomGenerator.random_params(rng, biome, "twisted")
		MeadowLandmarks.mushroom_from_params(self, p, Vector2(x.origin.x, x.origin.z), rng.randf() * TAU)
	# Medium mushrooms: a handful of variants rendered via MultiMesh, each with a stem collider.
	var variants: Array[Dictionary] = []
	for i in 10:
		variants.append(MushroomGenerator.build(MushroomGenerator.random_params(rng, biome, "medium")))
	var medium := s.place({"count": int(220 * density), "spacing": 2.6, "area": Rect2(-125, -125, 250, 250), "max_slope": 0.45, "path_margin": 1.6, "min_height": -0.3,
		"density_map": func(p: Vector3) -> float: return _forest_density(p), "scale": Vector2(0.8, 1.4)})
	var buckets: Array = []
	buckets.resize(variants.size())
	for i in buckets.size():
		buckets[i] = [] as Array[Transform3D]
	var colliders := StaticBody3D.new()
	colliders.name = "MediumMushroomColliders"
	add_child(colliders)
	for x: Transform3D in medium:
		var vi := rng.randi() % variants.size()
		(buckets[vi] as Array[Transform3D]).append(x)
		var sc := x.basis.get_scale().x
		Props.add_capsule(colliders, x.origin + Vector3.UP * 0.2, x.origin + Vector3.UP * float(variants[vi]["stem_height"]) * sc * 0.9, float(variants[vi]["stem_radius"]) * sc * 1.2)
	for i in variants.size():
		var mmi := Props.multimesh(variants[i]["mesh"], buckets[i], false, 0.0)
		add_child(mmi)
		register_detail(mmi, 0.0, 115.0)
	print("Meadow: %d giant, %d twisted, %d medium mushrooms" % [giant_count, twisted.size(), medium.size()])


## More vegetation away from the open central meadow and paths.
func _forest_density(p: Vector3) -> float:
	var r := Vector2(p.x, p.z).length()
	var center_open := smoothstep(25.0, 60.0, Vector2(p.x + 5.0, p.z - 10.0).length())
	return clampf(0.25 + center_open * 0.75 - smoothstep(118.0, 130.0, r), 0.0, 1.0)


func _build_trees_and_crystals() -> void:
	var s := _scatter_main
	var density := Settings.scatter_density()
	var trees := s.place({"count": int(34 * maxf(density, 0.6)), "spacing": 9.0, "area": Rect2(-125, -125, 250, 250), "max_slope": 0.4, "path_margin": 4.0, "min_height": -0.2,
		"density_map": func(p: Vector3) -> float: return _forest_density(p)})
	var body := StaticBody3D.new()
	body.name = "TreeColliders"
	add_child(body)
	var tree_batches := SpatialBatcher.new(self, 2)
	for x: Transform3D in trees:
		var h := rng.randf_range(7.0, 15.0)
		var th := h * rng.randf_range(0.05, 0.08)
		var tr := TreeGenerator.build_kits(rng, biome, h, th)
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU), x.origin - Vector3.UP * 0.2)
		tree_batches.add(tr["trunk"], MaterialLib.bark(), xf)
		tree_batches.add(tr["leaves"], MaterialLib.foliage(), xf)
		Props.add_capsule(body, x.origin, x.origin + Vector3.UP * h * 0.6, th * 1.1)
	tree_batches.commit("Trees", true)
	# Crystal formations: east grove + scattered on rocky ground.
	var crystal_body := StaticBody3D.new()
	crystal_body.name = "CrystalColliders"
	add_child(crystal_body)
	var spots := s.place({"center": Vector3(CRYSTAL_GROVE.x, 0, CRYSTAL_GROVE.y), "radius": 16.0, "count": 9, "spacing": 4.0, "max_slope": 0.6, "path_margin": 0.0})
	spots.append_array(s.place({"count": 16, "spacing": 10.0, "area": Rect2(-125, -125, 250, 250), "max_slope": 0.8, "min_height": 1.5, "path_margin": 3.0}))
	var crystal_batches := SpatialBatcher.new(self, 2)
	for x: Transform3D in spots:
		var cr := CrystalGenerator.build_kits(rng, biome, rng.randf_range(1.6, 4.5), rng.randf_range(0.3, 0.6), rng.randi_range(4, 8))
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU), x.origin)
		crystal_batches.add(cr["crystal"], MaterialLib.crystal(1.4), xf)
		crystal_batches.add(cr["rock"], MaterialLib.stone(), xf)
		Props.add_cylinder(crystal_body, x.origin + Vector3.UP * 0.8, float(cr["radius"]) * 0.7, 1.6)
	crystal_batches.commit("Crystals", true)
	# Boulders with glowing veins.
	var rocks := s.place({"count": int(40 * density), "spacing": 5.0, "area": Rect2(-128, -128, 256, 256), "max_slope": 0.7, "path_margin": 2.0})
	var rock_body := StaticBody3D.new()
	rock_body.name = "RockColliders"
	add_child(rock_body)
	var rock_meshes: Array[ArrayMesh] = []
	for i in 5:
		rock_meshes.append(Props.rock_mesh(rng, biome, Vector3(1.4, 0.9, 1.2), i % 2 == 0))
	var rock_buckets: Array = []
	for i in rock_meshes.size():
		rock_buckets.append([] as Array[Transform3D])
	for x: Transform3D in rocks:
		var sc := rng.randf_range(0.6, 2.2)
		(rock_buckets[rng.randi() % rock_meshes.size()] as Array[Transform3D]).append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sc), x.origin - Vector3.UP * 0.2 * sc))
		if sc > 1.0:
			Props.add_cylinder(rock_body, x.origin + Vector3.UP * 0.4 * sc, 1.1 * sc, 1.2 * sc)
	for i in rock_meshes.size():
		var mmi := Props.multimesh(rock_meshes[i], rock_buckets[i], true)
		add_child(mmi)
		register_detail(mmi, 0.0, 160.0)


func _build_flowers() -> void:
	var s := _scatter_main
	var count := int(55 * Settings.scatter_density())
	var spots := s.place({"count": count, "spacing": 3.0, "area": Rect2(-110, -110, 220, 220), "max_slope": 0.35, "path_margin": 1.2, "min_height": -0.3,
		"density_map": func(p: Vector3) -> float: return 1.0 - _forest_density(p) * 0.6})
	# Flowers along the lake shore get special attention.
	spots.append_array(s.place({"center": Vector3(LAKE.x, 0, LAKE.y), "radius": LAKE_R + 10.0, "inner_radius": LAKE_R + 2.5, "count": 14, "spacing": 3.0, "path_margin": 1.0}))
	var holder := Node3D.new()
	holder.name = "Flowers"
	add_child(holder)
	for x: Transform3D in spots:
		var big := rng.randf() < 0.25
		var f := FlowerGenerator.build(rng, biome, rng.randf_range(2.2, 4.2) if big else rng.randf_range(0.9, 1.8), rng.randf_range(1.0, 1.6) if big else rng.randf_range(0.45, 0.8))
		holder.add_child(f)
		f.global_position = x.origin - Vector3.UP * 0.1


func _build_ground_cover() -> void:
	var s := Scatter.new(terrain, rng)
	s.exclude_circle(Vector3(LAKE.x, 0, LAKE.y), LAKE_R - 2.0)
	var density := Settings.scatter_density()
	# Grass tufts (several variants, MultiMesh, no shadows).
	var tufts: Array[ArrayMesh] = []
	for i in 4:
		tufts.append(Props.grass_tuft_mesh(biome, 100 + i))
	var grass := s.place({"count": 6000, "spacing": 0.0, "area": Rect2(-120, -120, 240, 240), "max_slope": 0.5, "path_margin": 0.8, "occupy": false, "attempts_per_item": 2, "scale": Vector2(0.7, 1.6), "min_height": -0.6})
	_multi_variants(tufts, grass, 0.3, 50.0)
	# Small glowing mushrooms.
	var smalls: Array[ArrayMesh] = []
	for i in 8:
		var p := MushroomGenerator.random_params(rng, biome, "small")
		smalls.append(MushroomGenerator.build(p)["mesh"])
	var small_spots := s.place({"count": 1200, "spacing": 0.0, "area": Rect2(-120, -120, 240, 240), "max_slope": 0.5, "path_margin": 0.6, "occupy": false, "attempts_per_item": 2, "scale": Vector2(0.6, 1.6),
		"density_map": func(p: Vector3) -> float: return 0.3 + _forest_density(p) * 0.7})
	_multi_variants(smalls, small_spots, 0.0, 60.0)
	print("Meadow: %d grass tufts, %d small mushrooms (density %.2f)" % [grass.size(), small_spots.size(), density])


func _multi_variants(meshes: Array[ArrayMesh], xforms: Array[Transform3D], min_density: float, vis_range: float) -> void:
	var buckets: Array = []
	for i in meshes.size():
		buckets.append([] as Array[Transform3D])
	for i in xforms.size():
		(buckets[i % meshes.size()] as Array[Transform3D]).append(xforms[i])
	for i in meshes.size():
		var mmi := Props.multimesh(meshes[i], buckets[i], false)
		add_child(mmi)
		register_detail(mmi, min_density, vis_range)


func _build_sky_pieces() -> void:
	# Floating islands drifting above the meadow.
	var islands: Array[Vector4] = [
		Vector4(-40, 48, -30, 10), Vector4(85, 42, -10, 7), Vector4(-85, 60, 40, 12), Vector4(20, 65, 60, 8),
		Vector4(-20, 75, -85, 14), Vector4(110, 55, 70, 9), Vector4(-115, 45, -70, 8), Vector4(60, 38, 95, 6),
	]
	for i in islands.size():
		var v := islands[i]
		MeadowLandmarks.floating_island(self, Vector3(v.x, v.y, v.z), v.w, v.w * 0.9, {"waterfall": i % 3 == 0, "fall_height": v.y * 0.7, "orbit": 6.0 if i % 2 == 0 else 0.0, "bob": 1.2})
	# A waterfall pouring into Glimmermere from a low island.
	MeadowLandmarks.floating_island(self, Vector3(LAKE.x + 14, 24, LAKE.y - 10), 6.0, 5.0, {"waterfall": true, "fall_height": 26.0, "bob": 0.3})
	# The Sky River: a ribbon of water arcing between two islands.
	_sky_river(Vector3(-40, 48, -30), Vector3(85, 42, -10), 34.0, 5.0)
	# Floating mushrooms drifting lazily.
	for i in 12:
		var p := MushroomGenerator.random_params(rng, biome, "floating")
		var info := MushroomGenerator.build(p)
		var holder := Node3D.new()
		var a := rng.randf() * TAU
		var d := rng.randf_range(20.0, 110.0)
		holder.position = Vector3(cos(a) * d, rng.randf_range(12.0, 30.0), sin(a) * d)
		holder.scale = Vector3.ONE * rng.randf_range(1.0, 2.5)
		var mi := MeshInstance3D.new()
		mi.mesh = info["mesh"]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(mi)
		add_child(holder)
		var fb := FloatBob.new()
		fb.amplitude = 1.5
		fb.orbit = rng.randf_range(4.0, 12.0)
		fb.orbit_speed = rng.randf_range(0.02, 0.05)
		holder.add_child(fb)
	# Silhouettes of colossal mushrooms beyond the rim make the world feel endless.
	var far := MeshKit.new()
	for i in 22:
		var a := TAU * i / 22.0 + rng.randf() * 0.15
		if absf(wrapf(a - (-PI * 0.5), -PI, PI)) < 0.35:
			continue
		var d := rng.randf_range(185.0, 240.0)
		var p := MushroomGenerator.random_params(rng, biome, "giant")
		var sc := rng.randf_range(2.0, 3.5)
		p.stem_height *= sc
		p.stem_width *= sc
		p.cap_radius *= sc
		p.cap_height *= sc
		p.cap_segments = 18
		p.spots = 4
		MushroomGenerator.build_into(far, p, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(cos(a) * d, 10.0, sin(a) * d)))
	var fmi := MeshInstance3D.new()
	fmi.mesh = far.commit(MaterialLib.mushroom())
	fmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fmi)


func _sky_river(a: Vector3, b: Vector3, arc: float, width: float) -> void:
	var kit := MeshKit.new()
	var steps := 40
	var prev := PackedInt32Array()
	var dir := (b - a)
	var side := Vector3(-dir.z, 0, dir.x).normalized()
	for i in steps + 1:
		var t := float(i) / steps
		var c := a.lerp(b, t) + Vector3.UP * sin(t * PI) * arc + side * sin(t * TAU) * 8.0
		var w := width * (0.8 + 0.2 * sin(t * 9.0))
		var l := kit.add_vertex(c - side * w, Color.WHITE, Vector2(0, t * 20.0))
		var r := kit.add_vertex(c + side * w, Color.WHITE, Vector2(1, t * 20.0))
		if prev.size() == 2:
			kit.add_quad(prev[0], prev[1], r, l)
		prev = PackedInt32Array([l, r])
	var mi := MeshInstance3D.new()
	mi.mesh = kit.commit(MaterialLib.water("sky_river", {"flow_speed": 2.0, "flow_dir": Vector2(1, 0), "alpha": 0.7, "glow": 1.5, "wave_height": 0.15}))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


# ------------------------------------------------------------------ life
func _build_life() -> void:
	# Sky drifters: jellyfish-like creatures orbiting slowly overhead.
	for i in 7:
		var rig := CreatureBuilder.build("sky_drifter", Color.WHITE, {"seed": i})
		var holder := Node3D.new()
		var a := TAU * i / 7.0
		var d := rng.randf_range(30.0, 90.0)
		holder.position = Vector3(cos(a) * d, rng.randf_range(14.0, 28.0), sin(a) * d)
		rig.scale = Vector3.ONE * rng.randf_range(1.0, 2.2)
		holder.add_child(rig)
		add_child(holder)
		var fb := FloatBob.new()
		fb.amplitude = 2.0
		fb.speed = 0.5
		fb.orbit = rng.randf_range(10.0, 25.0)
		fb.orbit_speed = rng.randf_range(0.03, 0.07)
		holder.add_child(fb)
	# Motes of light that follow the explorer around.
	_ambient_motes = SpellFX.ambient_motes(Color(0.75, 1.0, 0.6), 140, Vector3(26, 6, 26), 0.11)
	_ambient_motes.local_coords = false
	add_child(_ambient_motes)
	var spores := SpellFX.ambient_motes(Color(1.0, 0.5, 0.9), 60, Vector3(30, 8, 30), 0.08)
	spores.local_coords = false
	_ambient_motes.add_child(spores)


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
		return
	if _ambient_motes:
		_ambient_motes.global_position = _player.global_position + Vector3.UP * 2.0


# ------------------------------------------------------------------ interactables
func _add(node: Node3D, xz: Vector2, y_offset: float = 0.0) -> Node3D:
	add_child(node)
	node.global_position = Vector3(xz.x, ground(xz.x, xz.y) + y_offset, xz.y)
	return node


func _collectible(item_id: String, world_id: String, pos: Vector3, beam: bool = false, xp: int = 0) -> Collectible:
	var c := Collectible.new()
	c.item_id = item_id
	c.world_id = world_id
	c.radius = 1.0
	c.marker_height = 1.3
	c.xp_reward = xp
	var d := Database.item(item_id)
	var col := d.icon_color if d else Color.CYAN
	var visual := Node3D.new()
	visual.name = "Visual"
	var kit := MeshKit.new()
	if item_id == "spore_fragment":
		kit.crystal_prism(Vector3(0, -0.35, 0), Basis.IDENTITY, 0.8, 0.18, 5, Color(col.r, col.g, col.b, 1.0), 0.45)
		kit.crystal_prism(Vector3(0, 0.35, 0), Basis(Vector3.RIGHT, PI), 0.5, 0.14, 5, Color(col.r, col.g, col.b, 1.0), 0.45)
	else:
		kit.ellipsoid(Vector3.ZERO, Vector3.ONE * 0.22, Color(col.r, col.g, col.b, 1.0), 6, 10)
		for k in 4:
			var b := Basis(Vector3.UP, k * PI * 0.5) * Basis(Vector3.RIGHT, PI * 0.5)
			kit.crystal_prism(Vector3.ZERO, b, 0.45, 0.05, 4, Color(1.0, 1.0, 0.85, 1.0), 0.6)
	var mi := MeshInstance3D.new()
	mi.mesh = kit.commit(MaterialLib.crystal(2.2))
	visual.add_child(mi)
	visual.position.y = 0.2
	c.add_child(visual)
	add_child(c)
	c.global_position = pos
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = 1.2
	l.omni_range = 4.0
	l.position.y = 0.4
	c.add_child(l)
	if beam:
		MeadowLandmarks.light_beam(c, Vector3.ZERO, col, 40.0, 0.35)
	return c


func _lore(lore_id: String, title: String, text: String, xz: Vector2, kind: String = "stone", activate_id: String = "") -> LoreObject:
	var lo := LoreObject.new()
	lo.lore_id = lore_id
	lo.lore_title = title
	lo.lore_text = text
	lo.display_name = title
	lo.activate_id = activate_id
	lo.radius = 1.4
	lo.marker_height = 2.4
	var kit := MeshKit.new()
	if kind == "stone":
		# A tapered standing stone ringed with glowing glyph bands.
		var stone := biome.rock_color.lightened(0.28)
		var path := PackedVector3Array()
		var radii := PackedFloat32Array()
		for i in 7:
			var t := float(i) / 6.0
			path.append(Vector3(sin(t * 2.0) * 0.08, t * 2.3, 0))
			radii.append(0.42 * (1.0 - t * 0.45) + 0.12 * exp(-t * 6.0))
		kit.tube(path, radii, 6, func(t: float) -> Color:
			var c := stone.lerp(stone.lightened(0.2), t)
			c.a = 0.0
			return c, true, true)
		for band in 3:
			var bt := 0.3 + band * 0.22
			var center := Vector3(sin(bt * 2.0) * 0.08, bt * 2.3, 0)
			var r := (0.42 * (1.0 - bt * 0.45) + 0.12 * exp(-bt * 6.0)) * 1.06
			var ring := PackedVector3Array()
			var rr := PackedFloat32Array()
			for k in 13:
				var a := TAU * k / 12.0
				ring.append(center + Vector3(cos(a) * r, sin(a * 3.0) * 0.04, sin(a) * r))
				rr.append(0.035)
			kit.tube(ring, rr, 4, func(_t: float) -> Color: return Color(1.0, 0.82, 0.35, 1.0), false, false)
		kit.crystal_prism(Vector3(0, 2.55, 0), Basis.IDENTITY, 0.5, 0.12, 5, Color(1.0, 0.85, 0.4))
	var mi := MeshInstance3D.new()
	mi.mesh = kit.commit(MaterialLib.stone())
	lo.add_child(mi)
	_add(lo, xz, -0.1)
	return lo


func _build_interactables() -> void:
	var prof := Game.profile
	# --- Spore Fragments (main quest), each marked by a beam of light.
	_collectible("spore_fragment", "fragment_shrine", landmarks["shrine_altar"] + Vector3(0, 0.3, 0), true)
	_collectible("spore_fragment", "fragment_circle", landmarks["circle_altar"] + Vector3(0, 0.6, 0), true)
	_collectible("spore_fragment", "fragment_hollow", Vector3(HOLLOW.x - 2, ground(HOLLOW.x - 2, HOLLOW.y + 2) + 1.0, HOLLOW.y + 2), true)
	# --- Dream Motes (side quest / exploration), hidden off the main path.
	_collectible("dream_mote", "mote_drift_isle", landmarks["drift_isle_top"] + Vector3(2, 1.0, 1), false, 10)
	_collectible("dream_mote", "mote_keeper_cap", landmarks["keeper_cap_top"] + Vector3(0, 0.8, 0), false, 10)
	_collectible("dream_mote", "mote_lantern", Vector3(LANTERN.x + 2.5, ground(LANTERN.x + 2.5, LANTERN.y + 3) + 1.0, LANTERN.y + 3), false, 5)
	_collectible("dream_mote", "mote_gate_ruins", Vector3(NORTH_GATE.x - 9, ground(NORTH_GATE.x - 9, NORTH_GATE.y + 8) + 1.0, NORTH_GATE.y + 8), false, 10)
	_collectible("dream_mote", "mote_fairy_ring", Vector3(-52, ground(-52, 42) + 1.0, 42), false, 10)
	_collectible("dream_mote", "mote_hollow", Vector3(HOLLOW.x + 4, ground(HOLLOW.x + 4, HOLLOW.y - 4) + 1.0, HOLLOW.y - 4), false, 10)
	# Hidden fairy ring around the mote in the western forest.
	var ring := MeshKit.new()
	var r2 := RandomNumberGenerator.new()
	r2.seed = 66
	for i in 12:
		var a := TAU * i / 12.0
		var p := MushroomGenerator.random_params(r2, biome, "small")
		p.glow_color = Color("#ffe14f")
		var pos := Vector3(-52 + cos(a) * 3.0, ground(-52 + cos(a) * 3.0, 42 + sin(a) * 3.0) - 0.05, 42 + sin(a) * 3.0)
		MushroomGenerator.build_into(ring, p, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 1.6), pos))
	var rmi := MeshInstance3D.new()
	rmi.mesh = ring.commit(MaterialLib.mushroom())
	add_child(rmi)
	# --- Singing crystals: activating them makes a mote drift down.
	var singing := Mechanism.new()
	singing.object_id = "singing_crystals"
	singing.display_name = "Singing Crystals"
	singing.prompt = "Touch"
	singing.radius = 2.0
	singing.marker_height = 2.8
	_add(singing, CRYSTAL_GROVE + Vector2(-3, 6), 0.5)
	var singing_crystal := CrystalGenerator.build(rng, biome, 3.2, 0.5, 7, true, 2.4)
	var scmi := MeshInstance3D.new()
	scmi.mesh = singing_crystal["mesh"]
	singing.add_child(scmi)
	singing.activated.connect(func() -> void:
		SpellFX.burst(self, singing.global_position + Vector3.UP * 2.0, Color(0.4, 1.0, 1.0), 80, 6.0)
		EventBus.notify("The crystals sing a falling note. Something drifts down from the sky...", "lore")
		var c := _collectible("dream_mote", "mote_singing", singing.global_position + Vector3(0, 14, 3), false, 10)
		var tw := c.create_tween()
		tw.tween_property(c, "global_position", singing.global_position + Vector3(0, 1.2, 3), 4.0).set_trans(Tween.TRANS_SINE))
	if prof and prof.world.has_flag("activated_singing_crystals") and not prof.world.is_consumed("mote_singing"):
		_collectible("dream_mote", "mote_singing", singing.global_position + Vector3(0, 1.2, 3), false, 10)
	# --- Rest pools.
	for pos: Vector2 in [Vector2(SPAWN.x + 6, SPAWN.y + 4), Vector2(KEEPER.x + 13, KEEPER.y + 10), Vector2(40, 30), Vector2(-60, -4)]:
		_rest_pool(pos)
	# --- Lore.
	_lore("waking_stone", "The Waking Stone",
		"Carved in a script you somehow read:\n\n\"Every dreamer wakes here. Every dreamer forgets. The meadow does not.\"\n\nBeneath it, many tally marks. The most recent one is still wet.",
		SPAWN + Vector2(-4, -6))
	_lore("lantern_carving", "Carving on the Lantern Cap",
		"\"The first gardeners did not plant the mushrooms. They listened to them. The mushrooms told them where to build, where to sleep, and where never to dig.\"",
		LANTERN + Vector2(3.5, 4.5))
	_lore("circle_glyph", "Rootstone Glyphs",
		"Seven stones, seven threads of the Mycelium. When the circle is in tune, the whole meadow sings one note. Right now the stones hum seven different songs, none of them happy.",
		CIRCLE + Vector2(0, 12))
	_lore("shrine_glimmermere", "Glimmermere Inscription",
		"\"The lake is a memory of the sky. If you look long enough, you can see what the sky looked like before it learned to dream.\"\n\nIn the water, for a moment, the stars are arranged differently.",
		SHRINE + Vector2(-2.5, 2.5))
	_lore("dreamers_shrine", "The Dreamers' Shrine",
		"Small offerings: a button, a pressed flower, a key to a door that doesn't exist here. Each one has a name scratched beside it.\n\nOne of the names is yours. The handwriting is yours, too.",
		HOLLOW + Vector2(3, 3))
	var isle_lore := LoreObject.new()
	isle_lore.lore_id = "drift_isle"
	isle_lore.lore_title = "The Island That Remembers Falling"
	isle_lore.display_name = isle_lore.lore_title
	isle_lore.lore_text = "Up here the hum of the Mycelium is quieter, like a song heard through a wall. The island's roots dangle into nothing, still reaching for ground it lost long ago."
	isle_lore.radius = 1.5
	add_child(isle_lore)
	isle_lore.global_position = landmarks["drift_isle_top"] + Vector3(-2, 0.5, -1)
	_lore("gate_inscription", "Northern Gate Inscription",
		"\"Through here: the Whispering Forest. Speak softly. The trees are listening, and they repeat everything.\"\n\nSomeone has scratched underneath: \"THEY ARE NOT REPEATING. THEY ARE ANSWERING.\"",
		NORTH_GATE + Vector2(7, 6))
	# --- Ancient mechanism: the Rootstone Circle.
	var mech := Mechanism.new()
	mech.object_id = "rootstone_circle"
	mech.display_name = "Rootstone Altar"
	mech.prompt = "Attune"
	mech.required_flag = "rift_seen"
	mech.locked_message = "The stones hum seven different songs. You don't know how to tune them — yet."
	mech.radius = 2.4
	mech.marker_height = 2.0
	mech.marker_color = Color(0.5, 1.0, 0.7)
	add_child(mech)
	mech.global_position = landmarks["circle_altar"] + Vector3(0, -0.5, 2.6)
	mech.activated.connect(func() -> void:
		MeadowLandmarks.awaken_circle(self, circle_node)
		EventBus.notify("The seven songs become one. Something huge stirs inside the circle...", "lore")
		_spawn_guardian())
	if prof and prof.world.has_flag("activated_rootstone_circle"):
		MeadowLandmarks.awaken_circle(self, circle_node)
	# --- Discovery zones.
	_discovery("awakening_hollow", "The Awakening Hollow", SPAWN, 12.0, 0, true)
	_discovery("keeper_grove", "Umbel's Grove", KEEPER + Vector2(0, 10), 18.0)
	_discovery("lantern_cap", "The Lantern Cap", LANTERN, 14.0)
	_discovery("glimmermere", "Glimmermere", LAKE + Vector2(-10, 30), 14.0)
	_discovery("rootstone_circle", "The Rootstone Circle", CIRCLE, 14.0)
	_discovery("hidden_hollow", "The Hidden Hollow", HOLLOW, 9.0, 40)
	_discovery("north_gate", "The Northern Gate", NORTH_GATE + Vector2(0, 8), 12.0)
	_discovery("hollow_gate", "The Hollow Gate", HOLLOW_GATE + Vector2(0, 10), 12.0)
	_discovery("crystal_grove", "The Singing Grove", CRYSTAL_GROVE, 14.0)
	_discovery("ollo_crossing", "Ollo's Crossing", OLLO_POS, 8.0, 5)
	var isle_zone := DiscoveryZone.new()
	isle_zone.area_id = "drift_isle"
	isle_zone.display_name = "Drift Isle"
	isle_zone.radius = 9.0
	isle_zone.height = 6.0
	isle_zone.xp_reward = 40
	add_child(isle_zone)
	isle_zone.global_position = DRIFT_ISLE + Vector3(0, 2.0, 0)


func _rest_pool(xz: Vector2) -> void:
	var pool := RestPool.new()
	pool.radius = 1.6
	pool.marker_height = 1.5
	_add(pool, xz, 0.0)
	var kit := MeshKit.new()
	kit.lathe(PackedVector2Array([Vector2(0, 0.15), Vector2(1.2, 0.15), Vector2(1.5, 0.3), Vector2(1.7, 0.1), Vector2(1.8, -0.2)]), 20, Vector3.ZERO, Basis.IDENTITY,
		func(t: float, _a: float) -> Color: return Color(0.2, 1.0, 0.9, 1.0) if t < 0.3 else Color(0.4, 0.25, 0.6, 0.1), Callable(), true, false)
	var mi := MeshInstance3D.new()
	mi.mesh = kit.commit(MaterialLib.stone())
	pool.add_child(mi)
	var motes := SpellFX.ambient_motes(Color(0.4, 1.0, 0.9), 16, Vector3(1.0, 1.0, 1.0), 0.1)
	motes.position = Vector3(0, 1.0, 0)
	pool.add_child(motes)


func _discovery(area_id: String, display: String, xz: Vector2, radius: float, xp: int = 15, silent: bool = false) -> void:
	var z := DiscoveryZone.new()
	z.area_id = area_id
	z.display_name = display
	z.radius = radius
	z.xp_reward = xp
	z.silent = silent
	_add(z, xz, 0.0)


# ------------------------------------------------------------------ NPCs
func _build_npcs() -> void:
	var keeper := NPC.new()
	keeper.npc_id = "mushroom_keeper"
	keeper.display_name = "Umbel"
	keeper.title = "the Mushroom Keeper"
	keeper.dialogue_id = "keeper_main"
	keeper.visual_kind = "keeper"
	keeper.talk_radius = 1.8
	_add(keeper, KEEPER_NPC)
	keeper.rotation.y = 0.0
	var petalune := NPC.new()
	petalune.npc_id = "madame_petalune"
	petalune.display_name = "Madame Petalune"
	petalune.title = "a flower of considerable opinion"
	petalune.dialogue_id = "petalune"
	petalune.visual_kind = "petalune"
	petalune.talk_radius = 2.0
	petalune.interact_height = 2.0
	_add(petalune, PETALUNE_POS)
	var ollo := NPC.new()
	ollo.npc_id = "ollo"
	ollo.display_name = "Ollo"
	ollo.title = "travelling merchant (slowly)"
	ollo.dialogue_id = "ollo"
	ollo.visual_kind = "ollo"
	ollo.talk_radius = 1.8
	_add(ollo, OLLO_POS)
	var grizzle := NPC.new()
	grizzle.npc_id = "mother_grizzleroot"
	grizzle.display_name = "Mother Grizzleroot"
	grizzle.title = "witch of Crookhollow (mostly harmless)"
	grizzle.dialogue_id = "grizzleroot"
	grizzle.visual_kind = "witch"
	grizzle.talk_radius = 2.0
	grizzle.interact_height = 1.5
	_add(grizzle, GRIZZLE_POS)
	grizzle.rotation.y = atan2(CROOK.x - GRIZZLE_POS.x, CROOK.y - GRIZZLE_POS.y) + PI


# ------------------------------------------------------------------ treasure
func _build_treasures() -> void:
	for t: Array in TREASURES:
		var xz: Vector2 = t[0]
		var chest := TreasureChest.new()
		chest.chest_id = t[1]
		chest.loot = t[2]
		chest.grade = t[3]
		chest.radius = 1.0
		_add(chest, xz)
		chest.rotation.y = rng.randf() * TAU
		if String(t[4]) != "":
			var seal := ClassSeal.new()
			seal.seal_id = "seal_" + String(t[1])
			seal.tag = t[4]
			seal.echo_text = t[5]
			seal.radius = 2.3
			_add(seal, xz)
			chest.seal = seal
	# The Drift Isle's reward for the bounce route.
	var sky := TreasureChest.new()
	sky.chest_id = "chest_drift_isle"
	sky.loot = {"items": {"moonsplitter": 1}, "glimmer": 80, "mana_essence": 6}
	sky.grade = "legendary"
	add_child(sky)
	sky.global_position = DRIFT_ISLE + Vector3(1.5, 0.2, 1.5)


# ------------------------------------------------------------------ creatures
func _creature(creature_id: String, encounter_id: String, xz: Vector2, unique_id: String = "", opts: Dictionary = {}) -> WorldCreature:
	var c := WorldCreature.new()
	c.creature_id = creature_id
	c.encounter_id = encounter_id
	c.unique_id = unique_id
	c.terrain = terrain
	c.home_radius = float(opts.get("home_radius", 10.0))
	c.aggro_radius = float(opts.get("aggro", 9.0))
	_add(c, xz)
	if unique_id == "":
		_respawns.append({"creature": c, "creature_id": creature_id, "encounter_id": encounter_id, "xz": xz, "opts": opts, "timer": 0.0})
	return c


func _build_creatures() -> void:
	_creature("sporeling", "enc_sporeling", Vector2(-8, 10))
	_creature("sporeling", "enc_sporelings", Vector2(28, 58))
	_creature("sporeling", "enc_sporeling", Vector2(-40, 30))
	_creature("sporeling", "enc_sporeling", Vector2(40, -20))
	_creature("crystal_beetle", "enc_crystal_beetle", CRYSTAL_GROVE + Vector2(6, -4))
	_creature("crystal_beetle", "enc_crystal_beetle", Vector2(92, 42))
	_creature("crystal_beetle", "enc_beetle_pair", Vector2(-38, -52))
	_creature("hollow_crone", "enc_crone", Vector2(-58, 40), "", {"home_radius": 8.0})
	_creature("hollow_crone", "enc_coven", Vector2(-50, 76), "", {"home_radius": 6.0})
	_creature("cackling_crone", "enc_crone", Vector2(-22, -40), "", {"home_radius": 8.0})
	_creature("gnasher_gremlin", "enc_gremlin", Vector2(30, 76), "", {"home_radius": 12.0})
	_creature("gnasher_gremlin", "enc_gremlin_gang", Vector2(-20, -92), "", {"home_radius": 12.0})
	_creature("gnasher_gremlin", "enc_gremlin", Vector2(80, -50), "", {"home_radius": 12.0})
	_creature("dream_fox", "enc_dream_fox", Vector2(48, -8), "", {"home_radius": 16.0})
	# The Ancient Spore Golem sleeps before the Hollow Gate until challenged.
	_creature("spore_golem", "enc_spore_golem", HOLLOW_GATE + Vector2(0, 9), "enc_spore_golem", {"home_radius": 0.5})


func _physics_process(delta: float) -> void:
	# Respawn ordinary creatures a while after they were defeated, out of sight.
	for r: Dictionary in _respawns:
		if is_instance_valid(r["creature"]):
			continue
		r["timer"] = float(r["timer"]) + delta
		if float(r["timer"]) < 150.0:
			continue
		var xz: Vector2 = r["xz"]
		if _player and _player.global_position.distance_to(Vector3(xz.x, _player.global_position.y, xz.y)) < 45.0:
			continue
		var c := WorldCreature.new()
		c.creature_id = r["creature_id"]
		c.encounter_id = r["encounter_id"]
		c.terrain = terrain
		c.home_radius = float((r["opts"] as Dictionary).get("home_radius", 10.0))
		_add(c, xz)
		r["creature"] = c
		r["timer"] = 0.0


# ------------------------------------------------------------------ quest hooks
func _setup_quest_hooks() -> void:
	EventBus.quest_tracker_changed.connect(_sync_quest_world)
	EventBus.object_activated.connect(_on_object_activated)
	EventBus.encounter_won.connect(_on_encounter_won)
	EventBus.quest_state_changed.connect(_on_quest_state)
	_sync_quest_world()


func _sync_quest_world() -> void:
	var prof := Game.profile
	if prof == null:
		return
	var q := prof.quests
	# The hollow-eyed sporeling appears once the player has learned magic.
	var need_corrupted := q.is_objective_current("first_awakening", "spot_creature") or q.is_objective_current("first_awakening", "defeat_creature")
	if need_corrupted and not _spawned_quest_nodes.has("corrupted"):
		var zone := DiscoveryZone.new()
		zone.area_id = "corrupted_sighting"
		zone.is_discovery = false
		zone.radius = 14.0
		_add(zone, SIGHTING)
		var c := _creature("hollow_sporeling", "enc_corrupted_sporeling", SIGHTING, "enc_corrupted_sporeling", {"aggro": 13.0, "home_radius": 4.0})
		_spawned_quest_nodes["corrupted"] = c
		var beam := MeadowLandmarks.light_beam(self, Vector3(SIGHTING.x, ground(SIGHTING.x, SIGHTING.y), SIGHTING.y), Color(1.0, 0.3, 0.7), 30.0, 0.5)
		_spawned_quest_nodes["corrupted_beam"] = beam
	# The rift appears where the corrupted sporeling fell.
	if prof.world.won_encounters.has("enc_corrupted_sporeling") and _rift == null:
		_spawn_rift()
		if _spawned_quest_nodes.has("corrupted_beam") and is_instance_valid(_spawned_quest_nodes["corrupted_beam"]):
			(_spawned_quest_nodes["corrupted_beam"] as Node).queue_free()
	# The Bloom Guardian waits in the circle while it must be calmed.
	if q.is_objective_current("hum_beneath", "defeat_guardian") and not _spawned_quest_nodes.has("guardian"):
		_spawn_guardian()


func _spawn_rift() -> void:
	_rift = Node3D.new()
	_rift.name = "MycelialRift"
	_add(_rift, SIGHTING)
	var kit := MeshKit.new()
	# A jagged glowing crack in the ground with threads spilling out.
	for i in 9:
		var t := float(i) / 8.0
		var p := Vector3((t - 0.5) * 7.0, 0.05, sin(t * 9.0) * 0.6)
		kit.ellipsoid(p, Vector3(0.6, 0.08, 0.25 + sin(t * PI) * 0.35), Color(1.0, 0.25, 0.75, 1.0), 3, 8, Basis(Vector3.UP, sin(t * 7.0) * 0.5))
	for i in 7:
		var a := TAU * i / 7.0
		var tp := PackedVector3Array()
		var tr := PackedFloat32Array()
		for k in 8:
			var t := float(k) / 7.0
			tp.append(Vector3(cos(a) * t * 3.0, sin(t * PI) * 1.2 + t * 0.5, sin(a) * t * 3.0) + Vector3(sin(t * 6.0 + a) * 0.3, 0, 0))
			tr.append(0.06 * (1.0 - t * 0.7))
		kit.tube(tp, tr, 4, func(t: float) -> Color: return Color(1.0, 0.3, 0.8, 0.3 + t * 0.7).lerp(Color(0.3, 1.0, 0.95, 1.0), t), false, true)
	var mi := MeshInstance3D.new()
	mi.mesh = kit.commit(MaterialLib.organic("rift", {"emission": 4.0, "pulse": 0.6, "pulse_speed": 3.0, "sway": 0.3, "sway_height": 2.0}))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rift.add_child(mi)
	var particles := SpellFX.ambient_motes(Color(1.0, 0.35, 0.8), 50, Vector3(3.5, 1.5, 1.5), 0.15)
	particles.position = Vector3(0, 1.0, 0)
	_rift.add_child(particles)
	MeadowLandmarks.glow_light(_rift, Vector3(0, 1.5, 0), Color(1.0, 0.3, 0.75), 3.0, 14.0)
	var lo := LoreObject.new()
	lo.lore_id = "lore_rift"
	lo.lore_title = "The Mycelial Rift"
	lo.display_name = "Mycelial Rift"
	lo.activate_id = "mycelial_rift"
	lo.radius = 3.0
	lo.marker_height = 2.2
	lo.marker_color = Color(1.0, 0.4, 0.8)
	lo.lore_text = "Where the hollow-eyed sporeling fell, the ground has split. Inside, the threads of the Mycelium are... grey. Unlit. As if something drank the light out of them.\n\nYou put your hand near the crack and hear, very faintly, seven stones humming out of tune — somewhere to the west."
	lo.position = Vector3(0, 0.5, 0)
	_rift.add_child(lo)


func _spawn_guardian() -> void:
	if _spawned_quest_nodes.has("guardian") or (Game.profile and Game.profile.world.won_encounters.has("enc_bloom_guardian")):
		return
	var c := _creature("bloom_guardian", "enc_bloom_guardian", CIRCLE + Vector2(0, -3), "enc_bloom_guardian", {"aggro": 12.0, "home_radius": 3.0})
	_spawned_quest_nodes["guardian"] = c
	c.scale = Vector3.ONE * 0.01
	c.create_tween().tween_property(c, "scale", Vector3.ONE, 2.0).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _on_object_activated(object_id: String) -> void:
	if object_id == "mycelial_rift" and Game.profile:
		Game.profile.world.set_flag("rift_seen", true)


func _on_encounter_won(encounter_id: String) -> void:
	if encounter_id == "enc_corrupted_sporeling":
		_sync_quest_world()


func _on_quest_state(qid: String, state: int) -> void:
	# If the rift was already inspected before its quest began, credit it.
	if qid == "hum_beneath" and state == QuestData.State.ACTIVE and Game.profile:
		if "lore_rift" in Game.profile.world.lore:
			Game.profile.quests.complete_objective("hum_beneath", "inspect_rift")
