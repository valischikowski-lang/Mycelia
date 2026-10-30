class_name CreatureBuilder
extends RefCounted
## Assembles creatures, NPCs and the combat avatar from procedural parts.
## Every result is a CreatureRig: root -> Body (animated) -> parts (+ Eyes).
## Kinds: sporeling, crystal_beetle, dream_fox, bloom_guardian, spore_golem,
## keeper, petalune, ollo, dreamer, sky_drifter.

const RIG_SCRIPT := preload("res://scripts/creatures/creature_rig.gd")


static func build(kind: String, tint: Color = Color.WHITE, opts: Dictionary = {}) -> CreatureRig:
	var rig := Node3D.new()
	rig.set_script(RIG_SCRIPT)
	var body := Node3D.new()
	body.name = "Body"
	rig.add_child(body)
	var biome: BiomeData = Database.biome("dreaming_meadow")
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind) + int(opts.get("seed", 0))
	match kind:
		"sporeling":
			_sporeling(body, rng, biome, tint)
		"crystal_beetle":
			_beetle(body, rng, biome)
			rig.set("idle_bob", 0.02)
			rig.set("squash", 0.02)
		"dream_fox":
			_fox(body, rng, biome)
			rig.set("idle_bob", 0.04)
		"bloom_guardian":
			_guardian(body, rng, biome)
			rig.set("idle_bob", 0.08)
			rig.set("idle_speed", 1.2)
		"spore_golem":
			_golem(body, rng, biome)
			rig.set("idle_bob", 0.06)
			rig.set("idle_speed", 0.9)
			rig.set("squash", 0.02)
		"keeper":
			_keeper(body, rng, biome)
			rig.set("idle_bob", 0.03)
			rig.set("idle_speed", 1.3)
			rig.set("squash", 0.015)
		"petalune":
			_petalune(body, rng, biome)
			rig.set("idle_bob", 0.05)
			rig.set("idle_speed", 1.0)
			rig.set("squash", 0.03)
		"ollo":
			_ollo(body, rng, biome)
			rig.set("idle_bob", 0.02)
			rig.set("idle_speed", 0.8)
		"dreamer":
			_dreamer(body, rng, biome, opts)
			rig.set("idle_bob", 0.04)
			rig.set("squash", 0.02)
		"sky_drifter":
			_drifter(body, rng, biome)
			rig.set("idle_bob", 0.3)
			rig.set("idle_speed", 0.8)
			rig.set("squash", 0.12)
		"witch":
			_witch(body, rng, opts)
			rig.set("idle_bob", 0.05)
			rig.set("idle_speed", 2.8)
			rig.set("squash", 0.04)
		"gremlin":
			_gremlin(body, rng)
			rig.set("idle_bob", 0.12)
			rig.set("idle_speed", 4.0)
			rig.set("squash", 0.08)
		_:
			_sporeling(body, rng, biome, tint)
	return rig as CreatureRig


