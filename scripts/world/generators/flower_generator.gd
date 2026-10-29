class_name FlowerGenerator
extends RefCounted
## Oversized dream flowers built as small node rigs so petals can open,
## close and the head can turn towards the player (see DreamFlower).

const LOD_DISTANCE := 26.0

static var _petal_cache: Dictionary = {}


static func _near_only(mi: MeshInstance3D) -> void:
	mi.visibility_range_end = LOD_DISTANCE
	mi.visibility_range_end_margin = 2.0


## Curved spoon-shaped petal mesh, length along +Z, cupped upwards.
static func petal_mesh(length: float, width: float, base_color: Color, tip_color: Color, glow_tip: bool) -> ArrayMesh:
	var key := "%0.2f:%0.2f:%s:%s:%s" % [length, width, base_color.to_html(), tip_color.to_html(), glow_tip]
	if _petal_cache.has(key):
		return _petal_cache[key]
	var mesh := petal_kit(length, width, base_color, tip_color, glow_tip).commit(MaterialLib.plant())
	_petal_cache[key] = mesh
	return mesh


static func petal_kit(length: float, width: float, base_color: Color, tip_color: Color, glow_tip: bool) -> MeshKit:
	var kit := MeshKit.new()
	var rows := 7
	var cols := 5
	var grid: Array[PackedInt32Array] = []
	for r in rows + 1:
		var v := float(r) / rows
		var row := PackedInt32Array()
		var w := width * sin(pow(v, 0.8) * PI) * (1.0 - 0.25 * v) + width * 0.08
		for c in cols + 1:
			var u := float(c) / cols * 2.0 - 1.0
			var cup := (u * u) * w * 0.35
			var curl := sin(v * PI * 0.8) * length * 0.12
			var p := Vector3(u * w, cup + curl - v * v * length * 0.08, v * length)
			var col := base_color.lerp(tip_color, smoothstep(0.2, 1.0, v))
			col.a = (smoothstep(0.7, 1.0, v) * 0.9 if glow_tip else 0.05) + 0.1 * (1.0 - absf(u)) * v
			row.append(kit.add_vertex(p, col, Vector2((u + 1.0) * 0.5, v)))
		grid.append(row)
	for r in rows:
		for c in cols:
			kit.add_quad(grid[r][c], grid[r][c + 1], grid[r + 1][c + 1], grid[r + 1][c])
	# Back side (double-sided without disabling culling globally).
	var back := MeshKit.new()
	back.vertices = kit.vertices.duplicate()
	back.colors = kit.colors.duplicate()
	back.uvs = kit.uvs.duplicate()
	for i in range(0, kit.indices.size(), 3):
		back.add_tri(kit.indices[i], kit.indices[i + 2], kit.indices[i + 1])
	for i in back.vertices.size():
		back.vertices[i] -= Vector3(0, 0.01, 0)
		back.colors[i] = back.colors[i].darkened(0.25)
	kit.merge(back)
	return kit


