class_name AbilityRunner
extends RefCounted
## Executes class abilities in the world. Each `kind` is a small, real
## behaviour (movement, projectiles, zones, summons, buffs) — and several
## also have a world use: abilities with a `world_tag` notify nearby
## ClassSeals (shadow veils, astral barriers, runes, root gates, mycelium
## nodes, spirit echoes) so they can open.

## Returns false if the ability couldn't be used right now (no mana is spent).
static func cast(pc: PlayerCombat, a: AbilityData, mult: float = 1.0) -> bool:
	var p := pc.player
	var tree := p.get_tree()
	var world := p.get_parent()
	var power := a.power * pc.spell_mult() * mult
	if pc.has_special("elder") and a.class_id == "grimlet":
		power *= 1.25
	var fwd := pc.facing()
	var col := a.color
	var target := pc.lock_target if is_instance_valid(pc.lock_target) else RtFx.nearest(tree, p.global_position, fwd, RtFx.ENEMY_GROUP, a.ability_range, 0.3)
	match a.kind:
		# ------------------------------------------------ ASSASSIN
		"dash":
			var start := p.global_position
			var end := start + fwd * a.ability_range
			end = _clear_path(p, start, end, true)
			_streak(world, start, end, col)
			var hit_list: Array = []
			for e in tree.get_nodes_in_group(RtFx.ENEMY_GROUP):
				var t := e as Node3D
				var cp := Geometry3D.get_closest_point_to_segment(t.global_position, start, end)
				if cp.distance_to(t.global_position) < 1.4 + RtFx._radius_of(t):
					t.call("take_hit", pc._hit(power, "melee", {"from": start, "stagger": 0.8}))
					hit_list.append(t)
			p.global_position = end
			pc.invuln = 0.35
		"backstab":
			var t := target if target else RtFx.nearest(tree, p.global_position, fwd, RtFx.ENEMY_GROUP, 3.5, -1.0)
			if t == null or t.global_position.distance_to(p.global_position) > a.ability_range + RtFx._radius_of(t):
				EventBus.notify("Nobody close enough to backstab.", "info")
				return false
			if is_instance_valid(pc.avatar):
				pc.avatar.swing(true, 2.0)
			t.call("take_hit", pc._hit(power, "melee", {"from": p.global_position, "backstab_mult": 3.0, "stagger": 1.2, "heavy": true}))
			RtFx.burst(world, t.global_position + Vector3.UP, Color(1.0, 0.3, 0.45), 24, 0.14, 5.0)
		"smoke":
			var z := RtFx.zone(world, p.global_position, a.radius, a.duration, Color(0.55, 0.55, 0.7))
			z.add_to_group("rt_smoke")
			for e in tree.get_nodes_in_group(RtFx.ENEMY_GROUP):
				var wc := e as WorldCreature
				if wc and wc.global_position.distance_to(p.global_position) < a.radius + 2.0:
					wc.statuses["slow"] = 2.0
		"clone":
			_clone(pc, a, power)
		"nightfall":
			if target == null:
				EventBus.notify("Nightfall needs a target.", "info")
				return false
			pc.buffs["nightfall_hide"] = 0.6
			var rig_node := target.get("rig") as Node3D
			var face_dir := rig_node.global_basis.z.normalized() if rig_node else -fwd
			face_dir.y = 0.0
			var behind := target.global_position - face_dir.normalized() * 1.6
			_streak(world, p.global_position, behind, col)
			p.global_position = Vector3(behind.x, maxf(behind.y, target.global_position.y), behind.z)
			p.look_at(Vector3(target.global_position.x, p.global_position.y, target.global_position.z))
			target.call("take_hit", pc._hit(power, "melee", {"from": p.global_position, "backstab_mult": 1.5, "stagger": 2.0, "heavy": true, "crit": true}))
			RtFx.burst(world, target.global_position + Vector3.UP, Color(0.4, 0.2, 1.0), 40, 0.2, 6.0)
			pc.invuln = 0.6
		# ------------------------------------------------ SPIRIT
		"soul_pulse":
			_ring(world, p.global_position, a.radius, col)
			for e in tree.get_nodes_in_group(RtFx.ENEMY_GROUP):
				var t := e as Node3D
				var to := t.global_position - p.global_position
				to.y = 0.0
				if to.length() <= a.radius + RtFx._radius_of(t):
					t.call("take_hit", pc._hit(power, "magic", {"from": p.global_position, "stagger": 1.0, "knockback": to.normalized() * 4.0}))
		"companion":
			var count := 2 if pc.has_special("bell") else 1
			var dur := a.duration * (1.5 if pc.has_special("bell") else 1.0)
			for i in count:
				var w := Wisp.new()
				w.owner_combat = pc
				w.damage = power
				w.life = dur
				w.phase = i * PI
				w.color = col
				w.attack_range = a.ability_range
				world.add_child(w)
				w.global_position = p.global_position + Vector3.UP * 2.0
		"astral":
			var start := p.global_position
			var end := _clear_path(p, start, start + fwd * a.ability_range, false)
			_streak(world, start, end, col)
			p.global_position = end
			pc.invuln = a.duration
		"shield":
			pc.shield_hp = power
			pc.buffs["soul_shield"] = a.duration
			RtFx.burst(world, p.global_position + Vector3.UP, col, 20, 0.12, 2.0)
			AudioManager.play_sfx("shield")
		"echo":
			for e in tree.get_nodes_in_group(RtFx.ENEMY_GROUP):
				var wc := e as WorldCreature
				if wc and wc.global_position.distance_to(p.global_position) < a.radius:
					wc.statuses["revealed"] = a.duration
					wc.statuses["exposed"] = minf(3.0, a.duration)
			_ring(world, p.global_position, a.radius, col)
		# ------------------------------------------------ WIZARD
		"bolt":
			RtFx.shoot(world, pc._muzzle(), pc._aim_dir(), 26.0, pc._hit(power, "magic", {"stagger": 0.4, "ability": a.id}), col, RtFx.ENEMY_GROUP,
				{"homing": target, "turn": 7.0, "life": 1.8, "on_land": func(_pr: Node3D, _t: Node3D) -> void: _notify_seals(tree, _pr.global_position, a.world_tag, 2.5)})
		"nova":
			_ring(world, p.global_position, a.radius, col)
			RtFx.area_hit(tree, p.global_position, a.radius, RtFx.ENEMY_GROUP, pc._hit(power, "magic", {"status": {"slow": a.duration}}))
		"spiral":
			var acc := [0.0]
			var z := RtFx.zone(world, p.global_position, a.radius, a.duration, col, func(zz: RtFx.Zone, dt: float) -> void:
				if not is_instance_valid(pc):
					return
				acc[0] += dt
				if acc[0] >= 0.35:
					acc[0] = 0.0
					RtFx.area_hit(tree, zz.global_position, a.radius, RtFx.ENEMY_GROUP, pc._hit(power, "magic", {"status": {"burn": 2.0}, "silent": false})))
			z.follow = p
			_orbiters(z, 3, a.radius, Color(1.0, 0.55, 0.2))
		"gravity":
			var c := (target.global_position if target else p.global_position + fwd * a.ability_range * 0.7)
			var acc2 := [0.0]
			RtFx.zone(world, c, a.radius, a.duration, col, func(zz: RtFx.Zone, dt: float) -> void:
				if not is_instance_valid(pc):
					return
				acc2[0] += dt
				for e in tree.get_nodes_in_group(RtFx.ENEMY_GROUP):
					var wc := e as WorldCreature
					if wc == null or wc.is_boss() or not zz.contains(wc):
						continue
					var pull := zz.global_position - wc.global_position
					pull.y = 0.0
					if pull.length() > 0.8:
						wc.global_position += pull.normalized() * minf(pull.length(), 5.0 * dt)
				if acc2[0] >= 0.5:
					acc2[0] = 0.0
					RtFx.area_hit(tree, zz.global_position, a.radius, RtFx.ENEMY_GROUP, pc._hit(power, "magic", {"status": {"slow": 1.0}})))
		"rift":
			var c2 := (target.global_position if target else p.global_position + fwd * a.ability_range * 0.6)
			RtFx.telegraph(world, c2, a.radius, 1.0, col)
			var timer := tree.create_timer(1.0)
			timer.timeout.connect(func() -> void:
				if not is_instance_valid(pc) or not is_instance_valid(world):
					return
				RtFx.burst(world, c2 + Vector3.UP, col, 60, 0.3, 9.0)
				RtFx.area_hit(tree, c2, a.radius, RtFx.ENEMY_GROUP, pc._hit(power, "magic", {"stagger": 2.0, "heavy": true})))
		# ------------------------------------------------ GRIMLET
		"snare":
			var t2 := target
			_notify_seals(tree, p.global_position + fwd * 3.0, a.world_tag, a.ability_range)
			if t2:
				t2.call("take_hit", pc._hit(power, "magic", {"status": {"root": a.duration}, "from": p.global_position}))
				_roots(world, t2.global_position, Color(0.6, 1.0, 0.3))
		"burst":
			RtFx.burst(world, p.global_position + Vector3.UP, col, 50, 0.25, 6.0)
			RtFx.area_hit(tree, p.global_position, a.radius, RtFx.ENEMY_GROUP, pc._hit(power, "magic", {"status": {"spores": a.duration}, "knockback": Vector3.ZERO}))
		"barkskin":
			pc.buffs["barkskin"] = a.duration
			RtFx.burst(world, p.global_position + Vector3.UP, col, 20, 0.15, 2.0)
		"link":
			pc.buffs["link"] = a.duration
			_ring(world, p.global_position, a.radius, col)
			_notify_seals(tree, p.global_position, a.world_tag, a.radius)
		"colossus":
			pc.buffs["colossus"] = a.duration
			var tw := p.create_tween()
			tw.tween_property(p, "scale", Vector3.ONE * 1.5, 0.4).set_trans(Tween.TRANS_BACK)
			RtFx.burst(world, p.global_position + Vector3.UP, col, 40, 0.25, 5.0)
			EventBus.notify("COLOSSUS!", "level")
		_:
			push_warning("AbilityRunner: unknown kind '%s'" % a.kind)
			return false
	# Abilities with a world use reach nearby seals (bolt does it on impact).
	if a.world_tag != "" and a.kind != "bolt":
		_notify_seals(tree, p.global_position, a.world_tag, maxf(a.radius, a.ability_range * 0.6))
	AudioManager.play_sfx(_sound(a.class_id), -2.0)
	return true


