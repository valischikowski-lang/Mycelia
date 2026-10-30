class_name WorldCreature
extends Node3D
## A creature living in the open world and fighting in real time.
## Hostile creatures notice the player, close in and use the attack patterns
## from resources/combat/enemy_profiles.json: every attack is telegraphed
## (wind-up flash + ground marker) and followed by a vulnerable recovery.
## Neutral creatures wander until challenged or hit. A creature leads its
## encounter: the other encounter members join it as a pack when it aggroes,
## and the encounter counts as won when the whole pack is down.

signal engaged(creature: WorldCreature)
signal died(creature: WorldCreature)

enum State { IDLE, WANDER, NOTICE, CHASE, WINDUP, RECOVER, STAGGER, RETURN, DEAD, ENGAGED }

const PROFILE_PATH := "res://resources/combat/enemy_profiles.json"
static var _profiles: Dictionary = {}

@export var creature_id: String = "sporeling"
@export var encounter_id: String = "enc_sporeling"
@export var home_radius: float = 10.0
@export var aggro_radius: float = 9.0
@export var engage_distance: float = 1.9
@export var move_speed: float = 2.2
@export var chase_speed: float = 4.2
## Persistent id for unique encounters (already-won ones won't spawn).
@export var unique_id: String = ""

var data: CreatureData
var rig: CreatureRig
var terrain: DreamTerrain
var state: State = State.IDLE
var home: Vector3
var profile: Dictionary = {}
var hp: float = 1.0
var max_hp: float = 1.0
var dead: bool = false
var hit_radius: float = 0.6
## The pack this creature leads (followers) or belongs to (leader).
var leader: WorldCreature
var pack: Array[WorldCreature] = []
var is_follower: bool = false
var hostile_override: bool = false
var phase: int = 0
var aware: bool = false
var shield_hp: float = 0.0
## Timed statuses: name -> seconds left (slow, root, stun, exposed, revealed, hidden, burn, spores)
var statuses: Dictionary = {}

var _target: Vector3
var _timer: float = 0.0
var _player: Node3D
var _foe: Node3D
var _cooldown: float = 0.0
var _attack_cd: Dictionary = {}
var _current: Dictionary = {}
var _notice_label: Label3D
var _bar: RtFx.HealthBar
var _hover: float = 0.0
var _leap_to: Vector3
var _dot_acc: float = 0.0


static func profiles() -> Dictionary:
	if _profiles.is_empty():
		var f := FileAccess.open(PROFILE_PATH, FileAccess.READ)
		if f:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_profiles = parsed
	return _profiles


func _ready() -> void:
	add_to_group("world_creature")
	data = Database.creature(creature_id)
	if data == null:
		queue_free()
		return
	if unique_id != "" and Game.profile and Game.profile.world.won_encounters.has(unique_id):
		queue_free()
		return
	profile = profiles().get(creature_id, profiles().get("sporeling", {}))
	max_hp = float(data.max_health)
	hp = max_hp
	chase_speed = float(profile.get("speed", chase_speed))
	aggro_radius = maxf(aggro_radius, float(profile.get("aggro", aggro_radius)))
	_hover = float(profile.get("flying", 0.0))
	hit_radius = 0.6 * data.visual_scale * (2.2 if bool(profile.get("boss", false)) else (1.5 if bool(profile.get("elite", false)) else 1.0))
	rig = CreatureBuilder.build(data.visual_kind, data.tint, {"seed": data.id.hash() % 1000})
	rig.scale = Vector3.ONE * data.visual_scale
	rig.position.y = _hover
	add_child(rig)
	add_to_group(RtFx.ENEMY_GROUP)
	home = global_position
	_target = home
	_timer = randf_range(1.0, 3.0)
	_notice_label = Label3D.new()
	_notice_label.text = "!"
	_notice_label.font_size = 96
	_notice_label.pixel_size = 0.006
	_notice_label.modulate = Color(1.0, 0.4, 0.6)
	_notice_label.outline_size = 12
	_notice_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_notice_label.position = Vector3(0, _top() + 0.5, 0)
	_notice_label.visible = false
	add_child(_notice_label)
	_bar = RtFx.HealthBar.new()
	_bar.width = 1.4 if not is_boss() else 2.4
	_bar.position = Vector3(0, _top() + 0.25, 0)
	add_child(_bar)
	if data.world_behavior == "neutral":
		var it := ChallengeInteract.new()
		it.prompt = "Challenge"
		it.display_name = data.display_name
		it.radius = 1.4
		it.marker_height = 2.2
		it.creature = self
		it.position = Vector3(0, 0.8, 0)
		add_child(it)


