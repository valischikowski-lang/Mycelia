class_name CombatArena
extends Node3D
## Presentation of a battle: a floating dream-platform above a sea of
## clouds, the combatants' rigs, a cinematic camera and event playback.
## It never decides outcomes — it only replays BattleState events.

signal number_shown(uid: int, text: String, color: Color)

const ORIGIN := Vector3(0, 800, 0)
const PLAYER_POS := Vector3(0, 0, 5.5)
const RUNE_SHADER := preload("res://shaders/rune_circle.gdshader")

var camera: Camera3D
var env: Environment
var rigs: Dictionary = {}
var base_positions: Dictionary = {}
var bubbles: Dictionary = {}
var sentinel: CreatureRig
var _crystal_ring: Node3D
var _cam_home: Transform3D
var _shake: float = 0.0
var _cam_base: Transform3D
var _target_rings: Dictionary = {}


func build(state: BattleState, player_opts: Dictionary) -> void:
	position = ORIGIN
	var biome: BiomeData = Database.biome("dream_arena")
	env = Region.make_environment(biome)
	env.fog_density = 0.004
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.8, 0.9)
	sun.light_energy = 1.1
	sun.rotation_degrees = Vector3(-40, 160, 0)
	sun.shadow_enabled = Settings.shadows_enabled()
	sun.directional_shadow_max_distance = 40.0
	add_child(sun)
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	# Platform.
	var isl := IslandGenerator.build(rng, biome, 13.0, 11.0, {"roots": 14})
	var plat := MeshInstance3D.new()
	plat.mesh = isl["mesh"]
	plat.position = Vector3(0, -0.15, 0)
	add_child(plat)
	var rune := MeshInstance3D.new()
	var quad := PlaneMesh.new()
	quad.size = Vector2(20, 20)
	rune.mesh = quad
	var rm := ShaderMaterial.new()
	rm.shader = RUNE_SHADER
	rune.material_override = rm
	rune.position = Vector3(0, 0.12, 0)
	add_child(rune)
	# Orbiting crystals.
	_crystal_ring = Node3D.new()
	add_child(_crystal_ring)
	for i in 8:
		var cr := CrystalGenerator.build(rng, biome, rng.randf_range(1.2, 2.4), 0.3, 3, false, 2.0)
		var cmi := MeshInstance3D.new()
		cmi.mesh = cr["mesh"]
		var a := TAU * i / 8.0
		cmi.position = Vector3(cos(a) * 15.0, 2.5 + sin(i * 1.7) * 1.5, sin(a) * 15.0)
		cmi.rotation = Vector3(rng.randf() * 0.6, rng.randf() * TAU, rng.randf() * 0.6)
		cmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_crystal_ring.add_child(cmi)
	# Background: islands of giant mushrooms floating in the void.
	var bg := MeshKit.new()
	for i in 9:
		var a := TAU * i / 9.0 + 0.3
		var d := rng.randf_range(45.0, 70.0)
		var center := Vector3(cos(a) * d, rng.randf_range(-12.0, 8.0), sin(a) * d)
		var ib := IslandGenerator.build(rng, biome, rng.randf_range(7, 12), 8.0, {"crystals": false, "roots": 4})
		var imi := MeshInstance3D.new()
		imi.mesh = ib["mesh"]
		imi.position = center
		imi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(imi)
		for k in 2:
			var p := MushroomGenerator.random_params(rng, biome, "giant")
			p.cap_segments = 20
			MushroomGenerator.build_into(bg, p, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), center + Vector3(rng.randf_range(-4, 4), 0, rng.randf_range(-4, 4))))
	var bgmi := MeshInstance3D.new()
	bgmi.mesh = bg.commit(MaterialLib.mushroom_breathing())
	bgmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bgmi)
	var motes := SpellFX.ambient_motes(Color(1.0, 0.8, 0.5), 80, Vector3(16, 6, 16), 0.12)
	motes.position = Vector3(0, 4, 0)
	add_child(motes)
	var fill := OmniLight3D.new()
	fill.light_color = Color(0.4, 0.9, 1.0)
	fill.light_energy = 1.5
	fill.omni_range = 18.0
	fill.position = Vector3(0, 4, 0)
	add_child(fill)
	# Combatants.
	var player_rig := CreatureBuilder.build("dreamer", Color.WHITE, player_opts)
	add_child(player_rig)
	player_rig.position = PLAYER_POS
	player_rig.rotation.y = PI
	rigs[0] = player_rig
	base_positions[0] = PLAYER_POS
	var n := state.enemies.size()
	for i in n:
		var e := state.enemies[i]
		var rig := CreatureBuilder.build(e.data.visual_kind, e.data.tint, {"seed": e.data.id.hash() % 1000})
		rig.scale = Vector3.ONE * e.data.visual_scale * (1.7 if e.data.visual_kind == "sporeling" else 1.0)
		var x := (i - (n - 1) * 0.5) * 4.2
		var pos := Vector3(x, 0, -4.5 + absf(x) * 0.15)
		rig.position = pos
		add_child(rig)
		rigs[e.uid] = rig
		base_positions[e.uid] = pos
		var ring := MeshInstance3D.new()
		var tor := TorusMesh.new()
		tor.inner_radius = 1.2
		tor.outer_radius = 1.4
		ring.mesh = tor
		ring.material_override = MaterialLib.glow_unique(Color(1.0, 0.85, 0.3), 2.0)
		ring.position = pos + Vector3.UP * 0.1
		ring.visible = false
		add_child(ring)
		_target_rings[e.uid] = ring
	camera = Camera3D.new()
	camera.environment = env
	camera.fov = 62.0
	camera.far = 600.0
	add_child(camera)
	_cam_home = _framing(Vector3(5.5, 4.4, 12.5), Vector3(0, 1.2, -3.0))
	camera.transform = _cam_home
	_cam_base = _cam_home


