class_name MeadowLandmarks
extends RefCounted
## Hand-composed landmark set pieces of the Dreaming Meadow. Each builder
## receives the region (for terrain height, biome and registration) and
## returns the root node it created.


static func _place(region: Region, node: Node3D, xz: Vector2, y_offset: float = 0.0) -> Node3D:
	region.add_child(node)
	node.global_position = Vector3(xz.x, region.ground(xz.x, xz.y) + y_offset, xz.y)
	return node


static func glow_light(parent: Node3D, pos: Vector3, color: Color, energy: float, light_range: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = light_range
	l.omni_attenuation = 1.4
	l.shadow_enabled = false
	l.position = pos
	parent.add_child(l)
	return l


## Vertical beam of light marking something important from afar.
static func light_beam(parent: Node3D, pos: Vector3, color: Color, height: float = 30.0, radius: float = 0.6) -> MeshInstance3D:
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius * 1.6
	cyl.bottom_radius = radius
	cyl.height = height
	cyl.radial_segments = 12
	cyl.rings = 1
	cyl.cap_top = false
	cyl.cap_bottom = false
	# UV.y runs top->bottom on CylinderMesh; fade towards the top.
	var mat := MaterialLib.glow_unique(color, 1.6, false, true)
	cyl.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = cyl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos + Vector3.UP * height * 0.5
	parent.add_child(mi)
	return mi


static func mushroom_from_params(region: Region, p: MushroomParams, xz: Vector2, yaw: float, walkable: bool = true, y_offset: float = -0.3) -> StaticBody3D:
	var info := MushroomGenerator.build(p, MaterialLib.mushroom_breathing() if p.stem_height > 8.0 else MaterialLib.mushroom())
	var y := region.ground(xz.x, xz.y) + y_offset
	var body := Props.mushroom_body(info, Transform3D(Basis(Vector3.UP, yaw), Vector3(xz.x, y, xz.y)), walkable)
	region.add_child(body)
	body.set_meta("info", info)
	return body


# ------------------------------------------------------------------ Keeper's house
static func keeper_house(region: Region, xz: Vector2) -> Node3D:
	var root := Node3D.new()
	root.name = "KeeperHouse"
	_place(region, root, xz)
	var p := MushroomParams.new()
	p.seed = 2024
	p.cap_shape = MushroomParams.CapShape.DOME
	p.stem_height = 11.0
	p.stem_width = 3.4
	p.stem_bend = 0.8
	p.cap_radius = 12.5
	p.cap_height = 6.0
	p.cap_curvature = 0.75
	p.cap_asymmetry = 0.08
	p.cap_segments = 40
	p.cap_color = Color("#8e2be8")
	p.cap_top_color = Color("#ff5fc8")
	p.glow_color = Color("#36fff0")
	p.spot_color = Color("#ffe14f")
	p.stem_color = Color("#8a74c8")
	p.spots = 18
	p.emission_intensity = 0.7
	var info := MushroomGenerator.build(p, MaterialLib.mushroom_breathing())
	var body := Props.mushroom_body(info, Transform3D(Basis.IDENTITY, Vector3(0, -0.4, 0)), true)
	root.add_child(body)
	# Door facing south (+Z) and round glowing windows.
	var dk := MeshKit.new()
	var door_z := 3.9
	dk.ellipsoid(Vector3(0, 1.6, door_z), Vector3(1.2, 1.9, 0.25), Color(0.12, 0.04, 0.2, 0.0), 8, 14)
	var frame := PackedVector3Array()
	var fr := PackedFloat32Array()
	for i in 15:
		var a := PI * float(i) / 14.0
		frame.append(Vector3(cos(a) * 1.35, 1.6 + sin(a) * 2.1 - 0.0, door_z + 0.15))
		fr.append(0.13)
	frame.append(Vector3(-1.35, -0.2, door_z + 0.15))
	fr.append(0.13)
	frame.insert(0, Vector3(1.35, -0.2, door_z + 0.15))
	fr.insert(0, 0.13)
	dk.tube(frame, fr, 6, func(_t: float) -> Color: return Color(1.0, 0.75, 0.3, 0.9), true, true)
	var windows := [Vector3(2.6, 5.0, 2.7), Vector3(-2.8, 6.4, 2.4), Vector3(0.6, 8.2, 3.2), Vector3(-3.2, 3.6, -1.5), Vector3(3.0, 7.0, -1.8)]
	for w: Vector3 in windows:
		var n := Vector3(w.x, 0, w.z).normalized()
		dk.ellipsoid(w, Vector3(0.6, 0.6, 0.6), Color(1.0, 0.72, 0.3, 1.0), 6, 10, Basis.looking_at(n, Vector3.UP).scaled(Vector3(1, 1, 0.3)))
	var dmi := MeshInstance3D.new()
	dmi.mesh = dk.commit(MaterialLib.organic("house_detail", {"emission": 1.5, "pulse": 0.15}))
	root.add_child(dmi)
	glow_light(root, Vector3(0, 2.5, door_z + 2.5), Color(1.0, 0.7, 0.4), 2.2, 9.0)
	glow_light(root, Vector3(0, 9.0, 0), Color(0.3, 1.0, 0.9), 2.0, 22.0)
	# Spiral stair of shelf fungi around the stem up to a balcony.
	var stair := StaticBody3D.new()
	stair.collision_layer = 1
	root.add_child(stair)
	var sk := MeshKit.new()
	var steps := 14
	var stem_path: PackedVector3Array = info["stem_path"]
	for i in steps:
		var t := float(i) / steps
		var h := 0.9 + t * 9.3
		var a := PI * 0.5 + t * TAU * 1.15
		var stem_idx := clampi(int(h / 11.0 * (stem_path.size() - 1)), 0, stem_path.size() - 1)
		var c := stem_path[stem_idx] + Vector3(0, -0.4, 0)
		var r := 3.4 * 1.15 + 1.1
		var center := Vector3(c.x + cos(a) * r, h, c.z + sin(a) * r)
		var shelf_col := Color("#ff9a3c") if i % 2 == 0 else Color("#ffd166")
		sk.ellipsoid(center, Vector3(1.5, 0.22, 1.1), shelf_col, 5, 12, Basis(Vector3.UP, -a), null, 0.0,
			func(d: Vector3) -> Color:
				var col := shelf_col.lerp(shelf_col.lightened(0.3), d.y * 0.5 + 0.5)
				col.a = 0.6 if d.y < -0.3 else 0.05
				if d.y < -0.3:
					col = Color(0.3, 1.0, 0.9, 0.7)
				return col)
		Props.add_box(stair, center + Vector3(0, 0.05, 0), Vector3(2.6, 0.4, 1.9), Basis(Vector3.UP, -a))
	var smi := MeshInstance3D.new()
	smi.mesh = sk.commit(MaterialLib.mushroom())
	stair.add_child(smi)
	# Balcony bounce pad up onto the cap.
	var last_a := PI * 0.5 + TAU * 1.15
	var balcony := stem_path[stem_path.size() - 1] + Vector3(cos(last_a) * 5.6, -0.6, sin(last_a) * 5.6)
	# The roof is reached from a bounce mushroom outside the rim (south-east),
	# aimed ballistically at the top of the cap.
	var pad_pos := Vector3(13.5, region.ground(xz.x + 13.5, xz.y + 13.5) - root.global_position.y - 0.3, 13.5)
	var bp := bounce_mushroom(root, pad_pos, Vector3.UP * 15.0, Color("#36fff0"), 1.5)
	bp.name = "CapBounce"
	var cap_top: Vector3 = root.global_position + Vector3(0, -0.4, 0) + (info["stem_top"] as Vector3) + Vector3(0, p.cap_height * 0.8, 0)
	var toward := Vector3(pad_pos.x, 0, pad_pos.z).normalized()
	var pad := bp.get_node("Pad") as BouncePad
	pad.has_target = true
	# Land on the dome about 6 m from its centre, on the side facing the pad.
	pad.target_point = Vector3(root.global_position.x + toward.x * 6.0, cap_top.y - 0.8, root.global_position.z + toward.z * 6.0)
	pad.clearance = 3.5
	region.landmarks["keeper_cap_top"] = root.global_position + info["cap_center"] + Vector3(0, 3.0, 0)
	region.landmarks["keeper_door"] = root.global_position + Vector3(0, 0, door_z + 3.5)
	var spores := SpellFX.ambient_motes(Color(0.4, 1.0, 0.9), 40, Vector3(12, 4, 12), 0.14)
	spores.position = Vector3(0, 6, 0)
	root.add_child(spores)
	return root


## Springy mushroom with a BouncePad on top. `pos` is local to parent.
static func bounce_mushroom(parent: Node3D, pos: Vector3, launch: Vector3, glow: Color, cap_radius: float = 1.3) -> Node3D:
	var holder := Node3D.new()
	holder.position = pos
	parent.add_child(holder)
	var p := MushroomParams.new()
	p.seed = int(pos.x * 13.0 + pos.z * 7.0)
	p.cap_shape = MushroomParams.CapShape.PUFFBALL
	p.stem_height = 0.5
	p.stem_width = 0.25
	p.cap_radius = cap_radius
	p.cap_height = cap_radius * 0.55
	p.cap_color = Color("#ff4fa8")
	p.cap_top_color = Color("#ffa0e0")
	p.glow_color = glow
	p.spot_color = glow
	p.spots = 8
	p.emission_intensity = 1.0
	var info := MushroomGenerator.build(p)
	var mi := MeshInstance3D.new()
	mi.mesh = info["mesh"]
	mi.name = "Visual"
	holder.add_child(mi)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	Props.add_cylinder(body, Vector3(0, 0.45, 0), cap_radius * 0.9, 0.9)
	holder.add_child(body)
	var pad := BouncePad.new()
	pad.name = "Pad"
	pad.launch_velocity = launch
	pad.radius = cap_radius * 0.85
	pad.position = Vector3(0, 1.1, 0)
	holder.add_child(pad)
	pad.set("_visual", mi)
	var ring := Label3D.new()
	ring.text = "⇡"
	ring.font_size = 120
	ring.pixel_size = 0.006
	ring.modulate = Color(glow, 0.8)
	ring.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	ring.position = Vector3(0, 2.2, 0)
	holder.add_child(ring)
	return holder


# ------------------------------------------------------------------ Lantern Cap
static func lantern_cap(region: Region, xz: Vector2) -> Node3D:
	var p := MushroomParams.new()
	p.seed = 777
	p.cap_shape = MushroomParams.CapShape.PARASOL
	p.stem_height = 17.0
	p.stem_width = 1.6
	p.stem_bend = 3.0
	p.stem_twist = 0.6
	p.cap_radius = 10.0
	p.cap_height = 3.2
	p.cap_curvature = 0.8
	p.cap_asymmetry = 0.1
	p.cap_segments = 36
	p.cap_color = Color("#ff7a1f")
	p.cap_top_color = Color("#ffc23a")
	p.glow_color = Color("#ffe14f")
	p.spot_color = Color("#fff4c0")
	p.spots = 14
	p.tendrils = 0
	p.emission_intensity = 1.0
	var body := mushroom_from_params(region, p, xz, 0.4)
	body.name = "LanternCap"
	var info: Dictionary = body.get_meta("info")
	var cap_c: Vector3 = info["cap_center"]
	# Hanging lantern pods from the rim.
	var lk := MeshKit.new()
	for i in 10:
		var a := TAU * i / 10.0 + 0.2
		var rr := 8.0 + sin(i * 2.3) * 1.0
		var top := cap_c + Vector3(cos(a) * rr, -1.2, sin(a) * rr)
		var length := 2.0 + absf(sin(i * 1.7)) * 3.0
		lk.tube(PackedVector3Array([top, top + Vector3(0, -length * 0.5, 0.1), top + Vector3(0, -length, 0)]), PackedFloat32Array([0.05, 0.04, 0.03]), 4,
			func(_t: float) -> Color: return Color(1.0, 0.8, 0.4, 0.4), false, false)
		lk.ellipsoid(top + Vector3(0, -length - 0.35, 0), Vector3(0.32, 0.45, 0.32), Color(1.0, 0.75, 0.25, 1.0), 6, 10)
	var lmi := MeshInstance3D.new()
	lmi.mesh = lk.commit(MaterialLib.organic("lantern", {"emission": 3.5, "pulse": 0.4, "sway": 0.15, "sway_height": -4.0}))
	lmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(lmi)
	glow_light(body, cap_c + Vector3(0, -3, 0), Color(1.0, 0.7, 0.3), 3.0, 26.0)
	return body


# ------------------------------------------------------------------ Rootstone Circle
static func rootstone_circle(region: Region, xz: Vector2) -> Node3D:
	var root := Node3D.new()
	root.name = "RootstoneCircle"
	_place(region, root, xz)
	var rng := RandomNumberGenerator.new()
	rng.seed = 314
	var stones := 7
	var body := StaticBody3D.new()
	body.collision_layer = 1
	root.add_child(body)
	var glyph_meshes: Array[MeshInstance3D] = []
	for i in stones:
		var a := TAU * i / stones
		var pos := Vector3(cos(a) * 9.0, 0, sin(a) * 9.0)
		pos.y = region.ground(xz.x + pos.x, xz.y + pos.z) - root.global_position.y - 0.4
		var kit := MeshKit.new()
		var noise := FastNoiseLite.new()
		noise.seed = rng.randi()
		noise.frequency = 1.0
		var h := rng.randf_range(4.5, 6.5)
		var rc := region.biome.rock_color.lightened(0.1)
		var twist := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.FORWARD, rng.randf_range(-0.12, 0.12))
		kit.ellipsoid(Vector3(0, h * 0.5, 0), Vector3(0.9, h * 0.5, 0.7), rc, 9, 10, twist, noise, 0.15,
			func(d: Vector3) -> Color:
				var c := rc.lerp(rc.lightened(0.25), d.y * 0.5 + 0.5)
				c.a = 0.0
				# Carved glyph bands.
				if absf(fmod(d.y * 4.0 + 10.0, 1.0) - 0.5) < 0.08 and d.z > 0.0:
					c = Color(0.3, 1.0, 0.9, 0.9)
				return c)
		# Roots wrapping the stone.
		for r in 3:
			var rp := PackedVector3Array()
			var rr := PackedFloat32Array()
			var ra := rng.randf() * TAU
			for k in 12:
				var t := float(k) / 11.0
				var ang := ra + t * TAU * 1.3
				rp.append(Vector3(cos(ang) * 0.95, t * h * 0.8, sin(ang) * 0.8))
				rr.append(0.12 * (1.0 - t * 0.6))
			kit.tube(rp, rr, 5, func(t: float) -> Color:
				var c := Color(0.3, 0.18, 0.4).lerp(Color(0.5, 0.9, 0.4), t)
				c.a = t * 0.3
				return c, true, true)
		var mi := MeshInstance3D.new()
		mi.mesh = kit.commit(MaterialLib.organic("rootstone", {"emission": 1.0, "pulse": 0.6, "pulse_speed": 0.8, "rim_strength": 0.3}))
		mi.position = pos
		root.add_child(mi)
		glyph_meshes.append(mi)
		Props.add_capsule(body, pos + Vector3(0, 0.5, 0), pos + Vector3(0, h - 0.5, 0), 0.85)
	# Central altar.
	var ak := MeshKit.new()
	var noise2 := FastNoiseLite.new()
	noise2.seed = 9
	ak.ellipsoid(Vector3(0, 0.5, 0), Vector3(2.2, 0.8, 2.2), region.biome.rock_color, 6, 14, Basis.IDENTITY, noise2, 0.1)
	ak.lathe(PackedVector2Array([Vector2(0.0, 1.35), Vector2(1.6, 1.3), Vector2(1.9, 1.15), Vector2(2.0, 1.0)]), 20, Vector3.ZERO, Basis.IDENTITY,
		func(t: float, _a: float) -> Color: return Color(0.3, 1.0, 0.9, 0.5 + t * 0.4) if t > 0.6 else Color(0.35, 0.22, 0.55, 0.1), Callable(), true, false)
	var ami := MeshInstance3D.new()
	ami.mesh = ak.commit(MaterialLib.stone())
	root.add_child(ami)
	Props.add_cylinder(body, Vector3(0, 0.6, 0), 2.0, 1.4)
	region.landmarks["circle_altar"] = root.global_position + Vector3(0, 1.5, 0)
	root.set_meta("glyph_meshes", glyph_meshes)
	glow_light(root, Vector3(0, 3, 0), Color(0.3, 1.0, 0.85), 1.2, 14.0)
	return root