func _top() -> float:
	return 1.4 * data.visual_scale * (2.6 if is_boss() else (1.6 if bool(profile.get("elite", false)) else 1.0)) + _hover


func is_boss() -> bool:
	return bool(profile.get("boss", false))


func is_hostile() -> bool:
	return data.world_behavior == "hostile" or hostile_override or is_follower


func _has(s: String) -> bool:
	return float(statuses.get(s, 0.0)) > 0.0


# ------------------------------------------------------------------ brain
func _physics_process(delta: float) -> void:
	if dead or data == null or state == State.ENGAGED:
		return
	_cooldown -= delta
	for k: String in _attack_cd.keys():
		_attack_cd[k] = float(_attack_cd[k]) - delta
	_tick_statuses(delta)
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
	var to_player := INF
	if _player:
		to_player = global_position.distance_to(_player.global_position)
	if to_player > 70.0 and state != State.CHASE:
		rig.walking = false
		return
	if _has("stun"):
		rig.walking = false
		return
	_foe = _pick_foe()
	var to_foe := global_position.distance_to(_foe.global_position) if _foe else INF
	match state:
		State.IDLE:
			rig.walking = false
			_timer -= delta
			if _timer <= 0.0:
				var a := randf() * TAU
				_target = home + Vector3(cos(a), 0, sin(a)) * randf_range(2.0, home_radius)
				state = State.WANDER
		State.WANDER:
			if _move_to(_target, move_speed, delta):
				state = State.IDLE
				_timer = randf_range(1.5, 4.0)
		State.NOTICE:
			rig.walking = false
			_timer -= delta
			if _foe:
				rig.face_towards(_foe.global_position, true)
			if _timer <= 0.0:
				_notice_label.visible = false
				state = State.CHASE
		State.CHASE:
			if _foe == null or _lost_track(to_foe):
				_set_aware(false)
				state = State.RETURN
			else:
				var atk := _choose_attack(to_foe)
				if not atk.is_empty():
					_begin_attack(atk)
				else:
					var keep := float(profile.get("keep_distance", 0.0))
					if keep > 0.0 and to_foe < keep * 0.7:
						var away := (global_position - _foe.global_position).normalized() * 3.0
						_move_to(global_position + away, chase_speed * 0.8, delta)
					elif to_foe > maxf(1.4, keep):
						_move_to(_foe.global_position, chase_speed, delta)
					else:
						rig.walking = false
						rig.face_towards(_foe.global_position)
		State.WINDUP:
			_timer -= delta
			if _foe and String(_current.get("kind", "")) in ["melee", "projectile", "leap"]:
				rig.face_towards(_foe.global_position)
			if _timer <= 0.0:
				_execute(_current)
		State.RECOVER, State.STAGGER:
			rig.walking = false
			_timer -= delta
			if state == State.RECOVER and String(_current.get("kind", "")) == "leap":
				_leap_step(delta)
			if _timer <= 0.0:
				state = State.CHASE
		State.RETURN:
			if _move_to(home, move_speed * 1.3, delta):
				state = State.IDLE
				_timer = 2.0
				hp = minf(max_hp, hp + max_hp * 0.5)
				_bar.set_ratio(hp / max_hp)
	if is_hostile() and state in [State.IDLE, State.WANDER] and to_player < aggro_radius and _cooldown <= 0.0 and Game.session_active:
		if _player is PlayerController and (_player as PlayerController).input_enabled and not _player_hidden():
			notice()
	if _hover > 0.0:
		rig.position.y = _hover + sin(Time.get_ticks_msec() * 0.004) * 0.25