# ---------------------------------------------------------------- helpers
static func _mesh(parent: Node3D, kit: MeshKit, mat: Material = null, shadows: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = kit.commit(mat if mat else MaterialLib.creature())
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func _glow(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, a)


## Adds a pair (or more) of cartoon eyes under an "Eyes" node.
static func _eyes(body: Node3D, centers: Array[Vector3], size: float, iris: Color, look: Vector3 = Vector3(0, 0, 1), hollow: bool = false) -> void:
	var eyes := Node3D.new()
	eyes.name = "Eyes"
	body.add_child(eyes)
	var kit := MeshKit.new()
	for c: Vector3 in centers:
		if hollow:
			kit.ellipsoid(c, Vector3(size, size * 1.1, size * 0.6), Color(0.05, 0.0, 0.08, 0.0), 6, 10)
			kit.ellipsoid(c + look * size * 0.45, Vector3.ONE * size * 0.25, _glow(Color(1.0, 0.2, 0.7), 1.0), 4, 8)
		else:
			kit.ellipsoid(c, Vector3(size, size * 1.15, size * 0.75), Color(0.97, 0.95, 1.0, 0.15), 7, 12)
			kit.ellipsoid(c + look * size * 0.55, Vector3(size * 0.55, size * 0.62, size * 0.35), _glow(iris, 0.6), 5, 10)
			kit.ellipsoid(c + look * size * 0.8, Vector3(size * 0.28, size * 0.32, size * 0.15), Color(0.02, 0.0, 0.05, 0.0), 4, 8)
			kit.ellipsoid(c + look * size * 0.85 + Vector3(size * 0.2, size * 0.25, 0), Vector3.ONE * size * 0.12, Color(1, 1, 1, 1.0), 3, 6)
	_mesh(eyes, kit, null, false)


static func _legs(kit: MeshKit, anchors: Array[Vector3], length: float, radius: float, color: Color, spread: float = 1.0) -> void:
	for a: Vector3 in anchors:
		var out := Vector3(a.x, 0, a.z).normalized() * spread
		var pts := PackedVector3Array([a, a + out * length * 0.5 + Vector3.UP * length * 0.25, a + out * length * 0.8 + Vector3.DOWN * (a.y)])
		var rad := PackedFloat32Array([radius, radius * 0.8, radius * 0.5, radius * 0.4, radius * 0.4, radius * 0.3, radius * 0.3])
		var path := MeshKit.spline(pts, 3)
		kit.tube(path, _fit(rad, path.size()), 5, func(_t: float) -> Color: return color, false, true)


static func _fit(values: PackedFloat32Array, count: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for i in count:
		var t := float(i) / maxf(1.0, count - 1) * (values.size() - 1)
		var a := int(floor(t))
		var b := mini(a + 1, values.size() - 1)
		out.append(lerpf(values[a], values[b], t - a))
	return out


# ---------------------------------------------------------------- creatures
static func _sporeling(body: Node3D, rng: RandomNumberGenerator, biome: BiomeData, tint: Color) -> void:
	var hollow := tint.s < 0.3 and tint.v < 0.8
	var kit := MeshKit.new()
	var skin := Color(0.93, 0.86, 1.0) * tint
	kit.ellipsoid(Vector3(0, 0.38, 0), Vector3(0.34, 0.36, 0.32), skin, 9, 14, Basis.IDENTITY, null, 0.0,
		func(d: Vector3) -> Color:
			var c := skin.lerp(skin.darkened(0.25), clampf(-d.y, 0.0, 1.0))
			c.a = 0.05
			return c)
	# Feet.
	kit.ellipsoid(Vector3(-0.15, 0.06, 0.05), Vector3(0.11, 0.07, 0.15), skin.darkened(0.2), 5, 8)
	kit.ellipsoid(Vector3(0.15, 0.06, 0.05), Vector3(0.11, 0.07, 0.15), skin.darkened(0.2), 5, 8)
	# Tiny arms.
	kit.ellipsoid(Vector3(-0.34, 0.36, 0.05), Vector3(0.06, 0.12, 0.06), skin, 4, 6, Basis(Vector3.FORWARD, 0.5))
	kit.ellipsoid(Vector3(0.34, 0.36, 0.05), Vector3(0.06, 0.12, 0.06), skin, 4, 6, Basis(Vector3.FORWARD, -0.5))
	_mesh(body, kit)
	# Cap: a little mushroom on its head.
	var p := MushroomParams.new()
	p.seed = rng.randi()
	p.cap_shape = MushroomParams.CapShape.DOME
	p.stem_height = 0.05
	p.stem_width = 0.12
	p.cap_radius = 0.48
	p.cap_height = 0.34
	p.cap_curvature = 0.6
	p.cap_asymmetry = 0.12
	p.stem_bend = 0.0
	p.cap_segments = 16
	p.cap_color = (Color(0.45, 0.42, 0.5) if hollow else Color(0.85, 0.2, 0.75)) * Color(tint, 1.0)
	p.cap_top_color = (Color(0.3, 0.28, 0.35) if hollow else Color(1.0, 0.45, 0.85))
	p.glow_color = Color(1.0, 0.25, 0.7) if hollow else Color(0.3, 1.0, 0.95)
	p.spot_color = Color(0.2, 0.2, 0.25) if hollow else Color(1.0, 0.92, 0.4)
	p.spots = 5
	p.emission_intensity = 0.9
	var info := MushroomGenerator.build(p, MaterialLib.creature())
	var cap := MeshInstance3D.new()
	cap.mesh = info["mesh"]
	cap.position = Vector3(0, 0.62, -0.02)
	cap.rotation.x = -0.15
	body.add_child(cap)
	_eyes(body, [Vector3(-0.13, 0.42, 0.26), Vector3(0.13, 0.42, 0.26)] as Array[Vector3], 0.095, Color(0.2, 0.8, 1.0), Vector3(0, 0, 1), hollow)


static func _beetle(body: Node3D, rng: RandomNumberGenerator, biome: BiomeData) -> void:
	var kit := MeshKit.new()
	var shell := Color(0.12, 0.2, 0.55)
	kit.ellipsoid(Vector3(0, 0.55, -0.15), Vector3(0.75, 0.42, 0.95), shell, 8, 14, Basis.IDENTITY, null, 0.0,
		func(d: Vector3) -> Color:
			var c := shell.lerp(Color(0.25, 0.6, 1.0), clampf(d.y, 0.0, 1.0) * 0.6)
			c.a = 0.08 + (0.6 if absf(d.x) < 0.06 and d.y > 0.2 else 0.0)
			return c)
	kit.ellipsoid(Vector3(0, 0.5, 0.75), Vector3(0.38, 0.3, 0.32), shell.darkened(0.2), 6, 10)
	var legs: Array[Vector3] = []
	for i in 3:
		var z := -0.5 + i * 0.45
		legs.append(Vector3(0.55, 0.4, z))
		legs.append(Vector3(-0.55, 0.4, z))
	_legs(kit, legs, 0.75, 0.06, Color(0.08, 0.1, 0.3, 0.05))
	_mesh(body, kit)
	# Crystal spikes along the back + mandibles.
	var ck := MeshKit.new()
	for i in 7:
		var z := -0.8 + i * 0.22
		var side := (i % 2) * 2 - 1
		var b := CrystalGenerator._basis_up(Vector3(side * 0.3, 1, -0.2).normalized(), rng.randf() * TAU)
		ck.crystal_prism(Vector3(side * 0.18, 0.9, z), b, rng.randf_range(0.35, 0.65), 0.08, 6, biome.pick(biome.crystal_colors, rng, Color(0.3, 0.9, 1.0)))
	for s: float in [-1.0, 1.0]:
		var mb := CrystalGenerator._basis_up(Vector3(s * 0.4, -0.1, 1).normalized(), 0.0)
		ck.crystal_prism(Vector3(s * 0.15, 0.45, 1.0), mb, 0.35, 0.05, 4, Color(0.6, 0.95, 1.0))
	_mesh(body, ck, MaterialLib.crystal(1.8))
	_eyes(body, [Vector3(-0.17, 0.6, 1.0), Vector3(0.17, 0.6, 1.0)] as Array[Vector3], 0.07, Color(0.3, 1.0, 1.0))


static func _fox(body: Node3D, rng: RandomNumberGenerator, biome: BiomeData) -> void:
	var kit := MeshKit.new()
	var fur := Color(0.55, 0.5, 1.0)
	var belly := Color(0.85, 0.85, 1.0)
	kit.ellipsoid(Vector3(0, 0.75, 0), Vector3(0.32, 0.32, 0.75), fur, 8, 12, Basis.IDENTITY, null, 0.0,
		func(d: Vector3) -> Color:
			var c := fur.lerp(belly, clampf(-d.y * 1.5, 0.0, 1.0))
			c.a = 0.18 + 0.5 * pow(maxf(0.0, d.y), 4.0)
			return c)
	# Head with snout.
	kit.ellipsoid(Vector3(0, 1.12, 0.72), Vector3(0.3, 0.27, 0.3), fur, 8, 12)
	kit.ellipsoid(Vector3(0, 1.04, 1.0), Vector3(0.12, 0.1, 0.2), belly, 5, 8)
	kit.ellipsoid(Vector3(0, 1.08, 1.18), Vector3.ONE * 0.045, Color(0.1, 0.05, 0.2, 0.0), 4, 6)
	_legs(kit, [Vector3(0.18, 0.6, 0.45), Vector3(-0.18, 0.6, 0.45), Vector3(0.18, 0.6, -0.45), Vector3(-0.18, 0.6, -0.45)] as Array[Vector3], 0.7, 0.07, fur.darkened(0.2), 0.25)
	# Tail: big curling star-tail.
	var tp := PackedVector3Array()
	var tr := PackedFloat32Array()
	for i in 10:
		var t := float(i) / 9.0
		tp.append(Vector3(sin(t * 3.0) * 0.4 * t, 0.85 + t * 0.9 - t * t * 0.4, -0.7 - t * 0.9))
		tr.append(0.12 + sin(t * PI) * 0.16)
	kit.tube(tp, tr, 8, func(t: float) -> Color:
		var c := fur.lerp(Color(1.0, 0.95, 0.6), t)
		c.a = t * t
		return c, true, true)
	_mesh(body, kit)
	# Ears.
	var ek := MeshKit.new()
	for s: float in [-1.0, 1.0]:
		var b := CrystalGenerator._basis_up(Vector3(s * 0.35, 1, 0.1).normalized(), 0.0)
		ek.crystal_prism(Vector3(s * 0.14, 1.3, 0.66), b, 0.5, 0.12, 4, Color(0.7, 0.6, 1.0), 0.6)
	_mesh(body, ek, MaterialLib.crystal(1.2))
	_eyes(body, [Vector3(-0.12, 1.18, 0.95), Vector3(0.12, 1.18, 0.95)] as Array[Vector3], 0.065, Color(1.0, 0.85, 0.3))
	var stars := SpellFX.ambient_motes(Color(1.0, 0.9, 0.5), 18, Vector3(0.3, 0.4, 0.5), 0.07)
	stars.position = Vector3(0, 1.4, -1.4)
	stars.local_coords = false
	body.add_child(stars)


static func _guardian(body: Node3D, rng: RandomNumberGenerator, biome: BiomeData) -> void:
	var kit := MeshKit.new()
	var stem := Color(0.18, 0.55, 0.35)
	var path := PackedVector3Array()
	var rad := PackedFloat32Array()
	for i in 9:
		var t := float(i) / 8.0
		path.append(Vector3(sin(t * 2.5) * 0.25, t * 2.6, 0))
		rad.append(0.32 * (1.0 - t * 0.45) + 0.15 * exp(-t * 6.0))
	kit.tube(path, rad, 9, func(t: float) -> Color:
		var c := stem.lerp(Color(0.35, 0.9, 0.55), t)
		c.a = 0.05
		return c, true, false)
	# Root feet.
	for i in 5:
		var a := TAU * i / 5.0
		var rp := PackedVector3Array([Vector3(0, 0.3, 0), Vector3(cos(a) * 0.5, 0.12, sin(a) * 0.5), Vector3(cos(a) * 0.9, 0.0, sin(a) * 0.9)])
		kit.tube(MeshKit.spline(rp, 3), _fit(PackedFloat32Array([0.14, 0.08, 0.03]), 7), 5, func(_t: float) -> Color: return stem.darkened(0.3), false, true)
	# Leaf arms.
	for s: float in [-1.0, 1.0]:
		var ap := PackedVector3Array([Vector3(0, 1.4, 0), Vector3(s * 0.7, 1.7, 0.2), Vector3(s * 1.3, 1.5, 0.5)])
		kit.tube(MeshKit.spline(ap, 3), _fit(PackedFloat32Array([0.1, 0.09, 0.05]), 7), 5, func(_t: float) -> Color: return stem, false, true)
		kit.ellipsoid(Vector3(s * 1.45, 1.45, 0.6), Vector3(0.45, 0.08, 0.28), Color(0.25, 0.85, 0.45, 0.2), 4, 8, Basis(Vector3.UP, s * 0.6))
	_mesh(body, kit)
	# Head: big flower.
	var head := Node3D.new()
	head.position = path[path.size() - 1] + Vector3(0, 0.05, 0.1)
	head.rotation.x = 0.55
	body.add_child(head)
	var pm := FlowerGenerator.petal_mesh(1.3, 0.55, Color(0.95, 0.3, 0.6), Color(1.0, 0.85, 0.35), true)
	for i in 9:
		var pv := Node3D.new()
		pv.rotation = Vector3(-0.25, TAU * i / 9.0, 0)
		head.add_child(pv)
		var mi := MeshInstance3D.new()
		mi.mesh = pm
		pv.add_child(mi)
	var face := MeshKit.new()
	face.ellipsoid(Vector3(0, 0.08, 0), Vector3(0.48, 0.2, 0.48), Color(1.0, 0.85, 0.3, 0.6), 6, 12)
	_mesh(head, face)
	var eyes_holder := Node3D.new()
	head.add_child(eyes_holder)
	_eyes(head, [Vector3(-0.17, 0.26, 0.12), Vector3(0.17, 0.26, 0.12)] as Array[Vector3], 0.1, Color(0.4, 1.0, 0.5), Vector3(0, 1, 0.3).normalized())
	var eyes := head.get_node("Eyes")
	head.remove_child(eyes)
	eyes.position = head.position
	eyes.rotation = head.rotation
	body.add_child(eyes)


static func _golem(body: Node3D, rng: RandomNumberGenerator, biome: BiomeData) -> void:
	var kit := MeshKit.new()
	var noise := FastNoiseLite.new()
	noise.seed = 99
	noise.frequency = 1.1
	var rock := Color(0.3, 0.2, 0.42)
	var stone_fn := func(d: Vector3) -> Color:
		var c := rock.lerp(Color(0.45, 0.32, 0.62), clampf(d.y * 0.5 + 0.5, 0.0, 1.0))
		c = c.lerp(Color(0.35, 0.55, 0.4), smoothstep(0.6, 0.95, d.y) * 0.6)
		c.a = 0.0
		return c
	kit.ellipsoid(Vector3(0, 2.0, 0), Vector3(1.5, 1.4, 1.2), rock, 9, 14, Basis.IDENTITY, noise, 0.18, stone_fn)
	kit.ellipsoid(Vector3(0, 3.35, 0.25), Vector3(0.8, 0.65, 0.7), rock, 7, 12, Basis.IDENTITY, noise, 0.2, stone_fn)
	for s: float in [-1.0, 1.0]:
		kit.ellipsoid(Vector3(s * 1.75, 2.3, 0.2), Vector3(0.6, 0.55, 0.55), rock, 6, 10, Basis.IDENTITY, noise, 0.25, stone_fn)
		kit.ellipsoid(Vector3(s * 2.0, 1.15, 0.45), Vector3(0.55, 0.85, 0.55), rock, 6, 10, Basis.IDENTITY, noise, 0.25, stone_fn)
		kit.ellipsoid(Vector3(s * 0.75, 0.45, 0.0), Vector3(0.6, 0.55, 0.65), rock, 6, 10, Basis.IDENTITY, noise, 0.2, stone_fn)
	# Glowing heartspore core + vein cracks.
	kit.ellipsoid(Vector3(0, 2.15, 1.05), Vector3(0.38, 0.38, 0.25), Color(1.0, 0.55, 0.15, 1.0), 6, 10)
	for i in 6:
		var a := TAU * i / 6.0
		var vp := PackedVector3Array([Vector3(0, 2.15, 1.1), Vector3(cos(a) * 0.7, 2.15 + sin(a) * 0.6, 1.0), Vector3(cos(a) * 1.2, 2.15 + sin(a) * 1.0, 0.6)])
		kit.tube(MeshKit.spline(vp, 3), _fit(PackedFloat32Array([0.06, 0.04, 0.02]), 7), 4, func(_t: float) -> Color: return Color(1.0, 0.6, 0.2, 1.0), false, true)
	_mesh(body, kit, MaterialLib.stone())
	# Mushroom forest on its back.
	var mk := MeshKit.new()
	for i in 7:
		var p := MushroomGenerator.random_params(rng, biome, "medium")
		var s := rng.randf_range(0.35, 0.6)
		p.stem_height *= s
		p.stem_width *= s
		p.cap_radius *= s
		p.cap_height *= s
		var a := rng.randf_range(-2.4, 2.4)
		var pos := Vector3(sin(a) * 0.9, 3.0 + rng.randf() * 0.4, -0.3 + cos(a) * 0.5)
		MushroomGenerator.build_into(mk, p, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), pos))
	_mesh(body, mk, MaterialLib.mushroom())
	_eyes(body, [Vector3(-0.3, 3.45, 0.85), Vector3(0.3, 3.45, 0.85)] as Array[Vector3], 0.13, Color(1.0, 0.6, 0.2))