## Environmental event when the circle is attuned: stones flare, a pillar of
## light rises and the ground veins pulse from the circle.
static func awaken_circle(region: Region, circle: Node3D) -> void:
	var glyphs: Array = circle.get_meta("glyph_meshes", [])
	var mat := MaterialLib.organic("rootstone_awake", {"emission": 4.0, "pulse": 0.8, "pulse_speed": 2.5, "rim": Color(0.4, 1.0, 0.8), "rim_strength": 1.2})
	for mi: Variant in glyphs:
		(mi as MeshInstance3D).material_override = mat
	var beam := light_beam(circle, Vector3.ZERO, Color(0.4, 1.0, 0.85), 80.0, 2.5)
	beam.scale = Vector3(0.01, 1, 0.01)
	var tw := beam.create_tween()
	tw.tween_property(beam, "scale", Vector3.ONE, 1.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var l := glow_light(circle, Vector3(0, 4, 0), Color(0.4, 1.0, 0.85), 0.0, 30.0)
	l.create_tween().tween_property(l, "light_energy", 4.0, 1.5)
	SpellFX.burst(circle, circle.global_position + Vector3.UP * 2.0, Color(0.4, 1.0, 0.85), 120, 9.0, 0.3, -1.0)
	var ground_mat := region.get_meta("ground_material") as ShaderMaterial
	if ground_mat:
		ground_mat.set_shader_parameter("pulse_origin", circle.global_position)
		ground_mat.set_shader_parameter("vein_strength", 3.0)
		var gt := region.create_tween()
		gt.tween_interval(6.0)
		gt.tween_method(func(v: float) -> void: ground_mat.set_shader_parameter("vein_strength", v), 3.0, 1.6, 4.0)


# ------------------------------------------------------------------ Glimmermere
static func lake(region: Region, center: Vector2, radius: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Glimmermere"
	region.add_child(root)
	var disc := MeshKit.new()
	var rings := 10
	var sides := 48
	var level := region.terrain.water_level
	var c0 := disc.add_vertex(Vector3(center.x, level, center.y), Color.WHITE)
	var prev := PackedInt32Array()
	for r in range(1, rings + 1):
		var rr := radius * 1.15 * float(r) / rings
		var pts := MeshKit.ring(Vector3(center.x, level, center.y), Basis.IDENTITY, rr, rr, sides)
		var idx := disc.add_ring(pts, Color.WHITE)
		if r == 1:
			disc.fan(idx, c0)
		else:
			disc.bridge(idx, prev, true)
		prev = idx
	var mi := MeshInstance3D.new()
	mi.mesh = disc.commit(MaterialLib.water("lake"))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	# Glowing lily lights scattered on the water.
	var lk := MeshKit.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 55
	for i in 40:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * radius * 0.85
		var p := Vector3(center.x + cos(a) * d, level + 0.04, center.y + sin(a) * d)
		var col := region.biome.pick(region.biome.flower_colors, rng, Color.PINK)
		lk.ellipsoid(p, Vector3(0.45, 0.03, 0.45), Color(0.15, 0.6, 0.45, 0.1), 3, 10)
		lk.ellipsoid(p + Vector3(0, 0.12, 0), Vector3(0.14, 0.12, 0.14), Color(col.r, col.g, col.b, 1.0), 4, 8)
	var lmi := MeshInstance3D.new()
	lmi.mesh = lk.commit(MaterialLib.plant())
	lmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(lmi)
	region.register_detail(lmi, 0.5)
	var motes := SpellFX.ambient_motes(Color(0.4, 1.0, 0.95), 60, Vector3(radius * 0.8, 2.0, radius * 0.8), 0.12)
	motes.position = Vector3(center.x, level + 1.5, center.y)
	root.add_child(motes)
	glow_light(root, Vector3(center.x, level + 3.0, center.y), Color(0.3, 1.0, 0.9), 1.6, radius * 1.2)
	return root


## Floating lily pads forming a jumpable path; returns the last pad position.
static func lily_path(region: Region, from: Vector2, to: Vector2, count: int) -> void:
	var level := region.terrain.water_level
	var body := StaticBody3D.new()
	body.collision_layer = 1
	region.add_child(body)
	var kit := MeshKit.new()
	for i in count:
		var t := float(i) / maxf(1.0, count - 1)
		var xz := from.lerp(to, t) + Vector2(sin(i * 1.7) * 0.8, 0)
		var r := 1.3 + sin(i * 2.1) * 0.2
		var center := Vector3(xz.x, level + 0.12, xz.y)
		var prof := PackedVector2Array([Vector2(0, 0.1), Vector2(r * 0.6, 0.08), Vector2(r, 0.0), Vector2(r * 0.9, -0.08), Vector2(0, -0.1)])
		kit.lathe(prof, 18, center, Basis(Vector3.UP, i * 1.3), func(tt: float, a: float) -> Color:
			var c := Color("#18c9a0").lerp(Color("#5effc4"), tt)
			c.a = 0.5 if absf(sin(a * 6.0)) < 0.15 else 0.05
			return c, func(a: float, _t: float) -> float: return 0.0 if absf(wrapf(a, -PI, PI)) < 0.25 else 1.0, true, true)
		kit.ellipsoid(center + Vector3(r * 0.3, 0.25, 0), Vector3.ONE * 0.18, Color(1.0, 0.6, 0.85, 1.0), 4, 8)
		Props.add_cylinder(body, center, r * 0.9, 0.3)
	var mi := MeshInstance3D.new()
	mi.mesh = kit.commit(MaterialLib.plant())
	body.add_child(mi)


static func lake_shrine(region: Region, xz: Vector2) -> Node3D:
	var root := Node3D.new()
	root.name = "LakeShrine"
	_place(region, root, xz)
	var rng := RandomNumberGenerator.new()
	rng.seed = 808
	# Ring of tall crystals around an altar.
	for i in 6:
		var a := TAU * i / 6.0 + 0.3
		var cr := CrystalGenerator.build(rng, region.biome, rng.randf_range(2.5, 4.5), 0.45, 4, false, 1.8)
		var mi := MeshInstance3D.new()
		mi.mesh = cr["mesh"]
		mi.position = Vector3(cos(a) * 3.2, -0.3, sin(a) * 3.2)
		root.add_child(mi)
	var ak := MeshKit.new()
	ak.lathe(PackedVector2Array([Vector2(0, 1.1), Vector2(0.9, 1.05), Vector2(1.1, 0.9), Vector2(0.7, 0.5), Vector2(1.0, 0.0)]), 16, Vector3.ZERO, Basis.IDENTITY,
		func(t: float, _a: float) -> Color: return Color(0.3, 0.85, 1.0, 0.8) if t < 0.2 else Color(0.35, 0.25, 0.6, 0.05), Callable(), true, true)
	var ami := MeshInstance3D.new()
	ami.mesh = ak.commit(MaterialLib.stone())
	root.add_child(ami)
	var body := StaticBody3D.new()
	Props.add_cylinder(body, Vector3(0, 0.55, 0), 1.0, 1.1)
	root.add_child(body)
	glow_light(root, Vector3(0, 2.5, 0), Color(0.3, 0.9, 1.0), 2.0, 12.0)
	region.landmarks["shrine_altar"] = root.global_position + Vector3(0, 1.4, 0)
	return root


# ------------------------------------------------------------------ Gates
static func north_gate(region: Region, xz: Vector2) -> Node3D:
	var root := Node3D.new()
	root.name = "NorthGate"
	_place(region, root, xz, -0.3)
	var kit := MeshKit.new()
	var body := StaticBody3D.new()
	root.add_child(body)
	for s: float in [-1.0, 1.0]:
		var pp := PackedVector3Array()
		var pr := PackedFloat32Array()
		for i in 16:
			var t := float(i) / 15.0
			var a := t * TAU * 1.5 * s
			pp.append(Vector3(s * 5.0 + cos(a) * 0.6 - s * t * t * 4.0, t * 13.0, sin(a) * 0.6))
			pr.append(0.95 * (1.0 - t * 0.5))
		kit.tube(pp, pr, 9, func(t: float) -> Color:
			var c := Color("#3b2466").lerp(Color("#7b4dff"), t)
			c.a = 0.05 + (0.8 if fmod(t * 7.0, 1.0) < 0.1 else 0.0)
			if c.a > 0.5:
				c = Color(0.3, 1.0, 0.9, 0.9)
			return c, true, true, func(ang: float, t: float) -> float: return 1.0 + 0.15 * sin(ang * 5.0 + t * 10.0))
		Props.add_capsule(body, Vector3(s * 5.0, 0, 0), Vector3(s * 3.0, 9.0, 0), 1.0)
	var gmi := MeshInstance3D.new()
	gmi.mesh = kit.commit(MaterialLib.bark())
	root.add_child(gmi)
	# The dreaming membrane.
	var mem := MeshKit.new()
	var c0 := mem.add_vertex(Vector3(0, 6.0, 0), Color(1, 1, 1, 1), Vector2(0.5, 0.0))
	var ring := PackedInt32Array()
	for i in 32:
		var a := TAU * i / 32.0
		ring.append(mem.add_vertex(Vector3(cos(a) * 3.9, 6.0 + sin(a) * 6.0, 0), Color(1, 1, 1, 1), Vector2(0.5, 1.0)))
	mem.fan(ring, c0)
	mem.fan(ring, c0, true)
	var mmi := MeshInstance3D.new()
	var mm := MaterialLib.glow_unique(Color(0.6, 0.4, 1.0), 1.2, true, false)
	mm.set_shader_parameter("fade_power", 0.6)
	mmi.mesh = mem.commit(mm)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mmi)
	Props.add_box(body, Vector3(0, 5.0, 0), Vector3(7.5, 10.0, 0.6))
	var portal := RegionPortal.new()
	portal.target_region = "whispering_forest"
	portal.visit_id = "north_gate_touch"
	portal.radius = 2.5
	portal.marker_height = 3.0
	portal.position = Vector3(0, 2.0, 1.2)
	portal.sealed_text = "Beyond the shimmering membrane you hear leaves whispering your name — but the gate will not open. The threads that should hold it are torn, as if something pulled them from the other side.\n\n(The Whispering Forest is not yet open in this version of MYCELIA.)"
	root.add_child(portal)
	glow_light(root, Vector3(0, 6, 2), Color(0.6, 0.4, 1.0), 2.5, 18.0)
	var motes := SpellFX.ambient_motes(Color(0.8, 0.6, 1.0), 40, Vector3(5, 6, 2), 0.15)
	motes.position = Vector3(0, 6, 0)
	root.add_child(motes)
	return root


static func hollow_gate(region: Region, xz: Vector2) -> Node3D:
	var root := Node3D.new()
	root.name = "HollowGate"
	_place(region, root, xz, -0.5)
	var kit := MeshKit.new()
	var body := StaticBody3D.new()
	root.add_child(body)
	# A great arch of twisted roots into the hillside.
	for k in 5:
		var pp := PackedVector3Array()
		var pr := PackedFloat32Array()
		var off := (k - 2) * 0.7
		for i in 20:
			var t := float(i) / 19.0
			var a := PI * t
			pp.append(Vector3(cos(a) * (5.5 + off * 0.3), sin(a) * (7.0 + off), off + sin(t * 9.0 + k) * 0.3))
			pr.append(0.5 + 0.25 * sin(t * PI))
		kit.tube(pp, pr, 7, func(t: float) -> Color:
			var c := Color("#2b1a50").lerp(Color("#4b1f62"), t)
			c.a = 0.05
			return c, true, true)
	var gmi := MeshInstance3D.new()
	gmi.mesh = kit.commit(MaterialLib.bark())
	root.add_child(gmi)
	var dark := MeshKit.new()
	dark.ellipsoid(Vector3(0, 2.5, 0.8), Vector3(5.0, 6.0, 0.4), Color(0.02, 0.0, 0.05, 0.0), 6, 16)
	var dmi := MeshInstance3D.new()
	dmi.mesh = dark.commit(MaterialLib.stone())
	root.add_child(dmi)
	Props.add_box(body, Vector3(0, 3.0, 1.0), Vector3(10.0, 7.0, 1.0))
	var portal := RegionPortal.new()
	portal.target_region = "forgotten_caves"
	portal.prompt = "Enter"
	portal.radius = 2.0
	portal.marker_height = 2.5
	portal.position = Vector3(0, 1.5, -0.8)
	portal.sealed_text = "Warm air breathes out of the dark, smelling of earth and old light. Far below, something enormous is dreaming. The way is choked with roots that will not part for you — yet.\n\n(The Forgotten Caves are not yet open in this version of MYCELIA.)"
	root.add_child(portal)
	glow_light(root, Vector3(0, 2, -2), Color(1.0, 0.55, 0.2), 2.0, 12.0)
	return root


# ------------------------------------------------------------------ Hidden Hollow
static func hidden_hollow(region: Region, xz: Vector2, entrance: Vector2) -> Node3D:
	var root := Node3D.new()
	root.name = "HiddenHollow"
	_place(region, root, xz)
	# Curtain of glowing vines hiding the entrance (no collision).
	var vk := MeshKit.new()
	var ent := Vector3(entrance.x, region.ground(entrance.x, entrance.y), entrance.y) - root.global_position
	var dir := (Vector3(xz.x, 0, xz.y) - Vector3(entrance.x, 0, entrance.y)).normalized()
	var side := Vector3(-dir.z, 0, dir.x)
	for i in 22:
		var s := (float(i) / 21.0 - 0.5) * 6.0
		var top := ent + side * s + Vector3.UP * 5.5
		var length := 4.5 + sin(i * 1.9) * 0.8
		var vp := PackedVector3Array()
		var vr := PackedFloat32Array()
		for k in 7:
			var t := float(k) / 6.0
			vp.append(top + Vector3(sin(t * 3.0 + i) * 0.1, -length * t, 0))
			vr.append(0.05)
		vk.tube(vp, vr, 4, func(t: float) -> Color: return Color(0.4, 1.0, 0.6, 0.3 + t * 0.7), false, true)
	# Beam across the top of the curtain.
	vk.tube(PackedVector3Array([ent - side * 3.5 + Vector3.UP * 5.6, ent + side * 3.5 + Vector3.UP * 5.6]), PackedFloat32Array([0.35, 0.35]), 6,
		func(_t: float) -> Color: return Color(0.3, 0.18, 0.4, 0.05), true, true)
	var vmi := MeshInstance3D.new()
	vmi.mesh = vk.commit(MaterialLib.organic("vines", {"emission": 2.2, "sway": 0.25, "sway_height": -5.0}))
	vmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(vmi)
	# A ring of tall mushrooms inside makes the hollow feel like a room.
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for i in 9:
		var a := TAU * i / 9.0
		var p := MushroomGenerator.random_params(rng, region.biome, "twisted")
		p.glow_color = Color("#8dff5a")
		mushroom_from_params(region, p, xz + Vector2(cos(a), sin(a)) * 11.0, rng.randf() * TAU)
	glow_light(root, Vector3(0, 3, 0), Color(0.55, 1.0, 0.4), 2.0, 16.0)
	var motes := SpellFX.ambient_motes(Color(0.6, 1.0, 0.4), 50, Vector3(8, 3, 8), 0.12)
	motes.position = Vector3(0, 2, 0)
	root.add_child(motes)
	return root


# ------------------------------------------------------------------ Floating islands
static func floating_island(region: Region, pos: Vector3, radius: float, depth: float, opts: Dictionary = {}) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pos.x * 31.0 + pos.z * 17.0 + pos.y)
	var isl := IslandGenerator.build(rng, region.biome, radius, depth, opts)
	var holder := Node3D.new()
	holder.position = pos
	region.add_child(holder)
	var mi := MeshInstance3D.new()
	mi.mesh = isl["mesh"]
	# Sky props don't cast shadows: they are far above and costly on mobile.
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if not bool(opts.get("walkable", false)) else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	holder.add_child(mi)
	if isl.has("waterfall_mesh"):
		var wf := MeshInstance3D.new()
		wf.mesh = isl["waterfall_mesh"]
		wf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(wf)
		var mist := SpellFX.ambient_motes(Color(0.6, 1.0, 1.0), 30, Vector3(2, 1, 2), 0.3)
		mist.position = isl["waterfall_bottom"]
		holder.add_child(mist)
	if bool(opts.get("walkable", false)):
		var body := StaticBody3D.new()
		body.collision_layer = 1
		Props.add_cylinder(body, Vector3(0, -0.6, 0), radius * 0.92, 1.4)
		holder.add_child(body)
	# A few mushrooms on top.
	var mk := MeshKit.new()
	for i in int(opts.get("mushrooms", 4)):
		var p := MushroomGenerator.random_params(rng, region.biome, "medium" if i < 2 else "small")
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.0, radius * 0.6)
		MushroomGenerator.build_into(mk, p, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(cos(a) * d, 0.1, sin(a) * d)))
	if mk.vertex_count() > 0:
		var mmi := MeshInstance3D.new()
		mmi.mesh = mk.commit(MaterialLib.mushroom())
		mmi.cast_shadow = mi.cast_shadow
		holder.add_child(mmi)
	if bool(opts.get("drift", true)):
		var fb := FloatBob.new()
		fb.amplitude = float(opts.get("bob", 0.6))
		fb.orbit = float(opts.get("orbit", 0.0))
		holder.add_child(fb)
	return holder