func _lost_track(to_foe: float) -> bool:
	if _player_hidden() and _foe == _player:
		return true
	var leash := home_radius * 3.0 + (30.0 if is_boss() or is_follower else 0.0)
	return to_foe > aggro_radius * 2.2 or global_position.distance_to(home) > leash


func _player_hidden() -> bool:
	if _player == null:
		return true
	var pc: Node = _player.get_node_or_null("Combat")
	return pc != null and bool(pc.call("is_hidden_from", self))


## Decoys (Phantom Clone) draw attention away from the player.
func _pick_foe() -> Node3D:
	for d in get_tree().get_nodes_in_group("rt_decoy"):
		var dn := d as Node3D
		if dn and dn.global_position.distance_to(global_position) < aggro_radius * 1.5:
			return dn
	return _player


func notice() -> void:
	if dead or state in [State.NOTICE, State.CHASE, State.WINDUP, State.RECOVER]:
		return
	state = State.NOTICE
	_timer = 0.55
	_notice_label.visible = true
	_set_aware(true)
	AudioManager.play_at(_voice(), global_position, get_parent(), -4.0)
	engaged.emit(self)
	_spawn_pack()
	for f in pack:
		if is_instance_valid(f):
			f.notice()
	if is_instance_valid(leader):
		leader.notice()


func _set_aware(on: bool) -> void:
	aware = on
	if on:
		EventBus.rt_enemy_aggro.emit(self)


# ------------------------------------------------------------------ attacks
func _choose_attack(dist: float) -> Dictionary:
	var options: Array = []
	for a: Dictionary in profile.get("attacks", []):
		if float(_attack_cd.get(a["id"], 0.0)) > 0.0:
			continue
		if int(a.get("phase", 0)) > phase:
			continue
		if dist > float(a.get("range", 2.0)) or dist < float(a.get("min_range", 0.0)):
			continue
		var kind := String(a.get("kind", "melee"))
		if kind == "heal" and hp / max_hp > float(a.get("below", 0.5)):
			continue
		if kind == "shield" and shield_hp > 0.0:
			continue
		if _has("root") and kind in ["leap", "blink"]:
			continue
		options.append(a)
	if options.is_empty():
		return {}
	# Prefer the "biggest" available move, with some randomness.
	options.shuffle()
	return options[0]


func _begin_attack(a: Dictionary) -> void:
	_current = a
	state = State.WINDUP
	rig.walking = false
	var windup := float(a.get("windup", 0.5))
	if _has("slow"):
		windup *= 1.4
	_timer = windup
	_attack_cd[a["id"]] = float(a.get("cooldown", 1.5))
	# Telegraph: a red flash on the body and a marker where it will land.
	rig.call("_flash", Color(1.0, 0.25, 0.25))
	var kind := String(a.get("kind", "melee"))
	var col := Color(String(a.get("color", "#ff4060")))
	match kind:
		"aoe_self":
			RtFx.telegraph(get_parent(), global_position, float(a.get("radius", 3.0)), windup, col)
		"aoe_target", "zone":
			_leap_to = _foe.global_position if _foe else global_position
			RtFx.telegraph(get_parent(), _leap_to, float(a.get("radius", 2.5)), windup, col)
		"leap":
			_leap_to = _foe.global_position if _foe else global_position
			RtFx.telegraph(get_parent(), _leap_to, 1.6, windup, Color(1.0, 0.35, 0.3))
		"shockwave":
			RtFx.telegraph(get_parent(), global_position, 2.5, windup, col)
	if is_boss() or bool(profile.get("elite", false)):
		EventBus.notify("%s readies %s!" % [data.display_name, String(a.get("name", "an attack"))], "warning")
	AudioManager.play_at("enemy_attack", global_position, get_parent(), -8.0)