# ---------------------------------------------------------------- characters
static func _keeper(body: Node3D, rng: RandomNumberGenerator, biome: BiomeData) -> void:
	var kit := MeshKit.new()
	var robe := Color(0.28, 0.12, 0.42)
	var trim := Color(0.25, 0.85, 0.6)
	var prof := PackedVector2Array([Vector2(0.18, 1.7), Vector2(0.3, 1.45), Vector2(0.38, 1.0), Vector2(0.5, 0.4), Vector2(0.62, 0.02)])
	kit.lathe(prof, 14, Vector3.ZERO, Basis.IDENTITY, func(t: float, a: float) -> Color:
		var c := robe.lerp(robe.lightened(0.15), 1.0 - t)
		if t > 0.85:
			c = trim
			c.a = 0.6
		else:
			c.a = 0.04 + (0.5 if absf(sin(a * 3.0 + t * 8.0)) > 0.97 else 0.0)
		return c, func(a: float, t: float) -> float: return 1.0 + 0.08 * sin(a * 5.0 + t * 4.0) * t, true, true)
	# Head and long glowing beard tendrils.
	var skin := Color(0.75, 0.62, 0.85)
	kit.ellipsoid(Vector3(0, 1.88, 0.02), Vector3(0.2, 0.22, 0.2), skin, 7, 12)
	kit.ellipsoid(Vector3(0, 1.84, 0.2), Vector3(0.06, 0.05, 0.07), skin.darkened(0.1), 4, 6)
	for i in 9:
		var a := -0.9 + i * 0.225
		var start := Vector3(sin(a) * 0.15, 1.78, 0.12 + cos(a) * 0.05)
		var bp := PackedVector3Array()
		var br := PackedFloat32Array()
		var length := 0.6 + absf(sin(i * 1.7)) * 0.35
		for k in 6:
			var t := float(k) / 5.0
			bp.append(start + Vector3(sin(t * 3.0 + i) * 0.04, -length * t, 0.08 * t + 0.05 * sin(t * 2.0)))
			br.append(0.028 * (1.0 - t * 0.7))
		kit.tube(bp, br, 4, func(t: float) -> Color:
			var c := Color(0.75, 0.8, 0.9).lerp(Color(0.3, 1.0, 0.9), t)
			c.a = t
			return c, false, true)
	# Arms (sleeves).
	for s: float in [-1.0, 1.0]:
		var ap := PackedVector3Array([Vector3(s * 0.28, 1.45, 0), Vector3(s * 0.45, 1.15, 0.15), Vector3(s * 0.4, 0.95, 0.35)])
		kit.tube(MeshKit.spline(ap, 3), _fit(PackedFloat32Array([0.1, 0.13, 0.15]), 7), 7, func(_t: float) -> Color: return robe.lightened(0.05), false, true)
		kit.ellipsoid(Vector3(s * 0.4, 0.92, 0.38), Vector3.ONE * 0.07, skin, 4, 6)
	_mesh(body, kit)
	# Huge droopy mushroom hat.
	var p := MushroomParams.new()
	p.seed = 7
	p.cap_shape = MushroomParams.CapShape.WAVY
	p.cap_radius = 0.95
	p.cap_height = 0.55
	p.cap_curvature = 1.0
	p.cap_asymmetry = 0.18
	p.stem_height = 0.02
	p.stem_width = 0.15
	p.cap_segments = 22
	p.cap_color = Color(1.0, 0.55, 0.15)
	p.cap_top_color = Color(1.0, 0.8, 0.3)
	p.glow_color = Color(0.3, 1.0, 0.9)
	p.spot_color = Color(1.0, 0.95, 0.7)
	p.spots = 9
	p.emission_intensity = 0.9
	var hat := MeshInstance3D.new()
	hat.mesh = MushroomGenerator.build(p, MaterialLib.creature())["mesh"]
	hat.position = Vector3(0, 2.0, -0.02)
	hat.rotation = Vector3(-0.12, 0, 0.08)
	body.add_child(hat)
	# Lantern staff.
	var sk := MeshKit.new()
	var sp := PackedVector3Array([Vector3(0.42, 0.0, 0.42), Vector3(0.44, 1.2, 0.42), Vector3(0.4, 2.2, 0.45), Vector3(0.5, 2.45, 0.45)])
	sk.tube(MeshKit.spline(sp, 4), _fit(PackedFloat32Array([0.04, 0.035, 0.03]), 13), 5, func(_t: float) -> Color: return Color(0.35, 0.2, 0.15, 0.05), true, true)
	sk.ellipsoid(Vector3(0.62, 2.25, 0.45), Vector3.ONE * 0.13, Color(1.0, 0.85, 0.35, 1.0), 6, 10)
	_mesh(body, sk)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.75, 0.4)
	lamp.light_energy = 1.4
	lamp.omni_range = 6.0
	lamp.position = Vector3(0.62, 2.25, 0.45)
	lamp.shadow_enabled = false
	body.add_child(lamp)
	_eyes(body, [Vector3(-0.08, 1.92, 0.17), Vector3(0.08, 1.92, 0.17)] as Array[Vector3], 0.045, Color(0.4, 1.0, 0.9))


