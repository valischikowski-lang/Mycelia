class_name DreamTerrain
extends Node3D
## Analytic terrain: a deterministic height function composed of noise,
## a surrounding rim, hills, flattened plazas, basins and sunken paths.
## Generates chunked render meshes (for frustum culling) and a HeightMapShape3D.
## Generators query height_at()/normal_at()/path_distance() for placement.

@export var size: float = 300.0
@export var cell: float = 2.0
@export var chunks: int = 5
@export var noise_amplitude: float = 2.2
@export var noise_frequency: float = 0.011
@export var rim_start: float = 112.0
@export var rim_end: float = 150.0
@export var rim_height: float = 42.0

var biome: BiomeData
## Vector4(x, z, radius, height)
var hills: Array[Vector4] = []
## Vector4(x, z, radius, height) — flatten towards height inside radius.
var flats: Array[Vector4] = []
## Vector4(x, z, radius, depth)
var basins: Array[Vector4] = []
## Each: {"points": PackedVector2Array, "width": float}
var paths: Array[Dictionary] = []
## Vector3(angle_radians, width_radians, depth_fraction) — notches in the rim.
var rim_passes: Array[Vector3] = []
var water_level: float = -0.6

## Path weight of the last _color_at() sample (stored in UV.x for cobbles).
var _last_path_w: float = 0.0
var _noise := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _rim_noise := FastNoiseLite.new()


func setup(seed_value: int) -> void:
	_noise.seed = seed_value
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = noise_frequency
	_noise.fractal_octaves = 3
	_detail.seed = seed_value + 11
	_detail.frequency = 0.08
	_rim_noise.seed = seed_value + 23
	_rim_noise.frequency = 0.05


func height_at(x: float, z: float) -> float:
	var h := _noise.get_noise_2d(x, z) * noise_amplitude
	h += _detail.get_noise_2d(x, z) * 0.25
	for b: Vector4 in hills:
		var d := Vector2(x - b.x, z - b.y).length()
		if d < b.z:
			var k := 1.0 - d / b.z
			h += b.w * k * k * (3.0 - 2.0 * k)
	for f: Vector4 in flats:
		var d := Vector2(x - f.x, z - f.y).length()
		if d < f.z:
			var w := smoothstep(f.z, f.z * 0.55, d)
			h = lerpf(h, f.w, w)
	for bs: Vector4 in basins:
		var d := Vector2(x - bs.x, z - bs.y).length()
		if d < bs.z:
			h -= bs.w * smoothstep(bs.z, bs.z * 0.35, d)
	var pd := path_distance(Vector3(x, 0, z))
	if pd < 4.0:
		h -= 0.18 * smoothstep(4.0, 1.0, pd)
	# Rim.
	var r := Vector2(x, z).length()
	if r > rim_start:
		var ang := atan2(x, -z)
		var rim_h := rim_height
		for pass_: Vector3 in rim_passes:
			var da := absf(wrapf(ang - pass_.x, -PI, PI))
			rim_h *= lerpf(1.0, pass_.z, smoothstep(pass_.y, pass_.y * 0.4, da))
		var k := smoothstep(rim_start, rim_end, r)
		var spires := maxf(0.0, _rim_noise.get_noise_2d(x, z)) * rim_h * 0.6
		h += (k * k) * rim_h + spires * k
	return h


func normal_at(x: float, z: float) -> Vector3:
	var e := 0.75
	var hx := height_at(x + e, z) - height_at(x - e, z)
	var hz := height_at(x, z + e) - height_at(x, z - e)
	return Vector3(-hx, 2.0 * e, -hz).normalized()


const PATH_QUERY_RANGE := 8.0


func path_distance(p: Vector3) -> float:
	var best := INF
	var q := Vector2(p.x, p.z)
	for path: Dictionary in paths:
		if not path.has("bounds"):
			var pts0: PackedVector2Array = path["points"]
			var rect := Rect2(pts0[0], Vector2.ZERO)
			for pt: Vector2 in pts0:
				rect = rect.expand(pt)
			path["bounds"] = rect.grow(PATH_QUERY_RANGE + float(path.get("width", 3.0)))
		if not (path["bounds"] as Rect2).has_point(q):
			best = minf(best, PATH_QUERY_RANGE)
			continue
		var pts: PackedVector2Array = path["points"]
		var half := float(path.get("width", 3.0)) * 0.5
		for i in range(pts.size() - 1):
			var d := Geometry2D.get_closest_point_to_segment(q, pts[i], pts[i + 1]).distance_to(q) - half
			best = minf(best, d)
	return best