func _hit_for(a: Dictionary, mult: float = 1.0) -> Dictionary:
	return {"amount": float(a.get("damage", 5)) * mult * (1.0 + 0.08 * (data.level - 1)), "source": self, "name": String(a.get("name", "")),
		"kind": "magic" if String(a.get("kind", "")) in ["projectile", "zone", "aoe_target", "shockwave"] else "melee",
		"effect": String(a.get("effect", ""))}


func _execute(a: Dictionary) -> void:
	var kind := String(a.get("kind", "melee"))
	var recover := float(a.get("recover", 0.6))
	var col := Color(String(a.get("color", "#ff4060")))
	match kind:
		"melee":
			rig.play_attack(_foe.global_position if _foe else global_position + Vector3.FORWARD)
			if _foe and _foe.global_position.distance_to(global_position) <= float(a.get("range", 2.0)) + 0.8:
				_hit_foe(_hit_for(a))
		"leap":
			_timer = recover
			state = State.RECOVER
			rig.play_attack(_leap_to)
			return
		"projectile":
			rig.play_cast()
			var n := int(a.get("count", 1))
			var spread := deg_to_rad(float(a.get("spread", 0.0)))
			var from := global_position + Vector3.UP * (0.9 + _hover)
			var aim := (_foe.global_position + Vector3.UP * 0.9 - from) if _foe else -global_basis.z
			for i in n:
				var off := 0.0 if n == 1 else lerpf(-spread * 0.5, spread * 0.5, float(i) / (n - 1))
				var dir := aim.rotated(Vector3.UP, off)
				RtFx.shoot(get_parent(), from, dir, float(a.get("speed", 12.0)), _hit_for(a), col, _foe_group(), {"life": 2.5, "radius": 0.5})
		"aoe_self":
			rig.play_attack(global_position)
			RtFx.burst(get_parent(), global_position + Vector3.UP * 0.3, col, 40, 0.25, 7.0)
			_area_on_foes(global_position, float(a.get("radius", 3.0)), _hit_for(a))
			if String(profile.get("exposed_after", "")) == String(a.get("id", "")):
				statuses["exposed"] = recover
				EventBus.notify("%s is exposed — strike its back!" % data.display_name, "success")
		"aoe_target":
			rig.play_cast()
			RtFx.burst(get_parent(), _leap_to + Vector3.UP * 0.3, col, 30, 0.22, 6.0)
			_area_on_foes(_leap_to, float(a.get("radius", 2.5)), _hit_for(a))
		"zone":
			rig.play_cast()
			var hit := _hit_for(a)
			var acc := [0.0]
			RtFx.zone(get_parent(), _leap_to, float(a.get("radius", 3.0)), float(a.get("duration", 5.0)), col, func(z: RtFx.Zone, dt: float) -> void:
				acc[0] += dt
				if acc[0] >= 1.0:
					acc[0] = 0.0
					for f: Node3D in _foes():
						if z.contains(f):
							f.call("take_hit", hit))
		"shockwave":
			rig.play_attack(global_position)
			_shockwave(a, col)
		"summon":
			rig.play_cast()
			for i in int(a.get("count", 1)):
				var c := WorldCreature.new()
				c.creature_id = String(a.get("summon", "sporeling"))
				c.encounter_id = ""
				c.terrain = terrain
				c.is_follower = true
				c.leader = self
				c.home_radius = 6.0
				get_parent().add_child(c)
				var ang := TAU * i / maxf(1, int(a.get("count", 1)))
				var p := global_position + Vector3(cos(ang), 0, sin(ang)) * 3.0
				if terrain:
					p.y = terrain.height_at(p.x, p.z)
				c.global_position = p
				c.home = p
				pack.append(c)
				c.notice()
		"blink":
			rig.play_cast()
			RtFx.burst(get_parent(), global_position + Vector3.UP, Color(0.6, 1.0, 0.3), 16)
			var away := (global_position - (_foe.global_position if _foe else global_position)).normalized()
			if away.length() < 0.1:
				away = Vector3.FORWARD
			var p2 := global_position + away.rotated(Vector3.UP, randf_range(-0.8, 0.8)) * 6.0
			if terrain:
				p2.y = terrain.height_at(p2.x, p2.z)
			global_position = p2
			RtFx.number(get_parent(), global_position + Vector3.UP * 2.0, "Heeheehee!", Color(0.7, 1.0, 0.4))
		"heal":
			rig.play_cast()
			hp = minf(max_hp, hp + float(a.get("damage", 10)))
			_bar.set_ratio(hp / max_hp)
			RtFx.number(get_parent(), global_position + Vector3.UP * _top(), "+%d" % int(a.get("damage", 10)), UiTheme.SUCCESS)
		"stealth":
			statuses["hidden"] = float(a.get("duration", 3.0))
		"shield":
			rig.play_cast()
			shield_hp = float(a.get("damage", 40))
			EventBus.notify("%s hardens a shield of threads — break it!" % data.display_name, "warning")
	_timer = recover
	state = State.RECOVER


