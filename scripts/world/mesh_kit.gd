class_name MeshKit
extends RefCounted
## Lightweight mesh accumulator used by every procedural generator.
## Builds indexed geometry with vertex colors (alpha = emission mask) and
## computes smooth, area-weighted normals on commit.
##
## Winding: Godot treats clockwise triangles as front faces. ring() orders
## points from +X towards +Z, i.e. clockwise when seen from above. bridge()
## (unflipped) faces outward when the second ring lies further along +Y;
## lathe()/ellipsoid() walk profiles top-to-bottom and use flipped bridges.

var vertices := PackedVector3Array()
var colors := PackedColorArray()
var uvs := PackedVector2Array()
var indices := PackedInt32Array()


func vertex_count() -> int:
	return vertices.size()


func add_vertex(p: Vector3, c: Color, uv: Vector2 = Vector2.ZERO) -> int:
	vertices.append(p)
	colors.append(c)
	uvs.append(uv)
	return vertices.size() - 1


func add_tri(a: int, b: int, c: int) -> void:
	indices.append(a)
	indices.append(b)
	indices.append(c)


## Quad from four indices in clockwise order (as seen from the front).
func add_quad(a: int, b: int, c: int, d: int) -> void:
	add_tri(a, b, c)
	add_tri(a, c, d)


## A circle of points around `center` in the plane defined by `basis`
## (basis.x / basis.z span the ring, basis.y is the ring normal).
static func ring(center: Vector3, basis: Basis, radius_x: float, radius_z: float, sides: int, phase: float = 0.0, radius_mod: Callable = Callable()) -> PackedVector3Array:
	var pts := PackedVector3Array()
	for i in sides:
		var a := phase + TAU * float(i) / float(sides)
		var r := 1.0
		if radius_mod.is_valid():
			r = float(radius_mod.call(a))
		pts.append(center + basis.x * cos(a) * radius_x * r + basis.z * sin(a) * radius_z * r)
	return pts


## Adds a ring of vertices and returns their indices.
func add_ring(points: PackedVector3Array, color: Color, v: float = 0.0) -> PackedInt32Array:
	var idx := PackedInt32Array()
	var n := points.size()
	for i in n:
		idx.append(add_vertex(points[i], color, Vector2(float(i) / n, v)))
	return idx


## Connects two rings of equal size into a closed band. `flip` reverses facing.
func bridge(r0: PackedInt32Array, r1: PackedInt32Array, flip: bool = false) -> void:
	var n := r0.size()
	for i in n:
		var j := (i + 1) % n
		if flip:
			add_quad(r0[i], r1[i], r1[j], r0[j])
		else:
			add_quad(r0[i], r0[j], r1[j], r1[i])


## Closes a ring with a fan to a center vertex.
func fan(ring_idx: PackedInt32Array, center_idx: int, flip: bool = false) -> void:
	var n := ring_idx.size()
	for i in n:
		var j := (i + 1) % n
		if flip:
			add_tri(center_idx, ring_idx[j], ring_idx[i])
		else:
			add_tri(center_idx, ring_idx[i], ring_idx[j])


## Sweeps a tube along `path` with per-point radius and color.
## Returns the index rings so callers can attach caps.
func tube(path: PackedVector3Array, radii: PackedFloat32Array, sides: int, color_fn: Callable, close_start: bool = true, close_end: bool = true, wobble: Callable = Callable()) -> Array[PackedInt32Array]:
	var rings: Array[PackedInt32Array] = []
	var n := path.size()
	var prev_up := Vector3.BACK
	for i in n:
		var t := float(i) / float(maxi(1, n - 1))
		var tangent: Vector3
		if i == 0:
			tangent = (path[1] - path[0]).normalized()
		elif i == n - 1:
			tangent = (path[i] - path[i - 1]).normalized()
		else:
			tangent = (path[i + 1] - path[i - 1]).normalized()
		# Parallel-transport style frame to avoid twisting.
		var side := tangent.cross(prev_up)
		if side.length_squared() < 1e-6:
			side = tangent.cross(Vector3.RIGHT)
		side = side.normalized()
		var up := side.cross(tangent).normalized()
		prev_up = up
		var b := Basis(side, tangent, up)
		var mod := Callable()
		if wobble.is_valid():
			mod = func(a: float) -> float: return float(wobble.call(a, t))
		var pts := ring(path[i], b, radii[i], radii[i], sides, 0.0, mod)
		rings.append(add_ring(pts, color_fn.call(t) as Color, t))
	for i in range(n - 1):
		bridge(rings[i], rings[i + 1])
	if close_start:
		var c0 := add_vertex(path[0], color_fn.call(0.0) as Color)
		fan(rings[0], c0, true)
	if close_end:
		var c1 := add_vertex(path[n - 1], color_fn.call(1.0) as Color)
		fan(rings[n - 1], c1)
	return rings


