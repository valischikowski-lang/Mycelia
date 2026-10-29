class_name Props
extends RefCounted
## Helpers that turn generator output into world nodes with sensible
## collision, shadows and LOD ranges.


static func mesh_instance(mesh: Mesh, xform: Transform3D, shadows: bool = true, vis_range: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.transform = xform
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if vis_range > 0.0:
		mi.visibility_range_end = vis_range
		mi.visibility_range_end_margin = vis_range * 0.1
	return mi


## A mushroom with collision: stem capsules along its path + convex cap.
static func mushroom_body(info: Dictionary, xform: Transform3D, walkable_cap: bool = true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.transform = xform
	var mi := MeshInstance3D.new()
	mi.mesh = info["mesh"]
	mi.name = "Mesh"
	body.add_child(mi)
	var path: PackedVector3Array = info.get("stem_path", PackedVector3Array())
	var sr := float(info.get("stem_radius", 0.3)) * 1.15
	if path.size() >= 3:
		var segs := 3
		for s in segs:
			var a := path[int(float(s) / segs * (path.size() - 1))]
			var b := path[int(float(s + 1) / segs * (path.size() - 1))]
			add_capsule(body, a, b, sr * (1.25 - 0.25 * s))
	if walkable_cap and info.has("cap_points"):
		var shape := ConvexPolygonShape3D.new()
		shape.points = info["cap_points"]
		var cs := CollisionShape3D.new()
		cs.shape = shape
		body.add_child(cs)
	return body


static func add_capsule(body: Node3D, a: Vector3, b: Vector3, radius: float) -> void:
	var length := a.distance_to(b)
	if length < 0.01:
		return
	var cap := CapsuleShape3D.new()
	cap.radius = radius
	cap.height = length + radius * 2.0
	var cs := CollisionShape3D.new()
	cs.shape = cap
	var up := (b - a).normalized()
	var ref := Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var z := ref.cross(up).normalized()
	var x := up.cross(z).normalized()
	cs.transform = Transform3D(Basis(x, up, z), (a + b) * 0.5)
	body.add_child(cs)


static func add_cylinder(body: Node3D, center: Vector3, radius: float, height: float) -> void:
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = height
	var cs := CollisionShape3D.new()
	cs.shape = cyl
	cs.position = center
	body.add_child(cs)


static func add_box(body: Node3D, center: Vector3, size: Vector3, basis: Basis = Basis.IDENTITY) -> void:
	var box := BoxShape3D.new()
	box.size = size
	var cs := CollisionShape3D.new()
	cs.shape = box
	cs.transform = Transform3D(basis, center)
	body.add_child(cs)


static func static_body(mesh: Mesh, xform: Transform3D) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.transform = xform
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.name = "Mesh"
	body.add_child(mi)
	return body


static func multimesh(mesh: Mesh, xforms: Array[Transform3D], shadows: bool = false, vis_range: float = 0.0) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if vis_range > 0.0:
		mmi.visibility_range_end = vis_range
	return mmi


## Grass tuft: a few curved blades fanning out, tips brighter.
static func grass_tuft_mesh(biome: BiomeData, seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var kit := MeshKit.new()
	var blades := 3
	for b in blades:
		var a := TAU * b / blades + rng.randf() * 0.6
		var lean := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.1, 0.35)
		var h := rng.randf_range(0.35, 0.75)
		var w := 0.07
		var side := Vector3(-sin(a), 0, cos(a)) * w
		var base := Vector3(cos(a), 0, sin(a)) * 0.05
		var prev := PackedInt32Array()
		for k in 3:
			var t := float(k) / 2.0
			var c := biome.grass_color.lerp(biome.grass_tip_color, t)
			c.a = t * t * 0.5
			var p := base + lean * t * t + Vector3.UP * h * t
			var sw := side * (1.0 - t * 0.85)
			var l := kit.add_vertex(p - sw, c)
			var r := kit.add_vertex(p + sw, c)
			if prev.size() == 2:
				kit.add_quad(prev[0], l, r, prev[1])
				kit.add_quad(prev[1], r, l, prev[0])
			prev = PackedInt32Array([l, r])
	return kit.commit(MaterialLib.grass())


## Noisy rock blob.
static func rock_mesh(rng: RandomNumberGenerator, biome: BiomeData, size: Vector3, glow_band: bool = false) -> ArrayMesh:
	var kit := MeshKit.new()
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = 0.9
	var rc := biome.rock_color.lerp(biome.moss_color, rng.randf() * 0.3)
	var vein := biome.vein_color
	kit.ellipsoid(Vector3(0, size.y * 0.3, 0), size, rc, 7, 11, Basis(Vector3.UP, rng.randf() * TAU), noise, 0.3,
		func(d: Vector3) -> Color:
			var c := rc.lerp(rc.lightened(0.3), d.y * 0.5 + 0.5)
			c = c.lerp(biome.moss_color, smoothstep(0.5, 0.9, d.y) * 0.6)
			c.a = 0.0
			if glow_band and absf(d.y - 0.1) < 0.08:
				c = c.lerp(vein, 0.7)
				c.a = 0.8
			return c)
	return kit.commit(MaterialLib.stone())
