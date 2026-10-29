class_name MushroomGenerator
extends RefCounted
## Procedural mushroom meshes. Every mushroom is a bent/twisted stem sweep
## plus a lathed cap whose single profile runs apex -> rim -> gills -> stem,
## with asymmetry, lobes, glowing rim/gills and surface spots.

const Shape := MushroomParams.CapShape


## Returns {"mesh": ArrayMesh, "stem_top": Vector3, "stem_radius": float,
## "stem_height": float, "cap_center": Vector3, "cap_radius": float, "cap_height": float}
static func build(p: MushroomParams, material: Material = null) -> Dictionary:
	var kit := MeshKit.new()
	var info := build_into(kit, p, Transform3D.IDENTITY)
	info["mesh"] = kit.commit(material if material else MaterialLib.mushroom())
	return info


static func build_into(kit: MeshKit, p: MushroomParams, xform: Transform3D) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = p.seed
	var local := MeshKit.new()
	var info: Dictionary = {}

	# --- Stem ---------------------------------------------------------------
	var stem_h := p.stem_height
	var bend_dir := Vector2.from_angle(rng.randf() * TAU)
	var path := PackedVector3Array()
	var radii := PackedFloat32Array()
	var steps := int(lerpf(3.0, 10.0, p.detail))
	for i in steps + 1:
		var t := float(i) / steps
		var bend := p.stem_bend * t * t
		var tw := p.stem_twist * t
		var pos := Vector3(bend_dir.x * bend + sin(t * TAU * 1.3) * tw, stem_h * t, bend_dir.y * bend + cos(t * TAU * 1.3) * tw - tw)
		path.append(pos)
		var flare := 1.0 + 0.7 * exp(-t * 7.0)
		radii.append(p.stem_width * (1.0 - 0.3 * t) * flare)
	var stem_glow := p.glow_color
	var stem_fn := func(t: float) -> Color:
		var c := p.stem_color.lerp(p.stem_color.lightened(0.25), t)
		# Faint glow at the foot where the Mycelium enters the stem.
		var g := 0.55 * exp(-t * 9.0) * p.emission_intensity
		c = c.lerp(stem_glow, g * 0.6)
		c.a = g + 0.04
		return c
	if not p.floating or stem_h > 0.05:
		var sides := (10 if p.stem_width > 0.4 else 8) if p.detail > 0.5 else 5
		local.tube(path, radii, sides, stem_fn, not p.floating, false,
			func(a: float, t: float) -> float: return 1.0 + 0.06 * sin(a * 5.0 + t * 6.0))
	var top := path[path.size() - 1]
	var tangent := (path[path.size() - 1] - path[path.size() - 2]).normalized()
	var cap_up := tangent.lerp(Vector3.UP, 0.55).normalized()
	cap_up = (cap_up + Vector3(rng.randf_range(-0.08, 0.08), 0, rng.randf_range(-0.08, 0.08))).normalized()
	var cap_basis := _basis_from_up(cap_up, rng.randf() * TAU)

	# --- Cap profile ----------------------------------------------------------
	var R := p.cap_radius
	var H := p.cap_height
	var outer: Array[Vector2] = []
	var rows := int(lerpf(4.0, 9.0, p.detail))
	for i in rows + 1:
		var u := float(i) / rows
		outer.append(_outer_profile(p.cap_shape, u, R, H, p.cap_curvature))
	var rim: Vector2 = outer[outer.size() - 1]
	var profile := PackedVector2Array()
	var row_colors: Array[Color] = []
	var cap_top := p.cap_top_color
	var cap_main := p.cap_color
	for i in outer.size():
		var u := float(i) / rows
		profile.append(outer[i])
		var c := cap_top.lerp(cap_main, smoothstep(0.0, 0.75, u))
		c.a = 0.03
		if p.rim_glow and i >= outer.size() - 2:
			c = c.lerp(p.glow_color, 0.55)
			c.a = 0.55 * p.emission_intensity
		row_colors.append(c)
	if p.cap_shape != Shape.PUFFBALL:
		# Gills: rim back towards the stem, slightly raised.
		var stem_r := radii[radii.size() - 1] * 1.05
		var gill_rows := 3 if p.detail > 0.5 else 1
		for g in range(1, gill_rows + 1):
			var k := float(g) / gill_rows
			var r := lerpf(rim.x * 0.97, stem_r, k)
			var y := rim.y + H * 0.08 + H * 0.22 * pow(k, 0.7)
			profile.append(Vector2(r, y))
			var gc := p.glow_color.lerp(p.cap_color.darkened(0.3), k * 0.5)
			# Giant caps are seen mostly from below: keep their gills softer.
			var gill_glow := 0.55 if R > 4.0 else 1.0
			gc.a = lerpf(1.0, 0.6, k) * p.emission_intensity * gill_glow
			row_colors.append(gc)
	var asym_angle := rng.randf() * TAU
	var lobe_phase := rng.randf() * TAU
	var lobes := p.cap_lobes
	if p.cap_shape == Shape.WAVY and lobes == 0:
		lobes = 7
	var asym := p.cap_asymmetry
	var mod := func(a: float, t: float) -> float:
		var m := 1.0 + asym * cos(a - asym_angle) * t
		if lobes > 0:
			m += 0.09 * sin(a * lobes + lobe_phase) * t * t
		return m
	var n_rows := profile.size()
	var color_fn := func(t: float, _a: float) -> Color:
		var idx := clampi(int(round(t * (n_rows - 1))), 0, n_rows - 1)
		return row_colors[idx]
	# The cap sits slightly sunk onto the stem.
	var cap_origin := top - cap_up * H * 0.12
	local.lathe(profile, p.cap_segments, cap_origin, cap_basis, color_fn, mod, true, p.cap_shape == Shape.PUFFBALL)

	# --- Spots ----------------------------------------------------------------
	for s in p.spots:
		var u := rng.randf_range(0.12, 0.78)
		var a := rng.randf() * TAU
		var pr := _outer_profile(p.cap_shape, u, R, H, p.cap_curvature)
		var pr2 := _outer_profile(p.cap_shape, minf(u + 0.03, 1.0), R, H, p.cap_curvature)
		var m := float(mod.call(a, u))
		var lp := Vector3(cos(a) * pr.x * m, pr.y, sin(a) * pr.x * m)
		var slope := Vector2(pr2.x - pr.x, pr2.y - pr.y).normalized()
		var ln := Vector3(cos(a) * -slope.y, slope.x, sin(a) * -slope.y).normalized()
		var wp := cap_origin + cap_basis * lp
		var wn := (cap_basis * ln).normalized()
		var size := R * rng.randf_range(0.06, 0.13)
		var sc := p.spot_color
		sc.a = p.emission_intensity
		local.ellipsoid(wp + wn * size * 0.15, Vector3(size, size * 0.32, size), sc, 3 if p.detail < 0.5 else 4, 6 if p.detail < 0.5 else 8, _basis_from_up(wn, a))

	# --- Tendrils (floating mushrooms / special variants) ---------------------
	for i in p.tendrils:
		var a := TAU * float(i) / maxf(1.0, p.tendrils) + rng.randf() * 0.4
		var start_r := rim.x * rng.randf_range(0.35, 0.85)
		var start := cap_origin + cap_basis * Vector3(cos(a) * start_r, rim.y + H * 0.1, sin(a) * start_r)
		var length := R * rng.randf_range(0.8, 2.2)
		var tp := PackedVector3Array()
		var tr := PackedFloat32Array()
		for k in 7:
			var t := float(k) / 6.0
			tp.append(start + Vector3(sin(t * 4.0 + a) * 0.15 * R * t, -length * t, cos(t * 3.0 + a) * 0.15 * R * t))
			tr.append(R * 0.045 * (1.0 - t * 0.8))
		var gcol := p.glow_color
		local.tube(tp, tr, 5, func(t: float) -> Color: return Color(gcol.r, gcol.g, gcol.b, 0.25 + t * 0.75), false, true)

	kit.merge(local, xform)
	# Convex hull points of the cap's outer surface (for walkable collision).
	var hull := PackedVector3Array()
	for i in range(0, outer.size(), 2):
		var pr: Vector2 = outer[i]
		for k in 12:
			var a := TAU * k / 12.0
			var m := float(mod.call(a, float(i) / rows))
			hull.append(xform * (cap_origin + cap_basis * Vector3(cos(a) * pr.x * m, pr.y, sin(a) * pr.x * m)))
	var under_y := rim.y + H * 0.25
	for k in 12:
		var a := TAU * k / 12.0
		hull.append(xform * (cap_origin + cap_basis * Vector3(cos(a) * rim.x * 0.6, under_y, sin(a) * rim.x * 0.6)))
	info["cap_points"] = hull
	var world_path := PackedVector3Array()
	for pt: Vector3 in path:
		world_path.append(xform * pt)
	info["stem_path"] = world_path
	info["stem_top"] = xform * top
	info["stem_radius"] = p.stem_width
	info["stem_height"] = stem_h
	info["cap_center"] = xform * (cap_origin + cap_basis * Vector3(0, rim.y + H * 0.35, 0))
	info["cap_radius"] = R
	info["cap_height"] = H
	return info