static func _petalune(body: Node3D, rng: RandomNumberGenerator, biome: BiomeData) -> void:
	var kit := MeshKit.new()
	var stem := Color(0.2, 0.6, 0.45)
	var path := PackedVector3Array()
	var rad := PackedFloat32Array()
	for i in 9:
		var t := float(i) / 8.0
		path.append(Vector3(sin(t * 3.0) * 0.2, t * 2.8, 0))
		rad.append(0.16 * (1.0 - t * 0.4))
	kit.tube(path, rad, 8, func(t: float) -> Color:
		var c := stem.lerp(Color(0.4, 0.95, 0.6), t)
		c.a = 0.05
		return c, true, false)
	for s: float in [-1.0, 1.0]:
		var ap := PackedVector3Array([Vector3(0, 1.4, 0), Vector3(s * 0.5, 1.6, 0.25), Vector3(s * 0.8, 1.95, 0.4)])
		kit.tube(MeshKit.spline(ap, 3), _fit(PackedFloat32Array([0.07, 0.05, 0.03]), 7), 5, func(_t: float) -> Color: return stem, false, true)
		kit.ellipsoid(Vector3(s * 0.9, 2.05, 0.45), Vector3(0.3, 0.06, 0.18), Color(0.3, 0.9, 0.5, 0.2), 4, 8, Basis(Vector3.FORWARD, s * 0.6))
	_mesh(body, kit)
	var head := Node3D.new()
	head.position = path[path.size() - 1] + Vector3(0, 0.1, 0.05)
	head.rotation.x = 1.1
	body.add_child(head)
	var outer := FlowerGenerator.petal_mesh(1.1, 0.5, Color(1.0, 0.35, 0.65), Color(1.0, 0.75, 0.9), true)
	var inner := FlowerGenerator.petal_mesh(0.7, 0.4, Color(1.0, 0.55, 0.3), Color(1.0, 0.9, 0.4), true)
	for i in 10:
		var pv := Node3D.new()
		pv.rotation = Vector3(-0.15, TAU * i / 10.0, 0)
		head.add_child(pv)
		var mi := MeshInstance3D.new()
		mi.mesh = outer
		pv.add_child(mi)
	for i in 7:
		var pv2 := Node3D.new()
		pv2.rotation = Vector3(-0.6, TAU * i / 7.0 + 0.3, 0)
		head.add_child(pv2)
		var mi2 := MeshInstance3D.new()
		mi2.mesh = inner
		pv2.add_child(mi2)
	var face := MeshKit.new()
	face.ellipsoid(Vector3(0, 0.08, 0), Vector3(0.36, 0.16, 0.36), Color(1.0, 0.88, 0.5, 0.35), 6, 12)
	# Eyelashes.
	for s: float in [-1.0, 1.0]:
		for k in 3:
			var base := Vector3(s * (0.12 + k * 0.035), 0.22, 0.24 - k * 0.02)
			face.tube(PackedVector3Array([base, base + Vector3(s * 0.04, 0.1, 0.03)]), PackedFloat32Array([0.012, 0.004]), 3, func(_t: float) -> Color: return Color(0.15, 0.05, 0.2, 0.0), false, true)
	_mesh(head, face)
	_eyes(head, [Vector3(-0.13, 0.2, 0.12), Vector3(0.13, 0.2, 0.12)] as Array[Vector3], 0.08, Color(0.6, 0.3, 1.0), Vector3(0, 1, 0.4).normalized())