func _framing(pos: Vector3, look: Vector3) -> Transform3D:
	var t := Transform3D(Basis.IDENTITY, pos)
	return t.looking_at(look, Vector3.UP)


func activate() -> void:
	camera.current = true


func _process(delta: float) -> void:
	if _crystal_ring:
		_crystal_ring.rotation.y += delta * 0.08
	if camera and _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 2.5)
		var off := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.25
		camera.transform = _cam_base.translated_local(off)


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func move_camera(to: Transform3D, time: float) -> void:
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(func(w: float) -> void:
		_cam_base = _cam_base.interpolate_with(to, w)
		camera.transform = _cam_base, 0.0, 1.0, time)
	await tw.finished
	_cam_base = to
	camera.transform = to


func camera_home(time: float = 0.6) -> void:
	await move_camera(_cam_home, time)


func play_intro() -> void:
	camera.transform = _framing(Vector3(0, 22, 26), Vector3(0, 0, 0))
	_cam_base = camera.transform
	for uid: int in rigs.keys():
		if uid == 0:
			continue
		var r: Node3D = rigs[uid]
		var s := r.scale
		r.scale = s * 0.01
		var tw := create_tween()
		tw.tween_interval(0.3 + uid * 0.15)
		tw.tween_property(r, "scale", s, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		SpellFX.burst(self, r.global_position + Vector3.UP, Color(1.0, 0.5, 0.9), 40)
	await move_camera(_cam_home, 1.6)


func world_pos(uid: int) -> Vector3:
	var r: Node3D = rigs.get(uid)
	return r.global_position if r else global_position


func show_target_rings(on: bool, uids: Array = []) -> void:
	for uid: int in _target_rings.keys():
		var ring: Node3D = _target_rings[uid]
		ring.visible = on and (uids.is_empty() or uid in uids) and (rigs[uid] as Node3D).visible


## Makes the given enemies pulse with a golden glow (target selection).
func highlight_targets(uids: Array) -> void:
	for uid: int in rigs.keys():
		if uid == 0:
			continue
		(rigs[uid] as CreatureRig).set_highlight(uid in uids)


## Screen position for UI overlays (target buttons, plates).
func screen_pos(uid: int, height: float = 1.6) -> Vector2:
	if camera == null:
		return Vector2.ZERO
	return camera.unproject_position(world_pos(uid) + Vector3.UP * height)


# ------------------------------------------------------------------ events
func play_events(events: Array[Dictionary], state: BattleState) -> void:
	var i := 0
	while i < events.size():
		var e: Dictionary = events[i]
		match String(e["type"]):
			"cast":
				await _play_cast(e, state)
			"damage":
				await _play_damage(e)
			"heal":
				_number(int(e["target"]), "+%d" % int(e["amount"]), Color(0.4, 1.0, 0.5), false)
			"miss":
				_number(int(e["target"]), "Miss", Color(0.8, 0.8, 0.9), false)
				AudioManager.play_sfx("miss")
				await get_tree().create_timer(0.2).timeout
			"status_applied":
				_status_popup(e)
			"interrupted":
				_number(int(e["target"]), "Interrupted!", Color(0.5, 1.0, 0.4), true)
				shake(0.5)
			"status_tick":
				var amt := int(e["amount"])
				var col: Color = e.get("color", Color.WHITE)
				_number(int(e["target"]), ("%+d" % amt), col, false)
				if amt < 0:
					var r: CreatureRig = rigs.get(int(e["target"]))
					if r:
						r.play_hit()
				await get_tree().create_timer(0.25).timeout
			"status_expired":
				_update_bubble(int(e["target"]), state)
				if String(e["status"]) == "sentinel" and sentinel:
					sentinel.queue_free()
					sentinel = null
			"death":
				var r2: CreatureRig = rigs.get(int(e["target"]))
				if r2:
					SpellFX.burst(self, r2.global_position + Vector3.UP, Color(0.9, 0.5, 1.0), 70, 5.0)
					await r2.play_death()
					_update_bubble(int(e["target"]), state)
			"stunned":
				_number(int(e["target"]), "Rooted!", Color(0.6, 1.0, 0.4), true)
				await get_tree().create_timer(0.5).timeout
			"charge_start":
				var r3: CreatureRig = rigs.get(int(e["source"]))
				if r3:
					SpellVFX.charge_up(self, r3.global_position, Color(1.0, 0.5, 0.2), 0.8)
					shake(0.4)
				await get_tree().create_timer(0.9).timeout
			"charge_release":
				shake(0.8)
			"phase":
				var r4: CreatureRig = rigs.get(int(e["source"]))
				if r4:
					shake(1.2)
					SpellFX.burst(self, r4.global_position + Vector3.UP * 2.0, Color(1.0, 0.6, 0.2), 120, 9.0, 0.3)
					var tw := create_tween()
					tw.tween_property(r4, "scale", r4.scale * 1.2, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
					AudioManager.play_sfx("golem_rumble")
				await get_tree().create_timer(1.0).timeout
			"shield":
				_update_bubble(int(e["target"]), state)
		i += 1


func _play_cast(e: Dictionary, state: BattleState) -> void:
	var caster := int(e["caster"])
	var style := String(e.get("style", ""))
	var element := String(e.get("element", "fungal"))
	var color := ElementChart.color(element)
	var targets: Array = e.get("targets", [])
	var rig: CreatureRig = rigs.get(caster)
	if rig == null:
		return
	if style == "meditate":
		await SpellVFX.heal_threads(self, rig.global_position, Color(0.4, 0.8, 1.0))
		return
	var is_player := caster == 0
	var summon := bool(e.get("summon", false))
	var from := rig.global_position + Vector3.UP * (1.6 if is_player else 0.8)
	if summon and sentinel:
		from = sentinel.global_position + Vector3.UP * 0.6
	var target_uid: int = int(targets[0]) if not targets.is_empty() else caster
	var self_cast := targets.size() == 1 and target_uid == caster
	if is_player and not summon:
		# The camera lives in arena space, so frame a local-space point.
		var focus := _framing(Vector3(3.5, 3.0, 10.5), to_local(world_pos(target_uid)) + Vector3.UP * (0.5 if not self_cast else 1.2))
		move_camera(focus, 0.35)
	AudioManager.play_sfx("cast_" + element if not style == "melee" else "enemy_attack", -2.0)
	if style == "melee":
		await rig.play_attack(world_pos(target_uid))
		AudioManager.play_sfx("hit")
		SpellVFX.impact(self, "melee", world_pos(target_uid), color)
		return
	if not summon:
		rig.play_cast()
		await SpellVFX.charge_up(self, rig.global_position, color)
	match style:
		"fungal_heal", "nature_bloom":
			if self_cast:
				await SpellVFX.heal_threads(self, rig.global_position, color)
				if style == "nature_bloom":
					SpellVFX.bloom(self, rig.global_position + Vector3(1.0, 0, 0.5))
				return
		"crystal_shield":
			AudioManager.play_sfx("shield")
			for uid: Variant in targets:
				_update_bubble(int(uid), state)
				var b: Node3D = bubbles.get(int(uid))
				if b:
					var s := b.scale
					b.scale = s * 0.1
					create_tween().tween_property(b, "scale", s, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			await get_tree().create_timer(0.35).timeout
			return
		"fungal_summon":
			_spawn_sentinel()
			await get_tree().create_timer(0.5).timeout
			return
		"chaos_gift":
			SpellFX.burst(self, rig.global_position + Vector3.UP, Color.from_hsv(randf(), 0.7, 1.0), 80, 4.0)
			await SpellVFX.screen_warp(get_tree().root, Color(1.0, 0.4, 0.9))
			return
		"fungal_eruption":
			for uid: Variant in targets:
				SpellVFX.impact(self, "fungal_eruption", world_pos(int(uid)), color, true)
			AudioManager.play_sfx("impact_fungal")
			shake(0.6)
			await get_tree().create_timer(0.45).timeout
			return
		"cosmic_gravity":
			var nodes: Array[Node3D] = []
			for uid: Variant in targets:
				nodes.append(rigs[int(uid)])
			await SpellVFX.gravity_well(self, (world_pos(int(targets[0])) + world_pos(int(targets[-1]))) * 0.5, nodes, color)
			AudioManager.play_sfx("impact_cosmic")
			shake(0.5)
			return
		"cosmic_star":
			await SpellVFX.falling_star(self, world_pos(target_uid), color)
			AudioManager.play_sfx("impact_cosmic")
			shake(1.0)
			SpellVFX.impact(self, "cosmic_star", world_pos(target_uid), color, true)
			return
		"chaos_rift":
			SpellVFX.screen_warp(get_tree().root, Color(1.0, 0.3, 0.7))
			AudioManager.play_sfx("impact_chaos")
			await SpellVFX.impact(self, "chaos_rift", world_pos(target_uid), color, true)
			return
		"nature_vines":
			AudioManager.play_sfx("impact_nature")
			SpellVFX.impact(self, "nature_vines", world_pos(target_uid), color)
			await get_tree().create_timer(0.35).timeout
			return
	# Default: projectile to each target then an impact.
	for uid: Variant in targets:
		var to := world_pos(int(uid)) + Vector3.UP * 0.9
		await SpellVFX.projectile(self, style, from, to, color)
		AudioManager.play_sfx("impact_" + element, -2.0)
		SpellVFX.impact(self, style, world_pos(int(uid)), color, style == "crystal_shards")


func _play_damage(e: Dictionary) -> void:
	var target := int(e["target"])
	var amount := int(e["amount"])
	var crit := bool(e.get("crit", false))
	var mult := float(e.get("mult", 1.0))
	var color := ElementChart.color(String(e.get("element", "fungal"))).lightened(0.3)
	var text := str(amount)
	if crit:
		text = "%d!" % amount
	if mult > 1.01:
		text += "  ▲"
	elif mult < 0.99:
		text += "  ▼"
	if int(e.get("absorbed", 0)) > 0:
		_number(target, "◆ %d" % int(e["absorbed"]), Color(0.5, 0.95, 1.0), false, 0.6)
	_number(target, text, Color(1.0, 0.95, 0.6) if crit else color, crit)
	var r: CreatureRig = rigs.get(target)
	if r and amount > 0:
		AudioManager.play_sfx("hit", -4.0)
		r.play_hit()
		if target == 0:
			shake(0.45)
		elif crit:
			shake(0.35)
	await get_tree().create_timer(0.18).timeout


func _status_popup(e: Dictionary) -> void:
	var fx: StatusEffectData = Database.status_effect(String(e["status"]))
	var col := fx.color if fx else Color.WHITE
	_number(int(e["target"]), String(e["name"]), col, false, 0.5)


func _number(uid: int, text: String, color: Color, big: bool, height_offset: float = 0.0) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = UiTheme.title_font()
	l.font_size = 120 if big else 84
	l.outline_size = 18
	l.outline_modulate = Color(0.12, 0.0, 0.2, 0.95)
	l.modulate = color
	l.pixel_size = 0.006
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 10
	add_child(l)
	var start := world_pos(uid) + Vector3(randf_range(-0.4, 0.4), 2.4 + height_offset, 0)
	l.global_position = start
	var tw := create_tween()
	tw.tween_property(l, "global_position", start + Vector3.UP * 1.3, 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 1.1).set_delay(0.5)
	if big:
		l.scale = Vector3.ONE * 0.4
		tw.parallel().tween_property(l, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(l.queue_free)
	number_shown.emit(uid, text, color)


func _update_bubble(uid: int, state: BattleState) -> void:
	var c := state.get_combatant(uid)
	var has := c != null and c.is_alive() and c.shield() > 0
	if has and not bubbles.has(uid):
		var b := SpellVFX.shield_bubble(Color(0.4, 0.95, 1.0))
		var rig: Node3D = rigs.get(uid)
		if rig:
			b.scale = Vector3.ONE * (1.6 if uid != 0 and (rig as CreatureRig).scale.x > 1.0 else 1.0)
			b.position = rig.position
			add_child(b)
			bubbles[uid] = b
	elif not has and bubbles.has(uid):
		(bubbles[uid] as Node).queue_free()
		bubbles.erase(uid)


func _spawn_sentinel() -> void:
	if sentinel:
		return
	sentinel = CreatureBuilder.build("sporeling")
	sentinel.scale = Vector3.ONE * 0.8
	add_child(sentinel)
	sentinel.position = PLAYER_POS + Vector3(-2.0, 0, -0.8)
	sentinel.rotation.y = PI
	SpellFX.burst(self, sentinel.global_position + Vector3.UP * 0.5, Color(0.8, 0.5, 1.0), 50)


func play_victory() -> void:
	var r: CreatureRig = rigs.get(0)
	await move_camera(_framing(Vector3(2.5, 2.4, 9.5), PLAYER_POS + Vector3.UP * 1.3), 0.8)
	if r:
		r.play_victory()
	for i in 3:
		SpellFX.burst(self, PLAYER_POS + Vector3(randf_range(-2, 2), 2.5, randf_range(-2, 2)), Color.from_hsv(randf(), 0.6, 1.0), 50, 6.0)
		await get_tree().create_timer(0.25).timeout


func play_defeat() -> void:
	var r: CreatureRig = rigs.get(0)
	if r:
		r.play_death()
	await move_camera(_framing(Vector3(0, 9, 12), PLAYER_POS), 1.2)