static func _outer_profile(shape: int, u: float, R: float, H: float, curv: float) -> Vector2:
	match shape:
		Shape.DOME:
			var tmax := lerpf(1.45, 1.9, curv)
			return Vector2(R * sin(u * tmax) / sin(minf(tmax, PI * 0.5)), H * cos(u * tmax))
		Shape.BELL:
			var r := R * pow(u, 0.65) * (1.0 + 0.3 * smoothstep(0.7, 1.0, u))
			return Vector2(r, H * (1.0 - pow(u, 1.25)) - H * 0.12 * curv * smoothstep(0.75, 1.0, u))
		Shape.PARASOL:
			var y := H * (0.35 * (1.0 - u * u) + 0.65 * exp(-u * u * 22.0))
			return Vector2(R * u, y - H * 0.2 * curv * u * u * u)
		Shape.FUNNEL:
			return Vector2(R * u, H * (0.15 + 0.85 * pow(u, 1.6)) - H * 0.25 * curv * smoothstep(0.85, 1.0, u))
		Shape.WAVY:
			var tmax2 := lerpf(1.3, 1.7, curv)
			return Vector2(R * sin(u * tmax2) / sin(tmax2 if tmax2 < PI * 0.5 else PI * 0.5), H * cos(u * tmax2) * 0.8)
		Shape.PUFFBALL:
			var th := u * PI
			return Vector2(R * sin(th), H * cos(th))
		Shape.SPIRE:
			var r2 := R * pow(u, 1.5)
			return Vector2(r2, H * (1.0 - u) - H * 0.1 * curv * u)
	return Vector2(R * u, H * (1.0 - u))