static func _sound(cls: String) -> String:
	match cls:
		"assassin":
			return "cast_chaos"
		"spirit":
			return "cast_cosmic"
		"wizard":
			return "cast_crystal"
	return "cast_nature"


static func _notify_seals(tree: SceneTree, at: Vector3, tag: String, radius: float) -> void:
	if tag == "":
		return
	for s in tree.get_nodes_in_group("class_seal"):
		var n := s as Node3D
		if n and n.global_position.distance_to(at) <= radius + float(n.get("reach")):
			n.call("on_ability", tag)


## Moves along a line; stops before walls. Astral shifts and shadow dashes
## pass through barriers tagged for them.
static func _clear_path(p: PlayerController, start: Vector3, end: Vector3, _through_enemies: bool) -> Vector3:
	var from := start + Vector3.UP * 0.9
	var to := end + Vector3.UP * 0.9
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	q.exclude = [p.get_rid()]
	var res := p.get_world_3d().direct_space_state.intersect_ray(q)
	var out := end
	if not res.is_empty():
		var col: Object = res["collider"]
		var passable := col and col.has_meta("passable_by")
		if not passable:
			out = (res["position"] as Vector3) - (to - from).normalized() * 0.6 - Vector3.UP * 0.9
	var region := p.get_tree().get_first_node_in_group("region") as Region
	if region and region.terrain:
		out.y = maxf(out.y, region.terrain.height_at(out.x, out.z) + 0.05)
	return out