## Ellipsoid (UV sphere) with optional noise displacement.
func ellipsoid(center: Vector3, radii: Vector3, color: Color, rings_n: int = 8, sides: int = 12, basis: Basis = Basis.IDENTITY, noise: FastNoiseLite = null, noise_amp: float = 0.0, color_fn: Callable = Callable()) -> void:
	var top := add_vertex(center + basis * Vector3(0, radii.y, 0), _c(color_fn, Vector3.UP, color))
	var ring_list: Array[PackedInt32Array] = []
	for r in range(1, rings_n):
		var phi := PI * float(r) / float(rings_n)
		var y := cos(phi)
		var s := sin(phi)
		var idx := PackedInt32Array()
		for i in sides:
			var a := TAU * float(i) / float(sides)
			var dir := Vector3(cos(a) * s, y, sin(a) * s)
			var disp := 1.0
			if noise:
				disp += noise.get_noise_3dv(dir * 3.0 + center) * noise_amp
			var p := center + basis * (Vector3(dir.x * radii.x, dir.y * radii.y, dir.z * radii.z) * disp)
			idx.append(add_vertex(p, _c(color_fn, dir, color)))
		ring_list.append(idx)
	var bottom := add_vertex(center + basis * Vector3(0, -radii.y, 0), _c(color_fn, Vector3.DOWN, color))
	fan(ring_list[0], top)
	for r in range(ring_list.size() - 1):
		bridge(ring_list[r], ring_list[r + 1], true)
	fan(ring_list[ring_list.size() - 1], bottom, true)


func _c(color_fn: Callable, dir: Vector3, fallback: Color) -> Color:
	if color_fn.is_valid():
		return color_fn.call(dir) as Color
	return fallback


## Lathe: revolves a 2D profile (x = radius, y = height) around the Y axis.
## radius_mod(angle, t) lets callers add asymmetry and wavy edges.
func lathe(profile: PackedVector2Array, sides: int, origin: Vector3, basis: Basis, color_fn: Callable, radius_mod: Callable = Callable(), close_top: bool = true, close_bottom: bool = false) -> Array[PackedInt32Array]:
	var rings: Array[PackedInt32Array] = []
	var n := profile.size()
	for i in n:
		var t := float(i) / float(maxi(1, n - 1))
		var pr := profile[i]
		var idx := PackedInt32Array()
		for s in sides:
			var a := TAU * float(s) / float(sides)
			var r := pr.x
			if radius_mod.is_valid():
				r *= float(radius_mod.call(a, t))
			var local := Vector3(cos(a) * r, pr.y, sin(a) * r)
			idx.append(add_vertex(origin + basis * local, color_fn.call(t, a) as Color, Vector2(float(s) / sides, t)))
		rings.append(idx)
	for i in range(n - 1):
		bridge(rings[i], rings[i + 1], true)
	if close_top:
		var c := add_vertex(origin + basis * Vector3(0, profile[0].y, 0), color_fn.call(0.0, 0.0) as Color)
		fan(rings[0], c)
	if close_bottom:
		var c2 := add_vertex(origin + basis * Vector3(0, profile[n - 1].y, 0), color_fn.call(1.0, 0.0) as Color)
		fan(rings[n - 1], c2, true)
	return rings


## Hexagonal (or n-gonal) crystal prism with a pointed tip.
func crystal_prism(base: Vector3, basis: Basis, height: float, radius: float, sides: int, color: Color, tip_ratio: float = 0.3) -> void:
	var r0 := ring(base, basis, radius, radius, sides)
	var shaft_top := base + basis.y * height * (1.0 - tip_ratio)
	var r1 := ring(shaft_top, basis, radius * 0.95, radius * 0.95, sides)
	var i0 := add_ring(r0, Color(color.r * 0.6, color.g * 0.6, color.b * 0.8, 0.2))
	var i1 := add_ring(r1, Color(color.r, color.g, color.b, 0.7))
	bridge(i0, i1)
	var tip := add_vertex(base + basis.y * height, Color(color.r * 1.2, color.g * 1.2, color.b * 1.2, 1.0))
	fan(i1, tip)
	var bottom := add_vertex(base - basis.y * radius * 0.3, color * 0.5)
	fan(i0, bottom, true)


## Appends another kit (with an optional transform).
func merge(other: MeshKit, xform: Transform3D = Transform3D.IDENTITY) -> void:
	var offset := vertices.size()
	for i in other.vertices.size():
		vertices.append(xform * other.vertices[i])
		colors.append(other.colors[i])
		uvs.append(other.uvs[i])
	for i in other.indices:
		indices.append(i + offset)


func compute_normals() -> PackedVector3Array:
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	for t in range(0, indices.size(), 3):
		var a := indices[t]
		var b := indices[t + 1]
		var c := indices[t + 2]
		# Godot front faces are clockwise; this cross product points outward.
		var n := (vertices[c] - vertices[a]).cross(vertices[b] - vertices[a])
		normals[a] += n
		normals[b] += n
		normals[c] += n
	for i in normals.size():
		normals[i] = normals[i].normalized() if normals[i].length_squared() > 1e-12 else Vector3.UP
	return normals


func commit(material: Material = null, existing: ArrayMesh = null) -> ArrayMesh:
	var mesh := existing if existing else ArrayMesh.new()
	if vertices.is_empty():
		return mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = compute_normals()
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if material:
		mesh.surface_set_material(mesh.get_surface_count() - 1, material)
	return mesh


## Builds a smooth bezier-ish path from control points (Catmull-Rom).
static func spline(points: PackedVector3Array, samples_per_segment: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	var n := points.size()
	if n < 2:
		return points
	for i in range(n - 1):
		var p0 := points[maxi(i - 1, 0)]
		var p1 := points[i]
		var p2 := points[i + 1]
		var p3 := points[mini(i + 2, n - 1)]
		for s in samples_per_segment:
			var t := float(s) / float(samples_per_segment)
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	out.append(points[n - 1])
	return out