static func _ollo(body: Node3D, rng: RandomNumberGenerator, biome: BiomeData) -> void:
	var kit := MeshKit.new()
	var skin := Color(0.55, 0.85, 0.75)
	var path := PackedVector3Array()
	var rad := PackedFloat32Array()
	for i in 10:
		var t := float(i) / 9.0
		path.append(Vector3(0, 0.22 + (0.55 * smoothstep(0.65, 1.0, t)), -1.0 + t * 2.0))
		rad.append(0.28 * (1.0 - 0.3 * absf(t - 0.4)))
	kit.tube(path, rad, 10, func(t: float) -> Color:
		var c := skin.lerp(skin.lightened(0.2), t)
		c.a = 0.1
		return c, true, true)
	for s: float in [-1.0, 1.0]:
		var ep := PackedVector3Array([Vector3(s * 0.1, 0.9, 1.0), Vector3(s * 0.18, 1.3, 1.1)])
		kit.tube(ep, PackedFloat32Array([0.04, 0.03]), 5, func(_t: float) -> Color: return skin, false, true)
	_mesh(body, kit)
	# Spiral shell house.
	var sk := MeshKit.new()
	var shell := Color(0.9, 0.45, 0.2)
	var sp := PackedVector3Array()
	var sr := PackedFloat32Array()
	for i in 30:
		var t := float(i) / 29.0
		var a := t * TAU * 2.2
		var r := 0.75 * (1.0 - t * 0.85)
		sp.append(Vector3(sin(t * 0.5) * 0.1, 1.05 + sin(a) * r, -0.4 + cos(a) * r))
		sr.append(0.42 * (1.0 - t * 0.82))
	sk.tube(sp, sr, 10, func(t: float) -> Color:
		var c := shell.lerp(Color(1.0, 0.8, 0.4), t)
		c.a = 0.04 + (0.7 if fmod(t * 9.0, 1.0) < 0.08 else 0.0)
		return c, true, true)
	# Tiny lantern and chimney.
	sk.ellipsoid(Vector3(0.35, 1.95, -0.3), Vector3.ONE * 0.1, Color(1.0, 0.85, 0.4, 1.0), 5, 8)
	sk.tube(PackedVector3Array([Vector3(-0.2, 1.7, -0.5), Vector3(-0.2, 2.1, -0.5)]), PackedFloat32Array([0.07, 0.06]), 6, func(_t: float) -> Color: return Color(0.4, 0.25, 0.5, 0.05), true, true)
	_mesh(body, sk)
	_eyes(body, [Vector3(-0.18, 1.33, 1.12), Vector3(0.18, 1.33, 1.12)] as Array[Vector3], 0.07, Color(0.4, 0.6, 1.0))