static func _streak(world: Node, a: Vector3, b: Vector3, col: Color) -> void:
	for i in 6:
		RtFx.burst(world, a.lerp(b, i / 5.0) + Vector3.UP, col, 6, 0.12, 1.0)


static func _ring(world: Node, at: Vector3, radius: float, col: Color) -> void:
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.9
	tm.outer_radius = 1.0
	tm.rings = 36
	tm.ring_segments = 4
	ring.mesh = tm
	ring.material_override = RtFx._unshaded(Color(col, 0.9))
	world.add_child(ring)
	ring.global_position = at + Vector3.UP * 0.4
	ring.scale = Vector3(0.5, 0.5, 0.5)
	var tw := ring.create_tween()
	tw.tween_property(ring, "scale", Vector3(radius, 0.6, radius), 0.35).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ring, "transparency", 1.0, 0.45)
	tw.tween_callback(ring.queue_free)


static func _orbiters(zone: Node3D, n: int, radius: float, col: Color) -> void:
	var pivot := Node3D.new()
	zone.add_child(pivot)
	pivot.position.y = 1.0
	for i in n:
		var m := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.22
		sm.height = 0.44
		m.mesh = sm
		m.material_override = RtFx._unshaded(Color(col, 1.0))
		var a := TAU * i / n
		m.position = Vector3(cos(a), 0, sin(a)) * radius
		pivot.add_child(m)
	var tw := pivot.create_tween().set_loops()
	tw.tween_property(pivot, "rotation:y", TAU, 1.0).from(0.0)