static func _basis_from_up(up: Vector3, spin: float) -> Basis:
	var ref := Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var z := ref.cross(up).normalized()
	var x := up.cross(z).normalized()
	var b := Basis(x, up, z)
	return b * Basis(Vector3.UP, spin)


## Generates parameters for a size class using a biome palette.
## size_class: "small" | "medium" | "giant" | "twisted" | "floating" | "cluster"
static func random_params(rng: RandomNumberGenerator, biome: BiomeData, size_class: String) -> MushroomParams:
	var p := MushroomParams.new()
	p.seed = rng.randi()
	p.cap_color = biome.pick(biome.mushroom_caps, rng, Color(0.7, 0.2, 0.9))
	p.cap_top_color = biome.pick(biome.mushroom_caps, rng, Color(1.0, 0.4, 0.8)).lightened(0.15)
	p.glow_color = biome.pick(biome.mushroom_glow, rng, Color(0.2, 1.0, 0.95))
	p.spot_color = biome.pick(biome.mushroom_glow, rng, Color(1.0, 0.9, 0.3))
	if p.spot_color == p.glow_color:
		p.spot_color = Color(1.0, 0.92, 0.4)
	p.stem_color = Color(0.86, 0.8, 1.0).lerp(p.cap_color, 0.12)
	p.cap_asymmetry = rng.randf_range(0.03, 0.22)
	p.cap_curvature = rng.randf()
	var shapes := [Shape.DOME, Shape.DOME, Shape.BELL, Shape.PARASOL, Shape.FUNNEL, Shape.WAVY, Shape.SPIRE]
	p.cap_shape = shapes[rng.randi() % shapes.size()]
	match size_class:
		"small":
			p.stem_height = rng.randf_range(0.25, 0.7)
			p.stem_width = rng.randf_range(0.04, 0.08)
			p.cap_radius = rng.randf_range(0.18, 0.4)
			p.cap_height = p.cap_radius * rng.randf_range(0.5, 1.1)
			p.stem_bend = rng.randf_range(0.0, 0.15)
			p.cap_segments = 7
			p.detail = 0.3
			p.spots = rng.randi_range(0, 2)
			p.emission_intensity = rng.randf_range(0.7, 1.0)
		"medium":
			p.stem_height = rng.randf_range(1.2, 3.2)
			p.stem_width = rng.randf_range(0.12, 0.25)
			p.cap_radius = rng.randf_range(0.7, 1.6)
			p.cap_height = p.cap_radius * rng.randf_range(0.45, 0.9)
			p.stem_bend = rng.randf_range(0.1, 0.7)
			p.cap_segments = 16
			p.spots = rng.randi_range(3, 8)
			p.emission_intensity = rng.randf_range(0.6, 0.9)
		"giant":
			p.stem_height = rng.randf_range(9.0, 18.0)
			p.stem_width = rng.randf_range(0.8, 1.5)
			p.cap_radius = rng.randf_range(5.0, 9.0)
			p.cap_height = p.cap_radius * rng.randf_range(0.35, 0.6)
			p.stem_bend = rng.randf_range(0.8, 3.5)
			p.cap_segments = 32
			p.spots = rng.randi_range(8, 16)
			p.emission_intensity = rng.randf_range(0.6, 0.85)
			var big_shapes := [Shape.DOME, Shape.PARASOL, Shape.WAVY, Shape.FUNNEL, Shape.DOME]
			p.cap_shape = big_shapes[rng.randi() % big_shapes.size()]
			# Big stems are seen up close: richer and darker so they don't bloom.
			p.stem_color = Color(0.62, 0.52, 0.85).lerp(p.cap_color, 0.3).darkened(0.1)
		"twisted":
			p.stem_height = rng.randf_range(3.5, 7.0)
			p.stem_width = rng.randf_range(0.25, 0.45)
			p.cap_radius = rng.randf_range(1.2, 2.4)
			p.cap_height = p.cap_radius * rng.randf_range(0.6, 1.2)
			p.stem_bend = rng.randf_range(1.0, 2.5)
			p.stem_twist = rng.randf_range(0.4, 0.9)
			p.cap_segments = 20
			p.cap_shape = [Shape.BELL, Shape.SPIRE, Shape.DOME][rng.randi() % 3]
			p.spots = rng.randi_range(4, 10)
		"floating":
			p.floating = true
			p.stem_height = rng.randf_range(0.2, 0.6)
			p.stem_width = rng.randf_range(0.08, 0.15)
			p.cap_radius = rng.randf_range(0.8, 1.8)
			p.cap_height = p.cap_radius * rng.randf_range(0.6, 1.0)
			p.cap_shape = [Shape.DOME, Shape.PUFFBALL, Shape.BELL][rng.randi() % 3]
			p.tendrils = rng.randi_range(4, 8)
			p.cap_segments = 16
			p.spots = rng.randi_range(2, 6)
			p.emission_intensity = 1.0
	return p


## Several mushrooms sprouting from one point. Returns the same info dict as
## build() describing the tallest member.
static func build_cluster(rng: RandomNumberGenerator, biome: BiomeData, count: int, scale: float) -> Dictionary:
	var kit := MeshKit.new()
	var main_info: Dictionary = {}
	for i in count:
		var p := random_params(rng, biome, "medium")
		var s := scale * (1.0 if i == 0 else rng.randf_range(0.45, 0.8))
		p.stem_height *= s
		p.stem_width *= s
		p.cap_radius *= s
		p.cap_height *= s
		p.stem_bend = rng.randf_range(0.3, 1.0) * s
		var off := Vector3.ZERO if i == 0 else Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized() * rng.randf_range(0.3, 0.9) * scale
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU), off)
		var info := build_into(kit, p, xf)
		if i == 0:
			main_info = info
	main_info["mesh"] = kit.commit(MaterialLib.mushroom())
	return main_info