static func _dreamer(body: Node3D, rng: RandomNumberGenerator, biome: BiomeData, opts: Dictionary) -> void:
	var kit := MeshKit.new()
	var robe: Color = opts.get("robe_color", Color(0.22, 0.25, 0.6))
	var hat_color: Color = opts.get("hat_color", Color(0.5, 0.2, 0.85))
	var prof := PackedVector2Array([Vector2(0.15, 1.45), Vector2(0.26, 1.25), Vector2(0.32, 0.8), Vector2(0.42, 0.3), Vector2(0.5, 0.02)])
	kit.lathe(prof, 14, Vector3.ZERO, Basis.IDENTITY, func(t: float, _a: float) -> Color:
		var c := robe.lerp(robe.lightened(0.25), 1.0 - t)
		c.a = 0.6 if t > 0.88 else 0.04
		if t > 0.88:
			c = Color(0.3, 1.0, 0.95, 0.7)
		return c, func(a: float, t: float) -> float: return 1.0 + 0.06 * sin(a * 4.0) * t, true, true)
	var skin := Color(0.95, 0.8, 0.85)
	kit.ellipsoid(Vector3(0, 1.62, 0), Vector3(0.18, 0.2, 0.18), skin, 7, 12)
	for s: float in [-1.0, 1.0]:
		var ap := PackedVector3Array([Vector3(s * 0.22, 1.25, 0), Vector3(s * 0.36, 1.0, 0.1), Vector3(s * 0.3, 0.85, 0.3)])
		kit.tube(MeshKit.spline(ap, 3), _fit(PackedFloat32Array([0.08, 0.1, 0.11]), 7), 6, func(_t: float) -> Color: return robe, false, true)
	_mesh(body, kit)
	# Pointy curling hat.
	var hk := MeshKit.new()
	var hp := PackedVector3Array()
	var hr := PackedFloat32Array()
	for i in 10:
		var t := float(i) / 9.0
		hp.append(Vector3(0, 1.72 + t * 0.75, -t * t * 0.35))
		hr.append(0.3 * pow(1.0 - t, 1.2) + 0.015)
	hk.tube(hp, hr, 10, func(t: float) -> Color:
		var c := hat_color.lerp(hat_color.lightened(0.3), t)
		c.a = 0.7 if absf(t - 0.25) < 0.05 else 0.05
		if c.a > 0.5:
			c = Color(1.0, 0.85, 0.35, 0.8)
		return c, true, true)
	hk.lathe(PackedVector2Array([Vector2(0.3, 1.74), Vector2(0.5, 1.72), Vector2(0.52, 1.69), Vector2(0.28, 1.7)]), 16, Vector3.ZERO, Basis.IDENTITY,
		func(_t: float, _a: float) -> Color: return Color(hat_color.r, hat_color.g, hat_color.b, 0.05), Callable(), false, false)
	_mesh(body, hk)
	# Staff with glowing orb.
	var sk := MeshKit.new()
	sk.tube(PackedVector3Array([Vector3(0.35, 0.05, 0.35), Vector3(0.36, 1.0, 0.35), Vector3(0.33, 1.8, 0.38)]), PackedFloat32Array([0.035, 0.03, 0.025]), 5, func(_t: float) -> Color: return Color(0.4, 0.25, 0.2, 0.05), true, true)
	sk.ellipsoid(Vector3(0.33, 1.9, 0.38), Vector3.ONE * 0.11, Color(0.3, 1.0, 0.95, 1.0), 6, 10)
	_mesh(body, sk)
	_eyes(body, [Vector3(-0.07, 1.66, 0.15), Vector3(0.07, 1.66, 0.15)] as Array[Vector3], 0.04, Color(0.3, 0.6, 1.0))


static func _drifter(body: Node3D, rng: RandomNumberGenerator, biome: BiomeData) -> void:
	# Jellyfish-like sky creature: translucent glowing bell with long tendrils.
	var kit := MeshKit.new()
	var col := biome.pick(biome.crystal_colors, rng, Color(0.4, 0.9, 1.0))
	var prof := PackedVector2Array()
	for i in 8:
		var u := float(i) / 7.0
		prof.append(Vector2(sin(u * 1.6) * 1.0, cos(u * 1.6) * 0.8))
	prof.append(Vector2(0.75, -0.02))
	prof.append(Vector2(0.4, 0.15))
	kit.lathe(prof, 16, Vector3.ZERO, Basis.IDENTITY, func(t: float, _a: float) -> Color:
		var c := col.lerp(Color(1.0, 0.6, 0.9), t)
		c.a = 0.35 + t * 0.5
		return c, func(a: float, t: float) -> float: return 1.0 + 0.08 * sin(a * 8.0) * t, true, false)
	for i in 8:
		var a := TAU * i / 8.0
		var tp := PackedVector3Array()
		var tr := PackedFloat32Array()
		for k in 8:
			var t := float(k) / 7.0
			tp.append(Vector3(cos(a) * 0.5 + sin(t * 4.0 + a) * 0.2, -t * 3.0, sin(a) * 0.5 + cos(t * 3.0 + a) * 0.2))
			tr.append(0.05 * (1.0 - t * 0.8))
		kit.tube(tp, tr, 4, func(t: float) -> Color: return Color(col.r, col.g, col.b, 0.4 + t * 0.6), false, true)
	_mesh(body, kit, null, false)