func _shockwave(a: Dictionary, col: Color) -> void:
	# An expanding ring along the ground: jump over it or dodge through it.
	var radius := float(a.get("radius", 12.0))
	var hit := _hit_for(a)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.85
	tm.outer_radius = 1.0
	tm.rings = 40
	tm.ring_segments = 4
	ring.mesh = tm
	ring.material_override = RtFx._unshaded(Color(col, 0.9))
	get_parent().add_child(ring)
	ring.global_position = global_position + Vector3.UP * 0.25
	ring.scale = Vector3(1, 0.4, 1)
	var hit_once := {}
	var center := global_position
	var tw := ring.create_tween()
	tw.tween_method(func(r: float) -> void:
		ring.scale = Vector3(r, 0.4, r)
		for f: Node3D in _foes():
			if hit_once.has(f):
				continue
			var d := Vector2(f.global_position.x - center.x, f.global_position.z - center.z).length()
			var airborne := f is PlayerController and not (f as PlayerController).is_on_floor()
			if absf(d - r) < 0.9 and not airborne:
				hit_once[f] = true
				f.call("take_hit", hit), 1.0, radius, radius / 9.0)
	tw.tween_callback(ring.queue_free)


func _leap_step(delta: float) -> void:
	var flat := Vector3(_leap_to.x - global_position.x, 0, _leap_to.z - global_position.z)
	if flat.length() < 0.6:
		if not _current.has("_landed"):
			_current["_landed"] = true
			if _foe and _foe.global_position.distance_to(global_position) < 2.2:
				_hit_foe(_hit_for(_current))
			RtFx.burst(get_parent(), global_position + Vector3.UP * 0.2, Color(1, 0.6, 0.4), 12)
		return
	var p := global_position + flat.normalized() * minf(flat.length(), chase_speed * 3.2 * delta)
	if terrain:
		p.y = terrain.height_at(p.x, p.z)
	global_position = p
	if _foe and _foe.global_position.distance_to(global_position) < 1.4 and not _current.has("_landed"):
		_current["_landed"] = true
		_hit_foe(_hit_for(_current))


func _foe_group() -> String:
	return RtFx.PLAYER_GROUP


func _foes() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for n in get_tree().get_nodes_in_group(RtFx.PLAYER_GROUP):
		out.append(n as Node3D)
	for n in get_tree().get_nodes_in_group("rt_decoy"):
		out.append(n as Node3D)
	return out


