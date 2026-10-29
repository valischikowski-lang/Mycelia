class_name IslandGenerator
extends RefCounted
## Floating landmasses: a grassy irregular top, a stratified rocky underside
## tapering to a point, dangling glowing roots, downward crystals and an
## optional sky waterfall.


static func build(rng: RandomNumberGenerator, biome: BiomeData, radius: float, depth: float, opts: Dictionary = {}) -> Dictionary:
	var kit := MeshKit.new()
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = 0.9
	var top_profile := PackedVector2Array()
	var cols: Array[Color] = []
	var grass := biome.grass_color
	var moss := biome.moss_color
	var rock := biome.rock_color
	var vein := biome.vein_color
	# Top surface: center -> rim (outward, faces up).
	var top_rows := 4
	for i in top_rows + 1:
		var u := float(i) / top_rows
		top_profile.append(Vector2(radius * u, 0.35 * radius * 0.12 * (1.0 - u * u)))
		var c := grass.lerp(biome.grass_tip_color, 0.25 * (1.0 - u)).lerp(moss, smoothstep(0.6, 1.0, u) * 0.6)
		c.a = 0.04
		cols.append(c)
	# Rim lip.
	top_profile.append(Vector2(radius * 1.03, -depth * 0.06))
	var lip := moss.lerp(vein, 0.3)
	lip.a = 0.5
	cols.append(lip)
	# Underside: down and inward to a point.
	var under_rows := 7
	for i in range(1, under_rows + 1):
		var u := float(i) / under_rows
		var r := radius * (1.0 - pow(u, 0.75)) * 1.0
		top_profile.append(Vector2(maxf(r, 0.01), -depth * 0.06 - depth * u))
		var strata := rock.lerp(rock.darkened(0.45), u)
		var band := 0.5 + 0.5 * sin(u * 18.0)
		strata = strata.lerp(rock.lightened(0.3), band * 0.25)
		strata.a = 0.35 if absf(u - 0.35) < 0.07 else 0.0
		if strata.a > 0.0:
			strata = strata.lerp(vein, 0.6)
		cols.append(strata)
	var n_rows := top_profile.size()
	var outline_seed := rng.randf() * 100.0
	var mod := func(a: float, t: float) -> float:
		return 1.0 + noise.get_noise_2d(cos(a) * 2.0 + outline_seed, sin(a) * 2.0) * 0.35 * (0.6 + t)
	kit.lathe(top_profile, 22, Vector3.ZERO, Basis.IDENTITY,
		func(t: float, _a: float) -> Color: return cols[clampi(int(round(t * (n_rows - 1))), 0, n_rows - 1)],
		mod, true, true)

	# Hanging roots.
	var roots := int(opts.get("roots", rng.randi_range(5, 10)))
	for i in roots:
		var a := rng.randf() * TAU
		var rr := radius * rng.randf_range(0.2, 0.8)
		var start := Vector3(cos(a) * rr, -depth * (0.1 + 0.6 * (1.0 - rr / radius)), sin(a) * rr)
		var length := depth * rng.randf_range(0.6, 1.6)
		var rp := PackedVector3Array()
		var rad := PackedFloat32Array()
		for k in 7:
			var t := float(k) / 6.0
			rp.append(start + Vector3(sin(t * 5.0 + a) * 0.3, -length * t, cos(t * 4.0 + a) * 0.3))
			rad.append(radius * 0.025 * (1.0 - t * 0.85))
		var vc := vein
		var rcol := rock.lightened(0.15)
		kit.tube(rp, rad, 5, func(t: float) -> Color:
			var c := rcol.lerp(vc, t * t)
			c.a = t * t
			return c, false, true)
	var mesh := kit.commit(MaterialLib.stone())

	# Downward crystals.
	if bool(opts.get("crystals", true)):
		var ck := MeshKit.new()
		var ccount := rng.randi_range(2, 5)
		for i in ccount:
			var a := rng.randf() * TAU
			var rr := radius * rng.randf_range(0.1, 0.45)
			var base := Vector3(cos(a) * rr, -depth * (0.3 + 0.5 * (1.0 - rr / radius)), sin(a) * rr)
			var dir := Vector3.DOWN.rotated(Vector3(cos(a + 1.57), 0, sin(a + 1.57)), rng.randf_range(0.1, 0.5))
			var cc := biome.pick(biome.crystal_colors, rng, Color(0.3, 0.9, 1.0))
			ck.crystal_prism(base, CrystalGenerator._basis_up(dir, a), depth * rng.randf_range(0.3, 0.7), radius * 0.06, 6, cc)
		ck.commit(MaterialLib.crystal(1.6), mesh)

	var result := {"mesh": mesh, "radius": radius, "depth": depth, "top_height": 0.35 * radius * 0.12}
	# Waterfall ribbon pouring off the rim.
	if bool(opts.get("waterfall", false)):
		var wk := MeshKit.new()
		var a := rng.randf() * TAU
		var rim := Vector3(cos(a), 0, sin(a)) * radius * 0.95
		var side := Vector3(-sin(a), 0, cos(a))
		var fall := float(opts.get("fall_height", depth * 6.0))
		var width := radius * 0.18
		var prev := PackedInt32Array()
		for k in 13:
			var t := float(k) / 12.0
			var outward := Vector3(cos(a), 0, sin(a)) * (radius * 0.08 * sqrt(t) * 3.0)
			var center := rim + outward + Vector3.DOWN * fall * t
			var w := width * (1.0 + t * 0.8)
			var l := wk.add_vertex(center - side * w, Color(1, 1, 1, 1), Vector2(0, t * 6.0))
			var r := wk.add_vertex(center + side * w, Color(1, 1, 1, 1), Vector2(1, t * 6.0))
			if prev.size() == 2:
				wk.add_quad(prev[0], prev[1], r, l)
			prev = PackedInt32Array([l, r])
		result["waterfall_mesh"] = wk.commit(MaterialLib.water("waterfall", {"flow_speed": 3.0, "flow_dir": Vector2(0, -1), "alpha": 0.6, "glow": 1.4, "wave_height": 0.0}))
		result["waterfall_bottom"] = rim + Vector3.DOWN * fall
	return result