static func _roots(world: Node, at: Vector3, col: Color) -> void:
	var kit := MeshKit.new()
	for i in 6:
		var a := TAU * i / 6.0
		kit.tube(PackedVector3Array([at + Vector3(cos(a) * 1.0, -0.2, sin(a) * 1.0), at + Vector3(cos(a) * 0.6, 1.0, sin(a) * 0.6), at + Vector3(cos(a + 0.6) * 0.25, 1.6, sin(a + 0.6) * 0.25)]),
			PackedFloat32Array([0.12, 0.08, 0.02]), 5, func(_t: float) -> Color: return Color(0.25, 0.4, 0.15, 0.3), false, true)
	var mi := MeshInstance3D.new()
	mi.mesh = kit.commit(MaterialLib.bark())
	world.add_child(mi)
	var tw := mi.create_tween()
	tw.tween_interval(2.6)
	tw.tween_property(mi, "scale", Vector3(1, 0.01, 1), 0.4)
	tw.tween_callback(mi.queue_free)
	RtFx.burst(world, at + Vector3.UP * 0.5, col, 16)


static func _clone(pc: PlayerCombat, a: AbilityData, power: float) -> void:
	var p := pc.player
	var cls := Game.profile.player_class() if Game.profile else null
	var decoy := Decoy.new()
	decoy.life = a.duration
	decoy.burst_damage = power
	decoy.burst_radius = a.radius
	decoy.owner_combat = pc
	p.get_parent().add_child(decoy)
	decoy.global_position = p.global_position
	decoy.global_rotation = p.global_rotation
	var av := PlayerAvatar.create(cls, Game.profile.inventory.equipment if Game.profile else {})
	av.rotation.y = PI
	decoy.add_child(av)
	decoy.visual = av
	pc.buffs["vanish"] = 1.0
	p.global_position += pc.facing() * -2.5


# ------------------------------------------------------------------ helpers nodes
## Phantom Clone: enemies target it; it bursts when it fades or dies.
class Decoy extends Node3D:
	var life: float = 6.0
	var burst_damage: float = 10.0
	var burst_radius: float = 3.0
	var owner_combat: PlayerCombat
	var visual: Node3D
	var hit_radius: float = 0.5
	var dead: bool = false
	var _hp: float = 40.0

	func _ready() -> void:
		add_to_group("rt_decoy")

	func _physics_process(delta: float) -> void:
		life -= delta
		if is_instance_valid(visual):
			visual.scale = Vector3.ONE * (1.0 + sin(life * 10.0) * 0.02)
		if life <= 0.0:
			_pop()

	func take_hit(hit: Dictionary) -> void:
		_hp -= float(hit.get("amount", 0.0))
		RtFx.number(get_parent(), global_position + Vector3.UP * 2.0, "fooled!", Color(0.7, 0.6, 1.0))
		if _hp <= 0.0:
			_pop()

	func _pop() -> void:
		if dead:
			return
		dead = true
		remove_from_group("rt_decoy")
		RtFx.burst(get_parent(), global_position + Vector3.UP, Color(0.6, 0.4, 1.0), 30, 0.2, 5.0)
		if is_instance_valid(owner_combat):
			RtFx.area_hit(get_tree(), global_position, burst_radius, RtFx.ENEMY_GROUP, owner_combat._hit(burst_damage, "magic", {"stagger": 1.0}))
		queue_free()


## Spirit Companion: orbits the player and fires soul darts.
class Wisp extends Node3D:
	var owner_combat: PlayerCombat
	var damage: float = 6.0
	var life: float = 20.0
	var phase: float = 0.0
	var color: Color = Color(0.7, 1.0, 1.0)
	var attack_range: float = 12.0
	var _shot: float = 0.0
	var _t: float = 0.0

	func _ready() -> void:
		var m := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.18
		sm.height = 0.36
		m.mesh = sm
		m.material_override = RtFx._unshaded(Color(color, 1.0))
		add_child(m)
		var l := OmniLight3D.new()
		l.light_color = color
		l.light_energy = 0.8
		l.omni_range = 3.0
		add_child(l)

	func _physics_process(delta: float) -> void:
		_t += delta
		life -= delta
		if life <= 0.0 or not is_instance_valid(owner_combat) or not owner_combat.is_inside_tree():
			queue_free()
			return
		var p := owner_combat.player.global_position
		global_position = global_position.lerp(p + Vector3(cos(_t * 2.0 + phase) * 1.4, 2.0 + sin(_t * 3.0) * 0.2, sin(_t * 2.0 + phase) * 1.4), minf(1.0, delta * 6.0))
		_shot -= delta
		if _shot <= 0.0:
			var t := RtFx.nearest(get_tree(), global_position, Vector3.FORWARD, RtFx.ENEMY_GROUP, attack_range, -1.0)
			if t:
				_shot = 1.1
				RtFx.shoot(get_parent(), global_position, t.global_position + Vector3.UP - global_position, 18.0, owner_combat._hit(damage, "magic", {"silent": false}), color, RtFx.ENEMY_GROUP, {"homing": t, "turn": 8.0, "life": 1.5})