func _hit_foe(hit: Dictionary) -> void:
	if _foe and _foe.has_method("take_hit"):
		hit["from"] = global_position
		_foe.call("take_hit", hit)


func _area_on_foes(center: Vector3, radius: float, hit: Dictionary) -> void:
	for f: Node3D in _foes():
		var d := f.global_position - center
		d.y = 0.0
		if d.length() <= radius + 0.4 and f.has_method("take_hit"):
			var h := hit.duplicate()
			h["from"] = center
			f.call("take_hit", h)


# ------------------------------------------------------------------ taking hits
## hit: {"amount", "source", "kind", "from", "stagger", "crit", "knockback",
##       "status": {name: seconds}, "backstab_mult", "silent"}
func take_hit(hit: Dictionary) -> void:
	if dead:
		return
	var amount := float(hit.get("amount", 0.0))
	var from: Vector3 = hit.get("from", global_position)
	var to_attacker := (from - global_position)
	to_attacker.y = 0.0
	# Models face +Z: behind = attacker on the -Z side of the rig.
	var facing := (rig.global_basis.z).normalized()
	var behind := to_attacker.length() > 0.1 and facing.dot(to_attacker.normalized()) < -0.3
	var notes := PackedStringArray()
	if behind or not aware:
		amount *= float(hit.get("backstab_mult", 1.0))
		if float(hit.get("backstab_mult", 1.0)) > 1.0:
			notes.append("BACKSTAB")
	if String(profile.get("weak", "")) == "back" and behind:
		amount *= 1.75
		notes.append("WEAK SPOT")
	elif float(profile.get("front_guard", 0.0)) > 0.0 and not behind and String(hit.get("kind", "")) == "melee" and not bool(hit.get("heavy", false)):
		amount *= 1.0 - float(profile.get("front_guard", 0.0))
		notes.append("GUARDED")
	if _has("exposed"):
		amount *= 2.0
		notes.append("EXPOSED")
	if shield_hp > 0.0:
		var absorbed := minf(shield_hp, amount * (1.6 if bool(hit.get("heavy", false)) else 1.0))
		shield_hp -= absorbed
		amount = maxf(0.0, amount - absorbed)
		if shield_hp <= 0.0:
			RtFx.number(get_parent(), global_position + Vector3.UP * (_top() + 0.4), "SHIELD BROKEN", UiTheme.GOLD, true)
			statuses["stun"] = 2.0
	var defense := float(data.defense)
	amount = maxf(1.0, amount - defense * 0.5) if amount > 0.0 else 0.0
	hp -= amount
	var col := UiTheme.GOLD if bool(hit.get("crit", false)) else Color(1, 1, 1)
	RtFx.number(get_parent(), global_position + Vector3.UP * (_top() * 0.8), ("%d" % int(round(amount))) + (" " + notes[0] if notes.size() > 0 else ""), col, bool(hit.get("crit", false)) or notes.size() > 0)
	for st: String in (hit.get("status", {}) as Dictionary).keys():
		if is_boss() and st in ["stun", "root"]:
			statuses[st] = maxf(float(statuses.get(st, 0.0)), float(hit["status"][st]) * 0.4)
		else:
			statuses[st] = maxf(float(statuses.get(st, 0.0)), float(hit["status"][st]))
	statuses.erase("hidden")
	_bar.set_ratio(hp / max_hp)
	rig.play_hit()
	AudioManager.play_at("hit", global_position, get_parent(), -6.0)
	var kb: Vector3 = hit.get("knockback", Vector3.ZERO)
	if kb != Vector3.ZERO and not is_boss():
		var p := global_position + Vector3(kb.x, 0, kb.z)
		if terrain:
			p.y = terrain.height_at(p.x, p.z)
		global_position = p
	if hp <= 0.0:
		_die()
		return
	# Boss phases from CreatureData.phase_thresholds.
	if is_boss() and phase < data.phase_thresholds.size() and hp / max_hp <= data.phase_thresholds[phase]:
		phase += 1
		statuses["stun"] = 1.5
		EventBus.notify("%s awakens fully!" % data.display_name, "warning")
	if not aware and bool(hit.get("silent", false)):
		# Silent hits (Nightpiercer, poisons) leave it confused, not alerted.
		pass
	elif not aware:
		hostile_override = true
		notice()
	elif state in [State.IDLE, State.WANDER, State.RETURN]:
		hostile_override = true
		state = State.CHASE
		_set_aware(true)
	# Heavy hits and parries interrupt wind-ups (not for bosses).
	var stagger := float(hit.get("stagger", 0.0))
	if stagger > 0.0 and (not is_boss() or stagger >= 1.5) and state == State.WINDUP:
		state = State.STAGGER
		_timer = stagger * (0.5 if is_boss() else 1.0)
		RtFx.number(get_parent(), global_position + Vector3.UP * (_top() + 0.3), "INTERRUPTED", UiTheme.GLOW)