# ---------------------------------------------------------------- dark folk
## Hunched witch with a crooked hat, hooked nose, mismatched eyes and only
## two or three crooked teeth. opts: teeth (2|3), skin (Color), hat (Color).
static func _witch(body: Node3D, rng: RandomNumberGenerator, opts: Dictionary) -> void:
	var teeth: int = int(opts.get("teeth", 2 + rng.randi() % 2))
	var skins := [Color("#6f8f4a"), Color("#8a7aa8"), Color("#9aa07a"), Color("#5f7a6a")]
	var skin: Color = opts.get("skin", skins[rng.randi() % skins.size()])
	var robe := Color("#160d22")
	var kit := MeshKit.new()
	# Hunched robe with a ragged hem.
	var prof := PackedVector2Array([Vector2(0.16, 1.5), Vector2(0.3, 1.3), Vector2(0.36, 0.9), Vector2(0.48, 0.4), Vector2(0.62, 0.02)])
	kit.lathe(prof, 14, Vector3.ZERO, Basis(Vector3.RIGHT, 0.22), func(t: float, _a: float) -> Color:
		var c := robe.lerp(Color("#2a1838"), 1.0 - t)
		c.a = 0.02
		return c, func(a: float, t: float) -> float: return 1.0 + 0.28 * sin(a * 9.0 + 1.3) * pow(t, 4.0) + 0.06 * sin(a * 3.0), true, false)
	kit.ellipsoid(Vector3(0, 1.35, -0.18), Vector3(0.36, 0.3, 0.3), robe.lightened(0.05), 6, 10)
	# Head, chin and the long hooked nose with a wart.
	var head := Vector3(0, 1.62, 0.42)
	kit.ellipsoid(head, Vector3(0.24, 0.27, 0.24), skin, 8, 12, Basis.IDENTITY, null, 0.0, func(d: Vector3) -> Color:
		var c := skin.lerp(skin.darkened(0.35), clampf(-d.y, 0.0, 1.0))
		c.a = 0.03
		return c)
	var chin := skin.darkened(0.15)
	chin.a = 0.03
	kit.ellipsoid(head + Vector3(0.03, -0.27, 0.12), Vector3(0.09, 0.1, 0.09), chin, 4, 8)
	var nose := PackedVector3Array([head + Vector3(0, 0.02, 0.2), head + Vector3(0.02, -0.02, 0.42), head + Vector3(0.05, -0.12, 0.55), head + Vector3(0.06, -0.22, 0.56)])
	kit.tube(MeshKit.spline(nose, 3), _fit(PackedFloat32Array([0.075, 0.06, 0.04, 0.015]), 10), 6, func(_t: float) -> Color:
		var c := skin.darkened(0.08)
		c.a = 0.03
		return c, false, true)
	kit.ellipsoid(head + Vector3(0.06, -0.02, 0.43), Vector3.ONE * 0.035, skin.darkened(0.4), 3, 6)
	# Wide crooked grin with 2-3 teeth.
	var mouth := head + Vector3(0.0, -0.13, 0.2)
	kit.ellipsoid(mouth, Vector3(0.17, 0.055, 0.06), Color(0.06, 0.0, 0.02, 0.0), 4, 10, Basis(Vector3.FORWARD, rng.randf_range(-0.25, 0.25)))
	var tooth_col := Color("#e6d9a0")
	for i in teeth:
		var x := lerpf(-0.08, 0.08, float(i) / maxf(1.0, teeth - 1)) + rng.randf_range(-0.02, 0.02)
		var tb := Basis(Vector3.FORWARD, rng.randf_range(-0.5, 0.5)) * Basis(Vector3.RIGHT, PI)
		# One tooth hangs from the top, the next pokes up from below: madness.
		if i % 2 == 1:
			tb = Basis(Vector3.FORWARD, rng.randf_range(-0.6, 0.6))
		var ty := 0.045 if i % 2 == 0 else -0.05
		kit.crystal_prism(mouth + Vector3(x, ty, 0.05), tb, rng.randf_range(0.08, 0.13), 0.024, 4, Color(tooth_col.r * 0.8, tooth_col.g * 0.8, tooth_col.b * 0.7, 0.05), 0.4)
	# Wild straggly hair.
	var hair := Color("#a6a3b8") if rng.randf() < 0.6 else Color("#5a3a7a")
	for i in 14:
		var a := PI * 0.15 + PI * 0.7 * float(i) / 13.0 + PI
		var root := head + Vector3(cos(a) * 0.22, 0.12, sin(a) * 0.18 - 0.05)
		var hp := PackedVector3Array()
		var hr := PackedFloat32Array()
		var length := rng.randf_range(0.45, 0.9)
		for k in 6:
			var t := float(k) / 5.0
			hp.append(root + Vector3(cos(a) * 0.18 * t + sin(t * 7.0 + i) * 0.05, -length * t, sin(a) * 0.1 * t - 0.12 * t))
			hr.append(0.02 * (1.0 - t * 0.6))
		kit.tube(hp, hr, 3, func(_t: float) -> Color: return Color(hair.r, hair.g, hair.b, 0.02), false, true)
	# Bony arms with claws, holding a gnarled staff topped by a sickly orb.
	var hand := Vector3(0.38, 1.0, 0.55)
	kit.tube(MeshKit.spline(PackedVector3Array([Vector3(0.3, 1.3, 0.1), Vector3(0.42, 1.1, 0.35), hand]), 3), _fit(PackedFloat32Array([0.08, 0.06, 0.05]), 7), 5, func(_t: float) -> Color: return robe, false, true)
	for f in 4:
		var fd := Vector3(0.04 * (f - 1.5), -0.05, 0.12).normalized()
		kit.tube(PackedVector3Array([hand, hand + fd * 0.12, hand + fd * 0.2 + Vector3(0, -0.06, 0)]), PackedFloat32Array([0.018, 0.014, 0.006]), 3, func(_t: float) -> Color: return Color(skin.r * 0.7, skin.g * 0.7, skin.b * 0.7, 0.02), false, true)
	var other := Vector3(-0.36, 1.05, 0.5)
	kit.tube(MeshKit.spline(PackedVector3Array([Vector3(-0.3, 1.3, 0.1), Vector3(-0.42, 1.15, 0.3), other]), 3), _fit(PackedFloat32Array([0.08, 0.06, 0.05]), 7), 5, func(_t: float) -> Color: return robe, false, true)
	var staff := PackedVector3Array([Vector3(0.4, 0.0, 0.62), Vector3(0.36, 1.0, 0.58), Vector3(0.45, 1.8, 0.6), Vector3(0.3, 2.1, 0.62)])
	kit.tube(MeshKit.spline(staff, 4), _fit(PackedFloat32Array([0.04, 0.035, 0.03, 0.025]), 13), 5, func(_t: float) -> Color: return Color("#24160e", 0.02), true, true)
	var orb_col: Color = opts.get("orb", Color("#6dffb0"))
	kit.ellipsoid(Vector3(0.3, 2.2, 0.62), Vector3.ONE * 0.1, Color(orb_col.r, orb_col.g, orb_col.b, 1.0), 5, 8)
	_mesh(body, kit)
	# The hat: a tall bent cone with a floppy brim and a glowing band.
	var hk := MeshKit.new()
	var hat_col: Color = opts.get("hat", Color("#120a1e"))
	var hp2 := PackedVector3Array()
	var hr2 := PackedFloat32Array()
	var bend := Vector3(rng.randf_range(-0.4, 0.4), 0, -0.3)
	for i in 10:
		var t := float(i) / 9.0
		hp2.append(head + Vector3(0, 0.17 + t * 0.95, -0.05) + bend * t * t + Vector3(sin(t * 4.0) * 0.06, 0, 0))
		hr2.append(0.26 * pow(1.0 - t, 1.2) + 0.012)
	hk.tube(hp2, hr2, 9, func(t: float) -> Color:
		if absf(t - 0.12) < 0.04:
			return Color(orb_col.r, orb_col.g, orb_col.b, 0.8)
		var c := hat_col.lerp(hat_col.lightened(0.15), t)
		c.a = 0.02
		return c, true, true)
	hk.lathe(PackedVector2Array([Vector2(0.25, 0.02), Vector2(0.45, 0.0), Vector2(0.58, -0.06), Vector2(0.24, -0.02)]), 16, head + Vector3(0, 0.17, -0.05), Basis(Vector3.RIGHT, -0.12),
		func(_t: float, _a: float) -> Color: return Color(hat_col.r, hat_col.g, hat_col.b, 0.02), func(a: float, t: float) -> float: return 1.0 + 0.12 * sin(a * 5.0) * t, false, false)
	_mesh(body, hk)
	# Mismatched eyes: one huge and yellow, one small and red.
	var eyes := Node3D.new()
	eyes.name = "Eyes"
	body.add_child(eyes)
	var ek := MeshKit.new()
	var le := head + Vector3(-0.1, 0.06, 0.2)
	var re := head + Vector3(0.1, 0.03, 0.21)
	ek.ellipsoid(le, Vector3(0.075, 0.085, 0.05), Color(1.0, 0.9, 0.3, 0.9), 5, 8)
	ek.ellipsoid(le + Vector3(0.0, 0.0, 0.045), Vector3(0.02, 0.05, 0.02), Color(0.02, 0.0, 0.0, 0.0), 4, 6)
	ek.ellipsoid(re, Vector3(0.04, 0.04, 0.03), Color(1.0, 0.2, 0.15, 1.0), 4, 6)
	ek.ellipsoid(re + Vector3(0.0, 0.0, 0.028), Vector3.ONE * 0.012, Color(0.02, 0.0, 0.0, 0.0), 3, 5)
	_mesh(eyes, ek, null, false)
	var l := OmniLight3D.new()
	l.light_color = orb_col
	l.light_energy = 1.2
	l.omni_range = 4.0
	l.position = Vector3(0.3, 2.2, 0.62)
	body.add_child(l)