# ------------------------------------------------------------------ Village
static func distant_village(region: Region, center: Vector2) -> Node3D:
	var root := Node3D.new()
	root.name = "Sporehaven"
	region.add_child(root)
	root.position = Vector3(center.x, 0, center.y)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1999
	var kit := MeshKit.new()
	var wk := MeshKit.new()
	for i in 11:
		var p := MushroomGenerator.random_params(rng, region.biome, "giant")
		var s := rng.randf_range(2.2, 4.2)
		p.stem_height *= s
		p.stem_width *= s * 0.8
		p.cap_radius *= s * 0.55
		p.cap_height *= s * 0.6
		p.cap_segments = 20
		p.spots = 6
		var pos := Vector3(rng.randf_range(-110, 110), -10.0, rng.randf_range(-40, 40))
		var info := MushroomGenerator.build_into(kit, p, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), pos))
		# Glowing windows climbing each tower.
		var path: PackedVector3Array = info["stem_path"]
		for w in 10:
			var t := rng.randf_range(0.15, 0.9)
			var c := path[int(t * (path.size() - 1))]
			var a := rng.randf() * TAU
			var r := p.stem_width * 1.1
			var wp := c + Vector3(cos(a) * r, 0, sin(a) * r)
			wk.ellipsoid(wp, Vector3(1.3, 1.6, 1.3), Color(1.0, 0.75, 0.35, 1.0), 4, 6)
	var vmi := MeshInstance3D.new()
	vmi.mesh = kit.commit(MaterialLib.mushroom())
	vmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(vmi)
	var wmi := MeshInstance3D.new()
	wmi.mesh = wk.commit(MaterialLib.organic("village_windows", {"emission": 6.0, "pulse": 0.2}))
	wmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(wmi)
	return root