func _tick_statuses(delta: float) -> void:
	var expired: Array = []
	for k: String in statuses.keys():
		statuses[k] = float(statuses[k]) - delta
		if float(statuses[k]) <= 0.0:
			expired.append(k)
	for k: String in expired:
		statuses.erase(k)
	if _has("burn") or _has("spores"):
		_dot_acc += delta
		if _dot_acc >= 1.0:
			_dot_acc = 0.0
			take_hit({"amount": 4.0 + (2.0 if _has("burn") else 0.0), "kind": "magic", "silent": true, "from": global_position})
	rig.visible = not _has("hidden") or _has("revealed")


func _die() -> void:
	dead = true
	state = State.DEAD
	remove_from_group(RtFx.ENEMY_GROUP)
	_bar.visible = false
	_notice_label.visible = false
	rig.play_death()
	died.emit(self)
	var prof := Game.profile
	if prof:
		_grant_kill_rewards(prof)
	EventBus.enemy_defeated.emit(data.id)
	var lead := leader if is_instance_valid(leader) else self
	lead._check_pack_done()
	var tw := create_tween()
	tw.tween_interval(1.0)
	tw.tween_property(self, "scale", Vector3.ONE * 0.01, 0.5)
	tw.tween_callback(func() -> void:
		if is_follower or not lead.dead:
			queue_free()
		else:
			visible = false)


func _grant_kill_rewards(prof: PlayerProfile) -> void:
	var gap := maxi(0, prof.stats.level - data.level - 2)
	var xp := int(round(data.xp_reward * maxf(0.3, 1.0 - gap * 0.2)))
	var items: Dictionary = {}
	for l: Dictionary in data.loot_table:
		if randf() <= float(l.get("chance", 0.0)):
			var id := String(l.get("item_id", ""))
			items[id] = int(items.get(id, 0)) + randi_range(int(l.get("min", 1)), int(l.get("max", 1)))
	var summary := prof.grant_rewards({"xp": xp, "glimmer": randi_range(data.glimmer_min, data.glimmer_max), "items": items})
	EventBus.xp_gained.emit(xp)
	RtFx.number(get_parent(), global_position + Vector3.UP * (_top() + 0.6), "+%d XP" % xp, UiTheme.XP)
	for id: String in (summary.get("items", {}) as Dictionary).keys():
		EventBus.item_collected.emit(id, int(summary["items"][id]))
		var d := Database.item(id)
		EventBus.notify("+%d %s" % [int(summary["items"][id]), d.display_name if d else id], "item")


