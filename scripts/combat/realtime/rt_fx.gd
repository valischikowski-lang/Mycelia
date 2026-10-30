class_name RtFx
extends RefCounted
## Real-time combat building blocks: telegraph decals, floating damage
## numbers, projectiles and timed area zones. All procedural and cheap.

const PLAYER_GROUP := "player"
const ENEMY_GROUP := "rt_enemy"


static func _unshaded(color: Color, additive: bool = true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.albedo_color = color
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	return m


## A flat ring/disc on the ground warning where an attack will land. It fills
## up over `time` seconds, then frees itself.
static func telegraph(parent: Node, pos: Vector3, radius: float, time: float, color: Color = Color(1.0, 0.25, 0.3)) -> Node3D:
	var root := Node3D.new()
	root.name = "Telegraph"
	parent.add_child(root)
	root.global_position = pos + Vector3.UP * 0.08
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = radius - 0.12
	tm.outer_radius = radius
	tm.rings = 32
	tm.ring_segments = 4
	ring.mesh = tm
	ring.scale.y = 0.05
	ring.material_override = _unshaded(Color(color, 0.85))
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)
	var fill := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.02
	cyl.radial_segments = 28
	fill.mesh = cyl
	fill.material_override = _unshaded(Color(color, 0.28))
	fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fill.scale = Vector3(0.05, 1, 0.05)
	root.add_child(fill)
	var tw := root.create_tween()
	tw.tween_property(fill, "scale", Vector3.ONE, time)
	tw.tween_callback(root.queue_free)
	return root


## Floating combat text (damage, "PARRY!", "MISS").
static func number(parent: Node, pos: Vector3, text: String, color: Color, big: bool = false) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = UiTheme.bold_font()
	l.font_size = 64 if big else 44
	l.outline_size = 12
	l.modulate = color
	l.outline_modulate = Color(0.05, 0.0, 0.1, 0.9)
	l.pixel_size = 0.006
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 10
	parent.add_child(l)
	l.global_position = pos + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3))
	var tw := l.create_tween()
	tw.tween_property(l, "global_position:y", l.global_position.y + 1.2, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.35)
	tw.tween_callback(l.queue_free)


## A bright burst of particles (hit sparks, explosions).
static func burst(parent: Node, pos: Vector3, color: Color, amount: int = 18, size: float = 0.12, speed: float = 4.0) -> void:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.amount = maxi(4, int(amount * Settings.particle_ratio()))
	p.lifetime = 0.55
	p.explosiveness = 0.95
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -6, 0)
	p.scale_amount_min = size * 0.5
	p.scale_amount_max = size
	var qm := QuadMesh.new()
	qm.size = Vector2.ONE
	qm.material = MaterialLib.particle(color, 4.0)
	p.mesh = qm
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)


## Damage everything of `group` inside a sphere; returns how many were hit.
static func area_hit(tree: SceneTree, center: Vector3, radius: float, group: String, hit: Dictionary, exclude: Array = []) -> int:
	var n := 0
	for node in tree.get_nodes_in_group(group):
		var t := node as Node3D
		if t == null or t in exclude or not t.is_inside_tree():
			continue
		if t.global_position.distance_to(center) <= radius + _radius_of(t):
			var h := hit.duplicate()
			h["from"] = center
			t.call("take_hit", h)
			n += 1
	return n


static func _radius_of(n: Node3D) -> float:
	var r: Variant = n.get("hit_radius")
	return float(r) if r != null else 0.5


## Nearest living target of a group inside a cone in front of `origin`.
static func nearest(tree: SceneTree, origin: Vector3, forward: Vector3, group: String, max_dist: float, min_dot: float = -1.0) -> Node3D:
	var best: Node3D = null
	var best_score := INF
	for node in tree.get_nodes_in_group(group):
		var t := node as Node3D
		if t == null or not t.is_inside_tree() or bool(t.get("dead")):
			continue
		var to := t.global_position - origin
		to.y = 0.0
		var d := to.length()
		if d > max_dist:
			continue
		var dot := forward.dot(to.normalized()) if d > 0.01 else 1.0
		if dot < min_dot:
			continue
		var score := d - dot * 3.0
		if score < best_score:
			best_score = score
			best = t
	return best


# ------------------------------------------------------------------ projectile
class Projectile extends Node3D:
	var velocity: Vector3
	var speed: float = 22.0
	var target_group: String = RtFx.ENEMY_GROUP
	var hit: Dictionary = {}
	var homing: Node3D
	var homing_turn: float = 6.0
	var life: float = 2.5
	var radius: float = 0.45
	var gravity: float = 0.0
	var color: Color = Color.WHITE
	## Called with (projectile, hit_node_or_null) when it lands.
	var on_land: Callable
	var pierce: bool = false
	var _hit_nodes: Array = []

	func _ready() -> void:
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.16
		sm.height = 0.32
		sm.radial_segments = 8
		sm.rings = 4
		mi.mesh = sm
		mi.material_override = RtFx._unshaded(Color(color, 1.0))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		var trail := CPUParticles3D.new()
		trail.amount = maxi(6, int(16 * Settings.particle_ratio()))
		trail.lifetime = 0.3
		trail.local_coords = false
		trail.gravity = Vector3.ZERO
		trail.initial_velocity_max = 0.3
		trail.scale_amount_min = 0.08
		trail.scale_amount_max = 0.16
		var qm := QuadMesh.new()
		qm.material = MaterialLib.particle(color, 3.0)
		trail.mesh = qm
		add_child(trail)

	func _physics_process(delta: float) -> void:
		life -= delta
		if life <= 0.0:
			_land(null)
			return
		if is_instance_valid(homing) and not bool(homing.get("dead")):
			var want := (homing.global_position + Vector3.UP * 0.8 - global_position).normalized() * speed
			velocity = velocity.lerp(want, minf(1.0, homing_turn * delta))
		velocity.y -= gravity * delta
		var from := global_position
		var to := from + velocity * delta
		# Terrain / walls.
		var q := PhysicsRayQueryParameters3D.create(from, to, 1)
		var res := get_world_3d().direct_space_state.intersect_ray(q)
		if not res.is_empty():
			global_position = res["position"]
			_land(null)
			return
		global_position = to
		for node in get_tree().get_nodes_in_group(target_group):
			var t := node as Node3D
			if t == null or t in _hit_nodes or bool(t.get("dead")):
				continue
			var c := t.global_position + Vector3.UP * 0.8
			if c.distance_to(global_position) <= radius + RtFx._radius_of(t):
				var h := hit.duplicate()
				h["from"] = from
				h["projectile"] = true
				t.call("take_hit", h)
				_hit_nodes.append(t)
				if not pierce:
					_land(t)
					return

	func _land(t: Node3D) -> void:
		if on_land.is_valid():
			on_land.call(self, t)
		RtFx.burst(get_parent(), global_position, color, 10, 0.1, 3.0)
		queue_free()