# ------------------------------------------------------------------ dark fantasy
## Crookhollow: a huddle of leaning, half-timbered witch houses around a
## little cobbled square with a bubbling cauldron.
static func crookhollow(region: Region, center: Vector2, count: int = 7, ring: float = 12.0) -> Node3D:
	var root := Node3D.new()
	root.name = "Crookhollow"
	region.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 6661
	var walls := MeshKit.new()
	var roofs := MeshKit.new()
	var glow := MeshKit.new()
	var body := StaticBody3D.new()
	body.name = "HouseColliders"
	root.add_child(body)
	var c3 := Vector3(center.x, 0, center.y)
	for i in count:
		# Leave a gap in the ring towards the east, where the path comes in.
		var a := lerpf(0.55, TAU - 0.55, float(i) / (count - 1)) + rng.randf_range(-0.12, 0.12)
		var r := ring + rng.randf_range(-1.5, 2.5)
		var pos := c3 + Vector3(cos(a), 0, sin(a)) * r
		pos.y = region.ground(pos.x, pos.z)
		# Door faces the square (local -Z side 0 faces ... the generator's +Z), with a crooked twist.
		var to_center := (c3 - pos)
		var yaw := atan2(to_center.x, to_center.z) + rng.randf_range(-0.3, 0.3)
		var xf := Transform3D(Basis(Vector3.UP, yaw).rotated(Vector3(1, 0, 0).rotated(Vector3.UP, yaw), rng.randf_range(-0.04, 0.04)), pos)
		var h := CrookedArchitecture.crooked_house(rng, xf)
		walls.merge(h["walls"], Transform3D.IDENTITY)
		roofs.merge(h["roof"], Transform3D.IDENTITY)
		glow.merge(h["glow"], Transform3D.IDENTITY)
		var sz: Vector3 = h["size"]
		Props.add_box(body, pos + Vector3.UP * sz.y * 0.5, sz * Vector3(0.95, 1.0, 0.95), Basis(Vector3.UP, yaw))
		if i % 2 == 0:
			var smoke := SpellFX.ambient_motes(Color(0.45, 1.0, 0.55), 10, Vector3(0.6, 3.0, 0.6), 0.25)
			smoke.position = h["chimney"]
			root.add_child(smoke)
	_commit(root, walls, MaterialLib.organic("crook_walls", {"emission": 0.35, "pulse": 0.0, "rim": Color(0.35, 0.3, 0.8), "rim_strength": 0.25, "roughness": 0.95}), true)
	_commit(root, roofs, MaterialLib.organic("crook_roofs", {"emission": 0.55, "pulse": 0.15, "rim": Color(0.3, 0.5, 1.0), "rim_strength": 0.5, "roughness": 0.7}), true)
	_commit(root, glow, MaterialLib.organic("crook_windows", {"emission": 5.0, "pulse": 0.25, "pulse_speed": 2.3}), false)
	# The cauldron in the middle of the square.
	var cpos := Vector3(c3.x, region.ground(c3.x, c3.z), c3.z)
	var ck := MeshKit.new()
	ck.ellipsoid(cpos + Vector3.UP * 0.75, Vector3(1.0, 0.8, 1.0), Color("#0d0a12"), 8, 12)
	var brew := MeshKit.new()
	brew.ellipsoid(cpos + Vector3.UP * 1.45, Vector3(0.85, 0.12, 0.85), Color("#6dff7a"), 4, 12)
	for k in 3:
		var la := TAU * k / 3.0
		ck.tube(PackedVector3Array([cpos + Vector3(cos(la) * 0.7, 0.4, sin(la) * 0.7), cpos + Vector3(cos(la) * 1.0, -0.1, sin(la) * 1.0)]), PackedFloat32Array([0.08, 0.06]), 4, func(_t: float) -> Color: return Color("#0d0a12"), false, true)
	_commit(root, ck, MaterialLib.stone(), true)
	_commit(root, brew, MaterialLib.organic("cauldron_brew", {"emission": 4.0, "pulse": 0.6, "pulse_speed": 3.0}), false)
	Props.add_cylinder(body, cpos + Vector3.UP * 0.7, 1.0, 1.4)
	var bubbles := SpellFX.ambient_motes(Color(0.5, 1.0, 0.45), 18, Vector3(0.7, 1.2, 0.7), 0.12)
	bubbles.position = cpos + Vector3.UP * 1.9
	root.add_child(bubbles)
	glow_light(root, cpos + Vector3.UP * 2.0, Color(0.45, 1.0, 0.5), 2.2, 9.0)
	return root