## Leader only: when every member of the encounter is down, it's won.
func _check_pack_done() -> void:
	if not dead:
		return
	for f in pack:
		if is_instance_valid(f) and not f.dead and f.encounter_id != "":
			return
	if encounter_id == "":
		return
	var enc := Database.encounter(encounter_id)
	var prof := Game.profile
	if prof and enc:
		if enc.bonus_xp > 0 or enc.bonus_glimmer > 0:
			prof.grant_rewards({"xp": enc.bonus_xp, "glimmer": enc.bonus_glimmer, "items": enc.bonus_items})
		if enc.unique:
			prof.world.won_encounters[enc.id] = true
	if unique_id != "" and prof:
		prof.world.won_encounters[unique_id] = true
	EventBus.encounter_won.emit(encounter_id)
	if is_boss() or (enc and enc.unique):
		AudioManager.play_sfx("victory")
		EventBus.notify("%s is defeated!" % (enc.display_name if enc else data.display_name), "quest_complete")
	for f in pack:
		if is_instance_valid(f) and f.dead:
			f.queue_free()
	queue_free()


## The other members of this creature's encounter join when it aggroes.
func _spawn_pack() -> void:
	if is_follower or encounter_id == "" or not pack.is_empty():
		return
	var enc := Database.encounter(encounter_id)
	if enc == null or enc.enemies.size() <= 1:
		return
	for i in range(1, enc.enemies.size()):
		var cd: CreatureData = enc.enemies[i]
		var c := WorldCreature.new()
		c.creature_id = cd.id
		c.encounter_id = encounter_id
		c.terrain = terrain
		c.is_follower = true
		c.leader = self
		c.home_radius = home_radius
		get_parent().add_child(c)
		var ang := TAU * i / enc.enemies.size() + randf()
		var p := global_position + Vector3(cos(ang), 0, sin(ang)) * 3.5
		if terrain:
			p.y = terrain.height_at(p.x, p.z)
		c.global_position = p
		c.home = home
		RtFx.burst(get_parent(), p + Vector3.UP, Color(0.6, 0.3, 1.0), 14)
		pack.append(c)
		c.notice()


# ------------------------------------------------------------------ movement
func _move_to(target: Vector3, speed: float, delta: float) -> bool:
	if _has("root"):
		rig.walking = false
		return false
	if _has("slow"):
		speed *= 0.45
	var flat := Vector3(target.x - global_position.x, 0, target.z - global_position.z)
	var d := flat.length()
	if d < 0.4:
		rig.walking = false
		return true
	rig.walking = true
	var step := flat.normalized() * minf(speed * delta, d)
	var p := global_position + step
	if terrain:
		p.y = terrain.height_at(p.x, p.z)
		if p.y < terrain.water_level - 0.2:
			_target = home
			return true
	global_position = p
	# Models face +Z, so look "away" from the opposite direction.
	var want := Basis.looking_at(-flat.normalized(), Vector3.UP)
	rig.basis = rig.basis.orthonormalized().slerp(want, minf(1.0, delta * 8.0)).scaled(Vector3.ONE * data.visual_scale)
	return false


func _voice() -> String:
	match data.visual_kind:
		"crystal_beetle":
			return "beetle_click"
		"dream_fox":
			return "fox_yip"
		"bloom_guardian":
			return "guardian_groan"
		"spore_golem":
			return "golem_rumble"
	return "sporeling_chirp"


## Kept for the legacy turn-based combat manager (no longer triggered from
## the world, but still supported for scripted duels).
func on_combat_result(won: bool, fled: bool) -> void:
	if won:
		if unique_id != "" and Game.profile:
			Game.profile.world.won_encounters[unique_id] = true
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector3.ONE * 0.01, 0.4)
		tw.tween_callback(queue_free)
		return
	state = State.RETURN
	_cooldown = 8.0 if fled else 12.0
	_notice_label.visible = false
	global_position = home


class ChallengeInteract extends Interactable:
	var creature: WorldCreature

	func _on_interact(_by: Node) -> void:
		if creature and not creature.dead and not creature.aware:
			creature.hostile_override = true
			creature.notice()
			queue_free()
