class_name Scatter
extends RefCounted
## Controlled procedural placement. Produces transforms that respect spacing,
## slope limits, height bands, exclusion zones and a hard count limit.
##
## Usage:
##   var s := Scatter.new(terrain, rng)
##   s.exclude_circle(Vector3(0,0,0), 12.0)
##   var xforms := s.place({"count": 200, "spacing": 3.0, "max_slope": 0.4})

var terrain: Object
var rng: RandomNumberGenerator
var _circles: Array[Vector4] = []
var _occupied: Dictionary = {}
var _cell: float = 2.0


func _init(terrain_obj: Object, random: RandomNumberGenerator) -> void:
	terrain = terrain_obj
	rng = random


## Excludes a circle (x, z, radius). Used for buildings, paths, landmarks.
func exclude_circle(center: Vector3, radius: float) -> void:
	_circles.append(Vector4(center.x, center.z, radius, 0))


func is_excluded(p: Vector3, margin: float = 0.0) -> bool:
	for c: Vector4 in _circles:
		if Vector2(p.x - c.x, p.z - c.y).length() < c.z + margin:
			return true
	return false


## Marks a position as occupied for spacing checks across multiple passes.
func occupy(p: Vector3, radius: float) -> void:
	var cells := int(ceil(radius / _cell))
	var cx := int(floor(p.x / _cell))
	var cz := int(floor(p.z / _cell))
	for x in range(cx - cells, cx + cells + 1):
		for z in range(cz - cells, cz + cells + 1):
			var key := Vector2i(x, z)
			var prev: float = _occupied.get(key, 0.0)
			_occupied[key] = maxf(prev, radius)


func _spacing_ok(p: Vector3, spacing: float) -> bool:
	var cells := int(ceil(spacing / _cell)) + 1
	var cx := int(floor(p.x / _cell))
	var cz := int(floor(p.z / _cell))
	for x in range(cx - cells, cx + cells + 1):
		for z in range(cz - cells, cz + cells + 1):
			var key := Vector2i(x, z)
			if _occupied.has(key):
				var cell_center := Vector2((x + 0.5) * _cell, (z + 0.5) * _cell)
				if cell_center.distance_to(Vector2(p.x, p.z)) < spacing + float(_occupied[key]) * 0.5:
					return false
	return true


## Options: count, spacing, max_slope (1 - normal.y), min_height, max_height,
## area (Rect2 in xz), center/radius (circle area), path_margin, scale (Vector2),
## density_map (Callable(Vector3)->float 0..1), attempts_per_item, align_to_normal,
## occupy (bool, default true).
func place(opts: Dictionary) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	var count := int(opts.get("count", 50))
	var spacing := float(opts.get("spacing", 2.0))
	var max_slope := float(opts.get("max_slope", 0.35))
	var min_h := float(opts.get("min_height", -INF))
	var max_h := float(opts.get("max_height", INF))
	var path_margin := float(opts.get("path_margin", 1.5))
	var scale_range: Vector2 = opts.get("scale", Vector2.ONE)
	var density: Callable = opts.get("density_map", Callable())
	var attempts := count * int(opts.get("attempts_per_item", 12))
	var align := bool(opts.get("align_to_normal", false))
	var do_occupy := bool(opts.get("occupy", true))
	var has_circle := opts.has("radius")
	var center: Vector3 = opts.get("center", Vector3.ZERO)
	var radius := float(opts.get("radius", 0.0))
	var inner := float(opts.get("inner_radius", 0.0))
	var area: Rect2 = opts.get("area", Rect2(-100, -100, 200, 200))
	while out.size() < count and attempts > 0:
		attempts -= 1
		var p: Vector3
		if has_circle:
			var a := rng.randf() * TAU
			var r := sqrt(rng.randf_range(inner * inner / maxf(radius * radius, 0.001), 1.0)) * radius
			p = center + Vector3(cos(a) * r, 0, sin(a) * r)
		else:
			p = Vector3(rng.randf_range(area.position.x, area.end.x), 0, rng.randf_range(area.position.y, area.end.y))
		if is_excluded(p):
			continue
		if terrain.call("path_distance", p) < path_margin:
			continue
		if density.is_valid() and rng.randf() > float(density.call(p)):
			continue
		var h: float = terrain.call("height_at", p.x, p.z)
		if h < min_h or h > max_h:
			continue
		var n: Vector3 = terrain.call("normal_at", p.x, p.z)
		if 1.0 - n.y > max_slope:
			continue
		p.y = h
		if not _spacing_ok(p, spacing):
			continue
		var s := rng.randf_range(scale_range.x, scale_range.y)
		var basis := Basis(Vector3.UP, rng.randf() * TAU)
		if align:
			var up := n
			var x := up.cross(basis.z).normalized()
			var z := x.cross(up).normalized()
			basis = Basis(x, up, z)
		basis = basis.scaled(Vector3.ONE * s)
		out.append(Transform3D(basis, p))
		if do_occupy:
			occupy(p, spacing * 0.5)
	return out