static func _commit(parent: Node3D, kit: MeshKit, mat: Material, shadows: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = kit.commit(mat)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## The dark castle on the far side of the north pass — always visible, never reachable (yet).
static func dark_castle(region: Region, center: Vector2) -> Node3D:
	var root := Node3D.new()
	root.name = "Nightspire"
	region.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1313
	var k := CrookedArchitecture.dark_castle(rng, Vector3(center.x, -4.0, center.y), 1.35)
	_commit(root, k["stone"], MaterialLib.organic("castle_stone", {"emission": 0.4, "pulse": 0.0, "rim": Color(0.3, 0.3, 0.9), "rim_strength": 0.6, "roughness": 0.95}), false)
	_commit(root, k["roof"], MaterialLib.organic("castle_roof", {"emission": 1.0, "pulse": 0.2, "rim": Color(0.3, 0.5, 1.0), "rim_strength": 0.6}), false)
	_commit(root, k["glow"], MaterialLib.organic("castle_windows", {"emission": 7.0, "pulse": 0.3, "pulse_speed": 0.7}), false)
	return root


## Bent iron lantern posts along a polyline. Lights only on every second post
## and only above low quality.
static func lantern_row(region: Region, points: PackedVector2Array, spacing: float, offset: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Lanterns"
	region.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 404 + points.size()
	var iron := MeshKit.new()
	var glow := MeshKit.new()
	var carry := spacing * 0.5
	var n := 0
	var lights := Settings.quality != Settings.Quality.LOW
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var seg := a.distance_to(b)
		var dir := (b - a) / seg
		var t := carry
		while t < seg:
			var p := a + dir * t
			var side := 1.0 if n % 2 == 0 else -1.0
			var perp := Vector2(-dir.y, dir.x) * side
			var foot2 := p + perp * offset
			var foot := Vector3(foot2.x, region.ground(foot2.x, foot2.y), foot2.y)
			var post := CrookedArchitecture.lantern_post(rng, foot, Vector3(-perp.x, 0, -perp.y))
			iron.merge(post["iron"], Transform3D.IDENTITY)
			glow.merge(post["glow"], Transform3D.IDENTITY)
			if lights and n % 2 == 0:
				glow_light(root, post["lamp"], Color(1.0, 0.66, 0.3), 1.3, 7.0)
			n += 1
			t += spacing
		carry = t - seg
	_commit(root, iron, MaterialLib.organic("lantern_iron", {"emission": 0.0, "pulse": 0.0, "rim_strength": 0.3}), false)
	_commit(root, glow, MaterialLib.organic("lantern_glow", {"emission": 6.0, "pulse": 0.3, "pulse_speed": 4.0}), false)
	return root