static func shoot(parent: Node, from: Vector3, dir: Vector3, speed: float, hit: Dictionary, color: Color, target_group: String, opts: Dictionary = {}) -> Projectile:
	var p := Projectile.new()
	p.speed = speed
	p.velocity = dir.normalized() * speed
	p.hit = hit
	p.color = color
	p.target_group = target_group
	p.homing = opts.get("homing", null)
	p.homing_turn = float(opts.get("turn", 6.0))
	p.gravity = float(opts.get("gravity", 0.0))
	p.life = float(opts.get("life", 2.5))
	p.radius = float(opts.get("radius", 0.45))
	p.pierce = bool(opts.get("pierce", false))
	p.on_land = opts.get("on_land", Callable())
	parent.add_child(p)
	p.global_position = from
	return p


# ------------------------------------------------------------------ zones
## A timed area: calls `tick(zone, delta)` every frame while alive, shows a
## soft coloured disc (and optional particles), then frees itself.
class Zone extends Node3D:
	var radius: float = 3.0
	var time: float = 4.0
	var color: Color = Color.WHITE
	var tick: Callable
	var follow: Node3D
	var age: float = 0.0

	func _ready() -> void:
		var disc := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = radius
		cyl.bottom_radius = radius
		cyl.height = 0.05
		cyl.radial_segments = 28
		disc.mesh = cyl
		disc.material_override = RtFx._unshaded(Color(color, 0.22))
		disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		disc.position.y = 0.06
		add_child(disc)
		var p := CPUParticles3D.new()
		p.amount = maxi(8, int(radius * 10.0 * Settings.particle_ratio()))
		p.lifetime = 1.4
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = radius
		p.direction = Vector3.UP
		p.gravity = Vector3(0, 0.6, 0)
		p.initial_velocity_max = 0.6
		p.scale_amount_min = 0.12
		p.scale_amount_max = 0.3
		var qm := QuadMesh.new()
		qm.material = MaterialLib.particle(color, 2.0)
		p.mesh = qm
		add_child(p)

	func _physics_process(delta: float) -> void:
		age += delta
		if is_instance_valid(follow):
			global_position = follow.global_position
		if tick.is_valid():
			tick.call(self, delta)
		if age >= time:
			queue_free()

	func contains(n: Node3D) -> bool:
		var d := n.global_position - global_position
		d.y = 0.0
		return d.length() <= radius


static func zone(parent: Node, pos: Vector3, radius: float, time: float, color: Color, tick: Callable = Callable()) -> Zone:
	var z := Zone.new()
	z.radius = radius
	z.time = time
	z.color = color
	z.tick = tick
	parent.add_child(z)
	z.global_position = pos
	return z


## Bars above enemies: background + fill quads that billboard.
class HealthBar extends Node3D:
	var fill: MeshInstance3D
	var width: float = 1.0
	var _ratio: float = 1.0

	func _ready() -> void:
		var bg := MeshInstance3D.new()
		var qb := QuadMesh.new()
		qb.size = Vector2(width + 0.06, 0.13)
		bg.mesh = qb
		var mb := RtFx._unshaded(Color(0.05, 0.0, 0.08, 0.75), false)
		mb.no_depth_test = true
		mb.render_priority = 4
		bg.material_override = mb
		add_child(bg)
		fill = MeshInstance3D.new()
		var qf := QuadMesh.new()
		qf.size = Vector2(width, 0.08)
		qf.center_offset = Vector3(width * 0.5, 0, 0)
		fill.mesh = qf
		var mf := RtFx._unshaded(Color(1.0, 0.3, 0.45, 1.0), false)
		mf.no_depth_test = true
		mf.render_priority = 5
		fill.material_override = mf
		fill.position = Vector3(-width * 0.5, 0, 0.005)
		add_child(fill)
		visible = false

	func _process(_delta: float) -> void:
		if not visible:
			return
		var cam := get_viewport().get_camera_3d()
		if cam:
			# Face the camera (the bar is a flat quad, not a material billboard,
			# so its left-aligned fill stays left-aligned).
			global_basis = cam.global_basis

	func set_ratio(r: float) -> void:
		_ratio = clampf(r, 0.0, 1.0)
		visible = _ratio < 0.999 and _ratio > 0.0
		fill.scale.x = maxf(0.001, _ratio)
