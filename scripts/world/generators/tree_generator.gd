class_name TreeGenerator
extends RefCounted
## Surreal trees: fluted spiral trunks, curling fiddlehead branches, puffy
## lollipop canopies or drooping glow-willows, with hanging luminous pods.

enum Style { SPIRAL_LOLLIPOP, CURL_WILLOW, STACKED_DISCS }


static func build(rng: RandomNumberGenerator, biome: BiomeData, height: float, thickness: float, style: int = -1) -> Dictionary:
	var kits := build_kits(rng, biome, height, thickness, style)
	var mesh := (kits["trunk"] as MeshKit).commit(MaterialLib.bark())
	(kits["leaves"] as MeshKit).commit(MaterialLib.foliage(), mesh)
	return {"mesh": mesh, "trunk_radius": thickness, "height": height}


## Same as build() but returns the unmerged MeshKits ("trunk", "leaves") so
## callers can batch many trees into a few draw calls.
static func build_kits(rng: RandomNumberGenerator, biome: BiomeData, height: float, thickness: float, style: int = -1) -> Dictionary:
	if style < 0:
		style = rng.randi() % 3
	var trunk_kit := MeshKit.new()
	var leaf_kit := MeshKit.new()
	var bark := biome.pick(biome.bark_colors, rng, Color(0.35, 0.15, 0.45))
	var leaf := biome.pick(biome.foliage_colors, rng, Color(0.2, 0.9, 0.7))
	var glow := biome.pick(biome.mushroom_glow, rng, Color(1.0, 0.6, 0.2))
	var pod_color := Color(1.0, 0.6, 0.18)
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = 0.8

	# Trunk follows a slow helix that widens with height.
	var turns := rng.randf_range(0.4, 1.1)
	var spiral_r := height * rng.randf_range(0.04, 0.12)
	var lean := Vector2.from_angle(rng.randf() * TAU) * height * rng.randf_range(0.02, 0.12)
	var path := PackedVector3Array()
	var radii := PackedFloat32Array()
	var steps := 14
	for i in steps + 1:
		var t := float(i) / steps
		var a := t * turns * TAU
		path.append(Vector3(sin(a) * spiral_r * t + lean.x * t * t, height * t, cos(a) * spiral_r * t - spiral_r * t + lean.y * t * t))
		radii.append(thickness * (1.0 - 0.72 * t) * (1.0 + 0.9 * exp(-t * 9.0)))
	var flutes := rng.randi_range(4, 7)
	var bark_fn := func(t: float) -> Color:
		var c := bark.lerp(bark.lightened(0.3), t)
		c.a = 0.05
		return c
	trunk_kit.tube(path, radii, 12, bark_fn, true, true,
		func(ang: float, t: float) -> float: return 1.0 + 0.16 * sin(ang * flutes + t * 9.0))
	# Glowing groove spiral wrapped around the trunk.
	var groove := PackedVector3Array()
	var groove_r := PackedFloat32Array()
	for i in 25:
		var t := float(i) / 24.0 * 0.85
		var idx := clampi(int(t * steps), 0, steps - 1)
		var f := t * steps - idx
		var center := path[idx].lerp(path[idx + 1], f)
		var r := lerpf(radii[idx], radii[idx + 1], f) * 1.08
		var a2 := t * TAU * 2.5
		groove.append(center + Vector3(cos(a2) * r, 0, sin(a2) * r))
		groove_r.append(thickness * 0.06)
	var gcol := glow
	trunk_kit.tube(groove, groove_r, 4, func(_t: float) -> Color: return Color(gcol.r, gcol.g, gcol.b, 0.9))

	var tips: Array[Vector3] = [path[path.size() - 1]]
	# Branches that end in curls.
	var branch_count := rng.randi_range(2, 5)
	for b in branch_count:
		var t0 := rng.randf_range(0.45, 0.85)
		var i0 := int(t0 * steps)
		var start := path[i0]
		var dir := _rand_dir_xz(rng)
		var length := height * rng.randf_range(0.22, 0.4)
		var bp := PackedVector3Array()
		var br := PackedFloat32Array()
		var curl_dir := 1.0 if rng.randf() > 0.5 else -1.0
		for k in 9:
			var s := float(k) / 8.0
			var out := dir * length * s
			var up := Vector3.UP * length * (0.6 * s + 0.4 * sin(s * PI) )
			var curl := Vector3.ZERO
			if s > 0.6:
				var cs := (s - 0.6) / 0.4
				curl = (dir.rotated(Vector3.UP, PI * 0.5 * curl_dir) * sin(cs * PI) - dir * (1.0 - cos(cs * PI))) * length * 0.15
			bp.append(start + out + up + curl)
			br.append(radii[i0] * 0.5 * (1.0 - s * 0.75))
		trunk_kit.tube(bp, br, 6, bark_fn, false, true)
		tips.append(bp[bp.size() - 1])

	match style:
		Style.SPIRAL_LOLLIPOP:
			for tip: Vector3 in tips:
				var r := height * rng.randf_range(0.14, 0.24)
				var lc := leaf.lerp(biome.pick(biome.foliage_colors, rng, leaf), 0.4)
				leaf_kit.ellipsoid(tip + Vector3.UP * r * 0.55, Vector3(r, r * rng.randf_range(0.7, 1.0), r), lc, 8, 14, Basis.IDENTITY, noise, 0.28,
					func(d: Vector3) -> Color:
						var c := lc.lerp(lc.lightened(0.35), clampf(d.y * 0.5 + 0.5, 0.0, 1.0))
						c.a = 0.08 + 0.25 * clampf(-d.y, 0.0, 1.0)
						return c)
		Style.CURL_WILLOW:
			var crown := tips[0]
			var r := height * 0.2
			leaf_kit.ellipsoid(crown + Vector3.UP * r * 0.3, Vector3(r * 1.2, r * 0.6, r * 1.2), leaf, 7, 14, Basis.IDENTITY, noise, 0.2)
			var strands := rng.randi_range(10, 16)
			for s in strands:
				var a := TAU * float(s) / strands + rng.randf() * 0.3
				var rr := r * rng.randf_range(0.7, 1.15)
				var st := crown + Vector3(cos(a) * rr, 0, sin(a) * rr)
				var drop := height * rng.randf_range(0.35, 0.6)
				var sp := PackedVector3Array()
				var sr := PackedFloat32Array()
				for k in 6:
					var t := float(k) / 5.0
					sp.append(st + Vector3(cos(a) * t * 0.6, -drop * t, sin(a) * t * 0.6))
					sr.append(thickness * 0.09 * (1.0 - t * 0.6))
				var lcol := leaf
				var gl := glow
				leaf_kit.tube(sp, sr, 4, func(t: float) -> Color:
					var c := lcol.lerp(gl, t)
					c.a = t * 0.9
					return c, false, true)
		Style.STACKED_DISCS:
			var crown := tips[0]
			var layers := rng.randi_range(3, 5)
			for l in layers:
				var lt := float(l) / layers
				var rad := height * lerpf(0.3, 0.1, lt)
				var center := crown + Vector3.UP * (lt * height * 0.35 - height * 0.05)
				var prof := PackedVector2Array([Vector2(0, rad * 0.25), Vector2(rad * 0.6, rad * 0.2), Vector2(rad, 0.0), Vector2(rad * 0.7, -rad * 0.08), Vector2(0.0, -rad * 0.05)])
				var lc := leaf.lerp(glow, lt * 0.35)
				leaf_kit.lathe(prof, 16, center, Basis(Vector3.UP, rng.randf() * TAU), func(t: float, _a: float) -> Color:
					var c := lc.lightened(0.2 * (1.0 - t))
					c.a = 0.1 + 0.6 * smoothstep(0.4, 0.6, t)
					return c, func(a: float, t: float) -> float: return 1.0 + 0.08 * sin(a * 6.0) * t, true, true)
			for tip: Vector3 in tips.slice(1):
				leaf_kit.ellipsoid(tip, Vector3.ONE * height * 0.07, leaf, 6, 10)

	# Hanging glowing pods.
	var pods := rng.randi_range(2, 6)
	for i in pods:
		var tip: Vector3 = tips[rng.randi() % tips.size()]
		var off := _rand_dir_xz(rng) * height * rng.randf_range(0.05, 0.18)
		var hang := tip + off - Vector3.UP * height * rng.randf_range(0.08, 0.2)
		var pr := height * 0.025
		leaf_kit.ellipsoid(hang, Vector3(pr, pr * 1.4, pr), Color(pod_color.r, pod_color.g, pod_color.b, 1.0), 5, 8)

	return {"trunk": trunk_kit, "leaves": leaf_kit, "trunk_radius": thickness, "height": height}


static func _rand_dir_xz(rng: RandomNumberGenerator) -> Vector3:
	var a := rng.randf() * TAU
	return Vector3(cos(a), 0, sin(a))
