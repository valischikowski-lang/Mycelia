class_name SpellVFX
extends RefCounted
## Spell visuals for the combat arena. Every function is awaitable and
## built from animated geometry + CPU particles so each discipline has its
## own readable visual language on small screens.

static var _mesh_cache: Dictionary = {}


static func _cached(key: String, builder: Callable) -> Mesh:
	if not _mesh_cache.has(key):
		_mesh_cache[key] = builder.call()
	return _mesh_cache[key]


static func _tween(node: Node) -> Tween:
	return node.create_tween()


static func _mi(parent: Node3D, mesh: Mesh, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos
	return mi


static func _flash_light(parent: Node3D, pos: Vector3, color: Color, energy: float = 6.0, light_range: float = 8.0, time: float = 0.45) -> void:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = light_range
	l.shadow_enabled = false
	parent.add_child(l)
	l.global_position = pos
	var tw := _tween(l)
	tw.tween_property(l, "light_energy", 0.0, time)
	tw.tween_callback(l.queue_free)


## Anticipation: a glowing ring and gathering motes at the caster.
static func charge_up(parent: Node3D, at: Vector3, color: Color, time: float = 0.35) -> void:
	var ring := _mi(parent, _cached("ring", func() -> Mesh:
		var t := TorusMesh.new()
		t.inner_radius = 0.9
		t.outer_radius = 1.0
		t.rings = 24
		t.ring_segments = 6
		return t), at + Vector3.UP * 0.1)
	ring.material_override = MaterialLib.glow_unique(color, 2.5)
	ring.scale = Vector3.ONE * 0.2
	var p := SpellFX.make_particles(color, 30, 0.6, 0.14)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 1.4
	p.radial_accel_min = -8.0
	p.radial_accel_max = -6.0
	p.gravity = Vector3.ZERO
	p.one_shot = true
	p.explosiveness = 0.3
	parent.add_child(p)
	p.global_position = at + Vector3.UP * 1.2
	p.emitting = true
	p.finished.connect(p.queue_free)
	_flash_light(parent, at + Vector3.UP * 1.2, color, 3.0, 6.0, time + 0.2)
	var tw := _tween(ring)
	tw.tween_property(ring, "scale", Vector3.ONE * 1.6, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ring, "rotation:y", PI, time)
	tw.tween_callback(ring.queue_free)
	await tw.finished


## Moves `node` along an arc from a to b.
static func _fly(node: Node3D, a: Vector3, b: Vector3, time: float, arc: float) -> void:
	var tw := _tween(node)
	tw.tween_method(func(t: float) -> void:
		if is_instance_valid(node):
			node.global_position = a.lerp(b, t) + Vector3.UP * sin(t * PI) * arc
			node.rotation.y += 0.3
			node.rotation.x += 0.2, 0.0, 1.0, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw.finished


static func _trail(node: Node3D, color: Color, amount: int = 40, size: float = 0.16) -> CPUParticles3D:
	var p := SpellFX.make_particles(color, amount, 0.6, size)
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.8
	p.gravity = Vector3(0, 0.3, 0)
	p.emitting = true
	node.add_child(p)
	return p


# ------------------------------------------------------------------ projectiles
static func projectile(parent: Node3D, style: String, from: Vector3, to: Vector3, color: Color) -> void:
	var node := Node3D.new()
	parent.add_child(node)
	node.global_position = from
	var arc := 1.5
	var time := 0.55
	match style:
		"fungal_spore":
			var kit := MeshKit.new()
			kit.ellipsoid(Vector3.ZERO, Vector3.ONE * 0.35, Color(0.85, 0.35, 1.0, 0.4), 7, 10)
			for i in 6:
				var d := Vector3(sin(i * 2.1), cos(i * 1.3), sin(i * 0.7)).normalized()
				kit.ellipsoid(d * 0.33, Vector3.ONE * 0.07, Color(1.0, 0.95, 0.4, 1.0), 3, 6)
			var mi := MeshInstance3D.new()
			mi.mesh = kit.commit(MaterialLib.creature())
			node.add_child(mi)
			_trail(node, Color(0.8, 0.4, 1.0), 50, 0.2)
			arc = 2.2
		"nature_thorn":
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 0.15
			cone.height = 0.9
			var mi2 := MeshInstance3D.new()
			mi2.mesh = cone
			mi2.material_override = MaterialLib.glow(Color(0.5, 1.0, 0.3), 2.0, false)
			mi2.rotation.x = -PI * 0.5
			node.add_child(mi2)
			node.look_at_from_position(from, to, Vector3.UP)
			_trail(node, Color(0.5, 1.0, 0.4), 40, 0.12)
			arc = 0.4
			time = 0.35
		"crystal_shards":
			await crystal_fan(parent, from, to, color)
			node.queue_free()
			return
		_:
			var s := SphereMesh.new()
			s.radius = 0.3
			s.height = 0.6
			var mi3 := MeshInstance3D.new()
			mi3.mesh = s
			mi3.material_override = MaterialLib.glow(color, 3.0, false)
			node.add_child(mi3)
			_trail(node, color, 40)
	await _fly(node, from, to, time, arc)
	node.queue_free()


static func crystal_fan(parent: Node3D, from: Vector3, to: Vector3, color: Color) -> void:
	var shards: Array[Node3D] = []
	var mesh := _cached("shard", func() -> Mesh:
		var k := MeshKit.new()
		k.crystal_prism(Vector3(0, -0.5, 0), Basis.IDENTITY, 1.0, 0.09, 5, Color(0.5, 1.0, 1.0), 0.4)
		return k.commit(MaterialLib.crystal(2.6)))
	for i in 5:
		var s := Node3D.new()
		parent.add_child(s)
		s.global_position = from
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.rotation.x = -PI * 0.5
		s.add_child(mi)
		shards.append(s)
	var dir := (to - from)
	var side := Vector3(-dir.z, 0, dir.x).normalized()
	var tw := parent.create_tween().set_parallel(true)
	for i in shards.size():
		var s := shards[i]
		var spread := (i - 2) * 0.9
		var mid := from.lerp(to, 0.45) + side * spread + Vector3.UP * (1.2 + absf(spread) * 0.3)
		tw.tween_method(func(t: float) -> void:
			if is_instance_valid(s):
				var p := from.lerp(mid, t).lerp(mid.lerp(to, t), t)
				s.look_at_from_position(p, p + (mid.lerp(to, t) - from.lerp(mid, t)), Vector3.UP), 0.0, 1.0, 0.45 + i * 0.04)
	await tw.finished
	for s in shards:
		s.queue_free()


# ------------------------------------------------------------------ impacts
static func impact(parent: Node3D, style: String, at: Vector3, color: Color, big: bool = false) -> void:
	_flash_light(parent, at + Vector3.UP, color, 8.0 if big else 5.0, 9.0)
	SpellFX.burst(parent, at + Vector3.UP * 0.9, color, 60 if big else 35, 6.0 if big else 4.5, 0.22, -3.0)
	match style:
		"fungal_spore", "fungal_eruption":
			await mushroom_eruption(parent, at, 5 if big else 3)
		"crystal_shards":
			SpellFX.burst(parent, at + Vector3.UP, Color(0.7, 1.0, 1.0), 40, 9.0, 0.12, -8.0)
		"nature_vines":
			await vines(parent, at, color)
		"nature_bloom":
			await bloom(parent, at)
		"cosmic_star":
			await shockwave(parent, at, color, 4.5)
		"chaos_rift":
			await chaos_shapes(parent, at)
		_:
			await shockwave(parent, at, color, 2.0)


static func shockwave(parent: Node3D, at: Vector3, color: Color, radius: float) -> void:
	var ring := _mi(parent, _cached("wave", func() -> Mesh:
		var t := TorusMesh.new()
		t.inner_radius = 0.92
		t.outer_radius = 1.0
		t.rings = 32
		t.ring_segments = 4
		return t), at + Vector3.UP * 0.15)
	var mat := MaterialLib.glow_unique(color, 3.0)
	ring.material_override = mat
	ring.scale = Vector3(0.2, 0.3, 0.2)
	var tw := _tween(ring)
	tw.tween_property(ring, "scale", Vector3(radius, 0.5, radius), 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_method(func(v: float) -> void: mat.set_shader_parameter("intensity", v), 3.0, 0.0, 0.4)
	tw.tween_callback(ring.queue_free)
	await tw.finished


static func mushroom_eruption(parent: Node3D, at: Vector3, count: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(at.x * 100.0 + at.z * 31.0) + Time.get_ticks_msec()
	var biome: BiomeData = Database.biome("dreaming_meadow")
	var nodes: Array[Node3D] = []
	var tw := parent.create_tween().set_parallel(true)
	for i in count:
		var p := MushroomGenerator.random_params(rng, biome, "medium")
		p.stem_height *= 0.6
		p.cap_radius *= 0.6
		p.cap_height *= 0.6
		p.stem_width *= 0.6
		p.emission_intensity = 1.0
		var mi := _mi(parent, MushroomGenerator.build(p)["mesh"], at + Vector3(cos(i * 2.4) * 1.1, -0.1, sin(i * 2.4) * 1.1))
		mi.scale = Vector3(0.05, 0.05, 0.05)
		nodes.append(mi)
		tw.tween_property(mi, "scale", Vector3.ONE, 0.25 + i * 0.04).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished
	var tw2 := parent.create_tween().set_parallel(true)
	for n in nodes:
		tw2.tween_property(n, "scale", Vector3(1.3, 0.01, 1.3), 0.35).set_delay(0.25)
	await tw2.finished
	for n in nodes:
		n.queue_free()


static func vines(parent: Node3D, at: Vector3, color: Color) -> void:
	var holder := Node3D.new()
	parent.add_child(holder)
	holder.global_position = at
	var kit := MeshKit.new()
	for v in 5:
		var a := TAU * v / 5.0
		var pts := PackedVector3Array()
		var radii := PackedFloat32Array()
		for k in 12:
			var t := float(k) / 11.0
			var ang := a + t * TAU * 1.2
			pts.append(Vector3(cos(ang) * (0.9 - t * 0.3), t * 2.6, sin(ang) * (0.9 - t * 0.3)))
			radii.append(0.1 * (1.0 - t * 0.7))
		kit.tube(pts, radii, 5, func(t: float) -> Color: return Color(0.3, 0.8, 0.3).lerp(Color(0.6, 1.0, 0.4), t) * Color(1, 1, 1, 0.3 + t * 0.7), false, true)
	var mi := MeshInstance3D.new()
	mi.mesh = kit.commit(MaterialLib.plant())
	holder.add_child(mi)
	holder.scale = Vector3(1, 0.01, 1)
	var tw := _tween(holder)
	tw.tween_property(holder, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.4)
	tw.tween_property(holder, "scale", Vector3(1, 0.01, 1), 0.3)
	tw.tween_callback(holder.queue_free)
	await tw.finished


static func bloom(parent: Node3D, at: Vector3) -> void:
	var biome: BiomeData = Database.biome("dreaming_meadow")
	var rng := RandomNumberGenerator.new()
	rng.seed = Time.get_ticks_msec()
	var f := FlowerGenerator.build(rng, biome, 0.4, 1.6)
	parent.add_child(f)
	f.global_position = at
	f.scale = Vector3.ONE * 0.05
	SpellFX.burst(parent, at + Vector3.UP * 1.0, Color(1.0, 0.5, 0.8), 60, 5.0, 0.2, 1.0)
	var tw := _tween(f)
	tw.tween_property(f, "scale", Vector3.ONE * 1.2, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.5)
	tw.tween_property(f, "scale", Vector3.ONE * 0.01, 0.3)
	tw.tween_callback(f.queue_free)
	await tw.finished


static func chaos_shapes(parent: Node3D, at: Vector3) -> void:
	var nodes: Array[MeshInstance3D] = []
	var meshes: Array[Mesh] = [BoxMesh.new(), PrismMesh.new(), SphereMesh.new(), TorusMesh.new()]
	var tw := parent.create_tween().set_parallel(true)
	for i in 7:
		var mi := _mi(parent, meshes[i % meshes.size()], at + Vector3.UP * 1.2)
		mi.material_override = MaterialLib.glow_unique(Color.from_hsv(randf(), 0.8, 1.0), 2.5)
		mi.scale = Vector3.ONE * 0.05
		nodes.append(mi)
		var dest := at + Vector3(randf_range(-2, 2), randf_range(0.5, 3.0), randf_range(-2, 2))
		tw.tween_property(mi, "global_position", dest, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(mi, "scale", Vector3.ONE * randf_range(0.3, 0.7), 0.5)
		tw.tween_property(mi, "rotation", Vector3(randf() * 6, randf() * 6, randf() * 6), 0.7)
	await tw.finished
	var tw2 := parent.create_tween().set_parallel(true)
	for mi in nodes:
		tw2.tween_property(mi, "scale", Vector3.ONE * 0.01, 0.3)
	await tw2.finished
	for mi in nodes:
		mi.queue_free()


# ------------------------------------------------------------------ special casts
static func falling_star(parent: Node3D, at: Vector3, color: Color) -> void:
	var star := Node3D.new()
	parent.add_child(star)
	var kit := MeshKit.new()
	for i in 5:
		var b := Basis(Vector3.FORWARD, TAU * i / 5.0)
		kit.crystal_prism(Vector3.ZERO, b, 1.1, 0.25, 4, Color(1.0, 0.9, 0.4), 0.6)
	var mi := MeshInstance3D.new()
	mi.mesh = kit.commit(MaterialLib.crystal(3.0))
	star.add_child(mi)
	_trail(star, Color(1.0, 0.85, 0.3), 80, 0.3)
	var start := at + Vector3(4, 16, -4)
	star.global_position = start
	var tw := _tween(star)
	tw.tween_property(star, "global_position", at + Vector3.UP * 0.6, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(star, "rotation:z", TAU * 2.0, 0.6)
	await tw.finished
	star.queue_free()


static func gravity_well(parent: Node3D, center: Vector3, targets: Array[Node3D], color: Color) -> void:
	var orb := _mi(parent, _cached("orb", func() -> Mesh:
		var s := SphereMesh.new()
		s.radius = 0.6
		s.height = 1.2
		return s), center + Vector3.UP * 2.5)
	orb.material_override = MaterialLib.glow_unique(Color(0.4, 0.2, 0.9), 2.0, false, true)
	orb.scale = Vector3.ONE * 0.1
	var tw := _tween(orb)
	tw.tween_property(orb, "scale", Vector3.ONE * 1.5, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for t: Node3D in targets:
		var base_y := t.position.y
		tw.parallel().tween_property(t, "position:y", base_y + 0.8, 0.4)
	await tw.finished
	shockwave(parent, center, color, 6.0)
	var tw2 := _tween(orb)
	tw2.tween_property(orb, "scale", Vector3.ONE * 0.05, 0.3)
	for t: Node3D in targets:
		tw2.parallel().tween_property(t, "position:y", t.position.y - 0.8, 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw2.tween_callback(orb.queue_free)
	await tw2.finished


static func heal_threads(parent: Node3D, at: Vector3, color: Color) -> void:
	var holder := Node3D.new()
	parent.add_child(holder)
	holder.global_position = at
	var kit := MeshKit.new()
	for v in 4:
		var pts := PackedVector3Array()
		var radii := PackedFloat32Array()
		for k in 14:
			var t := float(k) / 13.0
			var ang := TAU * v / 4.0 + t * TAU * 1.5
			pts.append(Vector3(cos(ang) * 0.9, t * 2.8, sin(ang) * 0.9))
			radii.append(0.04)
		kit.tube(pts, radii, 4, func(t: float) -> Color: return Color(color.r, color.g, color.b, 1.0), false, false)
	var mi := MeshInstance3D.new()
	mi.mesh = kit.commit(MaterialLib.organic("heal_threads", {"emission": 3.5, "pulse": 0.5, "pulse_speed": 6.0}))
	holder.add_child(mi)
	var p := SpellFX.make_particles(color, 40, 1.0, 0.16)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = 1.0
	p.emission_ring_inner_radius = 0.6
	p.emission_ring_height = 0.1
	p.direction = Vector3.UP
	p.spread = 10.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.0
	p.gravity = Vector3.ZERO
	p.one_shot = true
	p.explosiveness = 0.4
	holder.add_child(p)
	p.emitting = true
	holder.scale = Vector3(1, 0.01, 1)
	_flash_light(parent, at + Vector3.UP, color, 4.0, 6.0, 1.0)
	var tw := _tween(holder)
	tw.tween_property(holder, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(holder, "rotation:y", PI, 0.9)
	tw.tween_property(holder, "scale", Vector3(0.01, 1.2, 0.01), 0.35)
	tw.tween_callback(holder.queue_free)
	await tw.finished


static func shield_bubble(color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var kit := MeshKit.new()
	kit.ellipsoid(Vector3(0, 1.1, 0), Vector3(1.3, 1.5, 1.3), Color(color.r, color.g, color.b, 0.6), 6, 8)
	mi.mesh = kit.commit(MaterialLib.glow(color, 0.8, false, false))
	var m := MaterialLib.glow_unique(color, 0.6, false, true)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Full-screen chaos distortion pulse on a CanvasLayer.
static func screen_warp(host: Node, color: Color) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	host.add_child(layer)
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/chaos_warp.gdshader")
	mat.set_shader_parameter("strength", 0.0)
	mat.set_shader_parameter("tint", color)
	rect.material = mat
	layer.add_child(rect)
	var tw := host.create_tween()
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("strength", v), 0.0, 1.0, 0.2)
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("strength", v), 1.0, 0.0, 0.5)
	tw.tween_callback(layer.queue_free)
	await tw.finished