## Builds a flower rig. Returns the root Node3D (script DreamFlower attached).
static func build(rng: RandomNumberGenerator, biome: BiomeData, height: float, head_size: float) -> Node3D:
	var root := Node3D.new()
	root.set_script(load("res://scripts/world/dream_flower.gd"))
	var petal_color := biome.pick(biome.flower_colors, rng, Color(1.0, 0.4, 0.7))
	var tip_color := biome.pick(biome.flower_colors, rng, Color(1.0, 0.9, 0.3))
	var center_color := Color(1.0, 0.88, 0.3) if rng.randf() > 0.4 else biome.pick(biome.mushroom_glow, rng, Color(0.3, 1.0, 0.9))
	# Stem with leaves.
	var stem := MeshKit.new()
	var bend := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized() * height * 0.15
	var path := PackedVector3Array()
	var radii := PackedFloat32Array()
	for i in 9:
		var t := float(i) / 8.0
		path.append(Vector3(bend.x * t * t, height * t, bend.z * t * t))
		radii.append(head_size * 0.07 * (1.0 - 0.4 * t) + 0.02)
	var stem_col := biome.grass_color.lightened(0.15)
	stem.tube(path, radii, 6, func(t: float) -> Color:
		var c := stem_col.lerp(biome.grass_tip_color, t)
		c.a = 0.05
		return c, true, true)
	for l in 2:
		var lt := rng.randf_range(0.2, 0.5)
		var base := path[int(lt * 8)]
		var leaf_dir := Vector3(cos(l * PI + rng.randf()), 0.35, sin(l * PI + rng.randf())).normalized()
		var lp := PackedVector3Array([base, base + leaf_dir * head_size * 0.6 + Vector3.UP * head_size * 0.2, base + leaf_dir * head_size * 1.2])
		var lr := PackedFloat32Array([head_size * 0.03, head_size * 0.12, head_size * 0.01])
		stem.tube(MeshKit.spline(lp, 3), _resample(lr, 7), 4, func(_t: float) -> Color:
			var c := stem_col.darkened(0.1)
			c.a = 0.05
			return c, false, true)
	var far := MeshKit.new()
	far.merge(stem)
	var stem_mi := MeshInstance3D.new()
	stem_mi.mesh = stem.commit(MaterialLib.plant())
	stem_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(stem_mi)
	# Head.
	var head := Node3D.new()
	head.name = "Head"
	head.position = path[path.size() - 1]
	root.add_child(head)
	var petals := rng.randi_range(5, 9)
	var pm := petal_mesh(head_size, head_size * 0.42, petal_color, tip_color, true)
	var pk := petal_kit(head_size, head_size * 0.42, petal_color, tip_color, true)
	for i in petals:
		var pivot := Node3D.new()
		pivot.rotation.y = TAU * float(i) / petals
		head.add_child(pivot)
		var mi := MeshInstance3D.new()
		mi.mesh = pm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.name = "Petal"
		_near_only(mi)
		pivot.add_child(mi)
		far.merge(pk, Transform3D(Basis(Vector3.UP, TAU * float(i) / petals) * Basis(Vector3.RIGHT, -0.6), head.position))
	var center := MeshKit.new()
	var cc := center_color
	center.ellipsoid(Vector3(0, head_size * 0.05, 0), Vector3(head_size * 0.22, head_size * 0.14, head_size * 0.22), Color(cc.r, cc.g, cc.b, 1.0), 5, 10)
	for s in 8:
		var a := TAU * s / 8.0
		center.ellipsoid(Vector3(cos(a), 2.2, sin(a)) * head_size * 0.18, Vector3.ONE * head_size * 0.035, Color(1, 1, 1, 1), 3, 6)
	far.merge(center, Transform3D(Basis.IDENTITY, head.position))
	var cmi := MeshInstance3D.new()
	cmi.mesh = center.commit(MaterialLib.plant())
	cmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_near_only(cmi)
	head.add_child(cmi)
	_near_only(stem_mi)
	# Far LOD: the whole flower merged into one static mesh (one draw call).
	var far_mi := MeshInstance3D.new()
	far_mi.name = "FarLOD"
	far_mi.mesh = far.commit(MaterialLib.plant())
	far_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	far_mi.visibility_range_begin = LOD_DISTANCE
	far_mi.visibility_range_begin_margin = 2.0
	far_mi.visibility_range_end = 140.0
	root.add_child(far_mi)
	root.set("phase", rng.randf() * TAU)
	root.set("speed", rng.randf_range(0.25, 0.6))
	return root


static func _resample(values: PackedFloat32Array, count: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for i in count:
		var t := float(i) / (count - 1) * (values.size() - 1)
		var a := int(floor(t))
		var b := mini(a + 1, values.size() - 1)
		out.append(lerpf(values[a], values[b], t - a))
	return out