func _color_at(x: float, z: float, h: float, n: Vector3) -> Color:
	var b := biome
	var moss_n := _detail.get_noise_2d(x * 0.35, z * 0.35)
	var c := b.grass_color.lerp(b.grass_tip_color, clampf(0.3 + _noise.get_noise_2d(x * 2.0, z * 2.0) * 0.5, 0.0, 0.6))
	c = c.lerp(b.moss_color, smoothstep(0.15, 0.45, moss_n) * 0.75)
	var vein_mask := 1.0
	# Rock on slopes and the rim.
	var slope := 1.0 - n.y
	var rockiness := clampf(smoothstep(0.25, 0.55, slope) + smoothstep(rim_start + 8.0, rim_end, Vector2(x, z).length()) * 0.8, 0.0, 1.0)
	c = c.lerp(b.rock_color, rockiness)
	vein_mask -= rockiness * 0.8
	# Lake shores glow softly.
	for bs: Vector4 in basins:
		var d := Vector2(x - bs.x, z - bs.y).length()
		if d < bs.z * 1.1:
			var shore := smoothstep(bs.z * 1.1, bs.z * 0.8, d)
			c = c.lerp(b.path_color.lerp(b.vein_color, 0.25), shore * 0.55)
	# Paths.
	var pd := path_distance(Vector3(x, 0, z))
	_last_path_w = 0.0
	if pd < 1.5:
		var w := smoothstep(1.5, -0.5, pd)
		c = c.lerp(b.path_color, w)
		vein_mask -= w
		_last_path_w = w
	c.a = clampf(vein_mask, 0.0, 1.0)
	return c


## Builds render chunks + collision. Call after features are configured.
func build(material: Material) -> void:
	var samples := int(size / cell) + 1
	var half := size * 0.5
	var heights := PackedFloat32Array()
	heights.resize(samples * samples)
	for iz in samples:
		for ix in samples:
			heights[iz * samples + ix] = height_at(-half + ix * cell, -half + iz * cell)
	# Render chunks.
	var per_chunk := int(ceil(float(samples - 1) / chunks))
	for cz in chunks:
		for cx in chunks:
			var x0 := cx * per_chunk
			var z0 := cz * per_chunk
			var x1 := mini(x0 + per_chunk, samples - 1)
			var z1 := mini(z0 + per_chunk, samples - 1)
			if x1 <= x0 or z1 <= z0:
				continue
			var kit := MeshKit.new()
			var w := x1 - x0 + 1
			for iz in range(z0, z1 + 1):
				for ix in range(x0, x1 + 1):
					var x := -half + ix * cell
					var z := -half + iz * cell
					var h := heights[iz * samples + ix]
					var n := _grid_normal(heights, samples, ix, iz)
					var col := _color_at(x, z, h, n)
					kit.add_vertex(Vector3(x, h, z), col, Vector2(_last_path_w, 0.0))
			for iz in range(z1 - z0):
				for ix in range(w - 1):
					var a := iz * w + ix
					var b := a + 1
					var c := a + w
					var d := c + 1
					kit.add_tri(a, b, d)
					kit.add_tri(a, d, c)
			var mi := MeshInstance3D.new()
			mi.name = "TerrainChunk_%d_%d" % [cx, cz]
			mi.mesh = kit.commit(material)
			# The ground receives shadows but casting them would double its cost.
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)
	# Collision: heightmap at the same grid, uniformly scaled by cell size.
	var body := StaticBody3D.new()
	body.name = "TerrainBody"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := HeightMapShape3D.new()
	shape.map_width = samples
	shape.map_depth = samples
	var scaled := PackedFloat32Array()
	scaled.resize(heights.size())
	for i in heights.size():
		scaled[i] = heights[i] / cell
	shape.map_data = scaled
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.scale = Vector3.ONE * cell
	# HeightMapShape3D is centered; our grid already spans -half..half.
	cs.position = Vector3(0, 0, 0)
	body.add_child(cs)
	add_child(body)


func _grid_normal(heights: PackedFloat32Array, samples: int, ix: int, iz: int) -> Vector3:
	var l := heights[iz * samples + maxi(ix - 1, 0)]
	var r := heights[iz * samples + mini(ix + 1, samples - 1)]
	var u := heights[maxi(iz - 1, 0) * samples + ix]
	var d := heights[mini(iz + 1, samples - 1) * samples + ix]
	return Vector3(l - r, 2.0 * cell, u - d).normalized()
