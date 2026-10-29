class_name SpellFX
extends RefCounted
## Small reusable particle effects shared by world and combat. All effects
## are CPUParticles3D (predictable on every renderer) and free themselves.


static func make_particles(color: Color, amount: int, lifetime: float, size: float = 0.15) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = maxi(4, int(amount * Settings.particle_ratio()))
	p.lifetime = lifetime
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size
	quad.material = MaterialLib.particle(color, 2.5)
	p.mesh = quad
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = grad
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(0.2, 1.0))
	curve.add_point(Vector2(1, 0.0))
	p.scale_amount_curve = curve
	return p


## One-shot radial burst.
static func burst(parent: Node, where: Vector3, color: Color, amount: int = 40, speed: float = 4.0, size: float = 0.18, gravity: float = -2.0) -> CPUParticles3D:
	if parent == null or not parent.is_inside_tree():
		return null
	var p := make_particles(color, amount, 1.1, size)
	p.one_shot = true
	p.explosiveness = 0.9
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, gravity, 0)
	p.damping_min = 1.5
	p.damping_max = 3.0
	parent.add_child(p)
	p.global_position = where
	p.emitting = true
	p.finished.connect(p.queue_free)
	return p


## Continuous drifting motes in a box (ambient fireflies / spores).
static func ambient_motes(color: Color, amount: int, extents: Vector3, size: float = 0.12) -> CPUParticles3D:
	var p := make_particles(color, amount, 6.0, size)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = extents
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.4
	p.gravity = Vector3(0, 0.05, 0)
	p.preprocess = 6.0
	p.visibility_aabb = AABB(-extents - Vector3.ONE * 4.0, (extents + Vector3.ONE * 4.0) * 2.0)
	p.emitting = true
	return p