## Goggled gremlin with bat ears, spotted skin and a propeller pack.
static func _gremlin(body: Node3D, rng: RandomNumberGenerator) -> void:
	var skin := Color("#4fae3a")
	var spot := Color("#1d5a18")
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = 3.0
	var spotty := func(d: Vector3) -> Color:
		var c := skin.lerp(skin.darkened(0.3), clampf(-d.y, 0.0, 1.0))
		if noise.get_noise_3dv(d * 2.0) > 0.35:
			c = spot
		c.a = 0.12
		return c
	var limb := Color(skin.r, skin.g, skin.b, 0.12)
	var kit := MeshKit.new()
	kit.ellipsoid(Vector3(0, 0.55, 0), Vector3(0.28, 0.32, 0.24), skin, 7, 10, Basis.IDENTITY, null, 0.0, spotty)
	var head := Vector3(0, 1.08, 0.08)
	kit.ellipsoid(head, Vector3(0.42, 0.34, 0.36), skin, 9, 14, Basis.IDENTITY, null, 0.0, spotty)
	# Bat ears.
	for s: float in [-1.0, 1.0]:
		kit.ellipsoid(head + Vector3(s * 0.48, 0.2, -0.05), Vector3(0.32, 0.05, 0.16), Color(skin.r * 0.8, skin.g * 0.8, skin.b * 0.8, 0.25), 4, 8, Basis(Vector3.FORWARD, s * 0.5) * Basis(Vector3.UP, s * 0.3))
	# Huge grin full of sharp teeth.
	var mouth := head + Vector3(0, -0.12, 0.3)
	kit.ellipsoid(mouth, Vector3(0.3, 0.07, 0.08), Color(0.25, 0.02, 0.05, 0.0), 4, 12)
	for i in 9:
		var x := lerpf(-0.24, 0.24, float(i) / 8.0)
		var up := i % 2 == 0
		var tb := Basis.IDENTITY if not up else Basis(Vector3.RIGHT, PI)
		kit.crystal_prism(mouth + Vector3(x, (0.05 if up else -0.05), 0.06 - absf(x) * 0.15), tb, 0.07, 0.02, 3, Color(0.95, 0.95, 0.85, 0.1), 0.5)
	# Arms, legs and little bat wings.
	for s: float in [-1.0, 1.0]:
		kit.tube(PackedVector3Array([Vector3(s * 0.25, 0.7, 0.05), Vector3(s * 0.45, 0.5, 0.2), Vector3(s * 0.4, 0.35, 0.3)]), PackedFloat32Array([0.06, 0.05, 0.04]), 5, func(_t: float) -> Color: return limb, false, true)
		kit.tube(PackedVector3Array([Vector3(s * 0.12, 0.3, 0.0), Vector3(s * 0.15, 0.12, 0.05), Vector3(s * 0.16, 0.0, 0.12)]), PackedFloat32Array([0.07, 0.06, 0.05]), 5, func(_t: float) -> Color: return limb.darkened(0.2), false, true)
		kit.ellipsoid(Vector3(s * 0.45, 0.85, -0.2), Vector3(0.35, 0.04, 0.2), Color("#1a1420", 0.02), 3, 8, Basis(Vector3.FORWARD, s * 0.4))
	# Propeller backpack.
	kit.ellipsoid(Vector3(0, 0.75, -0.3), Vector3(0.2, 0.22, 0.12), Color("#3a2414", 0.02), 5, 8)
	_mesh(body, kit)
	var gk := MeshKit.new()
	var brass := Color("#9a7a30")
	for s: float in [-1.0, 1.0]:
		var c := head + Vector3(s * 0.15, 0.1, 0.32)
		var ring := PackedVector3Array()
		var rr := PackedFloat32Array()
		for k in 13:
			var a := TAU * k / 12.0
			ring.append(c + Vector3(cos(a) * 0.12, sin(a) * 0.12, 0))
			rr.append(0.03)
		gk.tube(ring, rr, 5, func(_t: float) -> Color: return Color(brass.r, brass.g, brass.b, 0.1), false, false)
		gk.ellipsoid(c, Vector3(0.11, 0.11, 0.03), Color(0.3, 0.9, 0.85, 0.7), 4, 8)
		for p in 2:
			var pc := Vector3(s * 0.35, 0.95 + p * 0.02, -0.38)
			gk.ellipsoid(pc, Vector3(0.28, 0.015, 0.05), Color(brass.r, brass.g, brass.b, 0.05), 3, 6, Basis(Vector3.UP, p * PI * 0.5))
	gk.tube(PackedVector3Array([head + Vector3(-0.4, 0.15, 0.1), head + Vector3(0, 0.3, 0.05), head + Vector3(0.4, 0.15, 0.1)]), PackedFloat32Array([0.03, 0.03, 0.03]), 4, func(_t: float) -> Color: return Color("#2a1a10", 0.0), false, false)
	_mesh(body, gk)
	var eyes := Node3D.new()
	eyes.name = "Eyes"
	body.add_child(eyes)
	var ek := MeshKit.new()
	for s: float in [-1.0, 1.0]:
		ek.ellipsoid(head + Vector3(s * 0.15, 0.1, 0.3), Vector3(0.07, 0.06, 0.03), Color(1.0, 0.75, 0.1, 1.0), 4, 6)
		ek.ellipsoid(head + Vector3(s * 0.15, 0.1, 0.33), Vector3(0.012, 0.045, 0.01), Color(0.0, 0.0, 0.0, 0.0), 3, 5)
	_mesh(eyes, ek, null, false)
