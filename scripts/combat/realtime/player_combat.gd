class_name PlayerCombat
extends Node
## Real-time combat for the player: light combos, charged heavy attacks,
## dodge with invulnerability, block and perfect parry, bow with draw and
## arrow types, weapon switching, class abilities, stamina, and taking hits.
## Reads intent from CombatInput (keyboard/mouse/gamepad/touch).

signal changed()
signal combat_mode_changed(on: bool)
signal ability_cast(ability_id: String)

const HEAVY_HOLD := 0.32
const COMBAT_LINGER := 3.5
const ARROW_TYPES: Array[Dictionary] = [
	{"id": "normal", "name": "Arrow", "color": Color(0.9, 0.9, 1.0), "item": ""},
	{"id": "fire", "name": "Ember Arrow", "color": Color(1.0, 0.5, 0.2), "item": "ember_arrow", "status": {"burn": 4.0}},
	{"id": "frost", "name": "Frost Arrow", "color": Color(0.6, 0.95, 1.0), "item": "frost_arrow", "status": {"slow": 4.0}},
	{"id": "spore", "name": "Spore Arrow", "color": Color(0.8, 0.4, 1.0), "item": "spore_arrow", "status": {"spores": 5.0}},
]

var player: PlayerController
var avatar: PlayerAvatar
var stamina: float = 100.0
var max_stamina: float = 100.0
var combat_mode: bool = false
var lock_target: Node3D
var cooldowns: Dictionary = {}
var buffs: Dictionary = {}
var shield_hp: float = 0.0
var arrow_type: int = 0
var draw: float = -1.0
var invuln: float = 0.0
var dead: bool = false

var _attack_hold: float = -1.0
var _attack_cd: float = 0.0
var _combo: int = 0
var _combo_timer: float = 0.0
var _stamina_delay: float = 0.0
var _block_started: float = -10.0
var _blocking: bool = false
var _guard_broken: float = 0.0
var _dodge_time: float = 0.0
var _dodge_dir: Vector3
var _combat_linger: float = 0.0
var _vanish_cd: float = 0.0
var _regen_acc: float = 0.0
var _casts: int = 0
var _time: float = 0.0


func _ready() -> void:
	name = "Combat"
	EventBus.rt_enemy_aggro.connect(func(_e: Node) -> void: _combat_linger = COMBAT_LINGER)
	EventBus.equipment_changed.connect(_on_equipment)
	refresh_class()


func refresh_class() -> void:
	var c := Game.profile.player_class() if Game.profile else null
	max_stamina = float(c.feel.get("stamina", 100.0)) if c else 100.0
	stamina = max_stamina
	changed.emit()


func _on_equipment() -> void:
	if is_instance_valid(avatar) and Game.profile:
		avatar.refresh_equipment(Game.profile.inventory.equipment)


# ------------------------------------------------------------------ equipment helpers
func weapon() -> ItemData:
	return _equipped("staff")


func shield() -> ItemData:
	var d := _equipped("offhand")
	return d if d and d.weapon_kind == "shield" else null


func bow() -> ItemData:
	return _equipped("ranged")


func _equipped(slot: String) -> ItemData:
	if Game.profile == null:
		return null
	var id: String = Game.profile.inventory.equipment.get(slot, "")
	return Database.item(id) if id != "" else null


## Specials only wake for the item's own calling (shared items always work).
func has_special(sp: String) -> bool:
	if Game.profile == null:
		return false
	for slot: String in Game.profile.inventory.equipment.keys():
		var d := _equipped(slot)
		if d and d.special == sp and (d.class_id == "" or d.class_id == Game.profile.class_id):
			return true
	return false


func stat(s: String) -> float:
	return Game.profile.stats.get_stat(s) if Game.profile else 0.0


func feel(k: String, default: float = 1.0) -> float:
	var c := Game.profile.player_class() if Game.profile else null
	return float(c.feel.get(k, default)) if c else default


func power_mult() -> float:
	var m := 1.0 + 0.06 * float(Game.profile.stats.level - 1) if Game.profile else 1.0
	if _buff("colossus"):
		m *= 1.6
	if _buff("hexed"):
		m *= 0.75
	if _buff("empower"):
		m *= 1.3
	return m


func spell_mult() -> float:
	return (1.0 + stat("spell_power") / 60.0) * power_mult()


func _buff(b: String) -> bool:
	return float(buffs.get(b, 0.0)) > 0.0


func is_busy() -> bool:
	return _dodge_time > 0.0 or _guard_broken > 0.0 or dead


# ------------------------------------------------------------------ main loop
func process_input(inp: CombatInput, delta: float) -> void:
	_time += delta
	_tick(delta)
	if dead:
		return
	if inp.lock:
		toggle_lock()
	if inp.switch_weapon:
		if draw >= 0.0:
			cycle_arrow()
		else:
			switch_weapon()
	for i in inp.abilities.size():
		if inp.abilities[i]:
			use_ability_slot(i)
	if inp.dodge:
		dodge(inp.move_dir)
	set_blocking(inp.block and not is_busy())
	# Bow: hold to draw, release to loose.
	if inp.bow and not _blocking and not is_busy() and bow() != null:
		if draw < 0.0:
			draw = 0.0
			AudioManager.play_sfx("card_draw", -6.0, 0.7)
		var speed := maxf(0.4, bow().attack_speed) * (1.25 if Game.profile and Game.profile.class_id == "assassin" else 1.0)
		draw = minf(1.0, draw + delta * speed)
	elif draw >= 0.0:
		_release_arrow()
	# Attack: tap = light combo, hold = charged heavy.
	if inp.attack and not _blocking and draw < 0.0:
		if _attack_hold < 0.0:
			_attack_hold = 0.0
		_attack_hold += delta
		if _attack_hold >= HEAVY_HOLD * 1.6:
			heavy_attack()
			_attack_hold = -100.0
	elif _attack_hold != -1.0:
		if _attack_hold >= HEAVY_HOLD:
			heavy_attack()
		elif _attack_hold >= 0.0:
			light_attack()
		_attack_hold = -1.0
	if not inp.attack and _attack_hold < -1.0:
		_attack_hold = -1.0


func _tick(delta: float) -> void:
	_attack_cd -= delta
	_combo_timer -= delta
	if _combo_timer <= 0.0:
		_combo = 0
	_guard_broken -= delta
	_vanish_cd -= delta
	invuln -= delta
	_stamina_delay -= delta
	if _stamina_delay <= 0.0 and not _blocking:
		stamina = minf(max_stamina, stamina + 30.0 * delta)
	for k: String in cooldowns.keys():
		cooldowns[k] = maxf(0.0, float(cooldowns[k]) - delta)
	var expired: Array = []
	for k: String in buffs.keys():
		buffs[k] = float(buffs[k]) - delta
		if float(buffs[k]) <= 0.0:
			expired.append(k)
	for k: String in expired:
		buffs.erase(k)
		_on_buff_end(k)
	if shield_hp > 0.0 and not _buff("soul_shield"):
		shield_hp = 0.0
	# Dodge movement.
	if _dodge_time > 0.0:
		_dodge_time -= delta
		player.velocity.x = _dodge_dir.x
		player.velocity.z = _dodge_dir.z
	# Regeneration (health from class/gear, mana always trickles back).
	var prof := Game.profile
	if prof and not dead:
		_regen_acc += delta
		if _regen_acc >= 0.5:
			var hr := stat("health_regen") + (2.0 if _buff("barkskin") else 0.0)
			if hr > 0.0 and prof.stats.health < prof.stats.max_health():
				prof.stats.heal(hr * _regen_acc)
			var mr := (0.22 if combat_mode else 0.6) * (1.0 + stat("mana_regen"))
			if prof.stats.mana < prof.stats.max_mana():
				prof.stats.restore_mana(mr * _regen_acc)
			_regen_acc = 0.0
	# Combat mode follows aware enemies nearby.
	_combat_linger -= delta
	var near := false
	for e in get_tree().get_nodes_in_group(RtFx.ENEMY_GROUP):
		var wc := e as WorldCreature
		if wc and wc.aware and not wc.dead and wc.global_position.distance_to(player.global_position) < 28.0:
			near = true
			break
	if near:
		_combat_linger = COMBAT_LINGER
	var want := _combat_linger > 0.0 or draw >= 0.0
	if want != combat_mode:
		combat_mode = want
		combat_mode_changed.emit(want)
		Game.in_combat = want
		if not want:
			lock_target = null
	if is_instance_valid(lock_target) and (bool(lock_target.get("dead")) or lock_target.global_position.distance_to(player.global_position) > 30.0):
		lock_target = null
	changed.emit()


# ------------------------------------------------------------------ actions
func _spend(cost: float) -> bool:
	if stamina < cost * 0.5:
		if stamina < 1.0:
			EventBus.notify("Too tired!", "warning")
		return false
	stamina = maxf(0.0, stamina - cost)
	_stamina_delay = 0.7
	return true


func facing() -> Vector3:
	var f := -player.global_basis.z
	f.y = 0.0
	return f.normalized()


func light_attack() -> void:
	if is_busy() or _attack_cd > 0.0:
		return
	var w := weapon()
	var kind := w.weapon_kind if w else "fist"
	var speed := w.attack_speed if w and w.attack_speed > 0.0 else 1.6
	if not _spend(6.0 if kind != "dagger" else 4.0):
		return
	_attack_cd = 1.0 / speed
	_combo = (_combo % (4 if kind == "dagger" else 3)) + 1
	_combo_timer = 1.0 / speed + 0.5
	_combat_linger = COMBAT_LINGER
	var dmg: float = (w.damage if w and w.damage > 0.0 else 5.0 + stat("spell_power") * 0.1) * [1.0, 1.0, 1.12, 1.4, 1.6][_combo] * power_mult()
	if is_instance_valid(avatar):
		avatar.swing(false, speed)
	AudioManager.play_sfx("card_select", -4.0, randf_range(1.2, 1.5))
	if kind == "wand":
		_fire_bolt(dmg, Color(0.55, 0.7, 1.0), false)
		return
	_melee(dmg, w.reach if w else 1.8, kind in ["sword", "greatsword", "axe", "hammer"] or (w and w.special == "cleave"), 0.0, false)


func heavy_attack() -> void:
	if is_busy() or _attack_cd > 0.0:
		return
	var w := weapon()
	if not _spend(18.0):
		return
	var speed := w.attack_speed if w and w.attack_speed > 0.0 else 1.6
	_attack_cd = 1.4 / speed
	_combo = 0
	_combat_linger = COMBAT_LINGER
	var dmg := (w.damage if w and w.damage > 0.0 else 5.0) * 2.2 * power_mult()
	if is_instance_valid(avatar):
		avatar.swing(true, speed)
	AudioManager.play_sfx("enemy_attack", -2.0, 0.8)
	var sp := w.special if w else ""
	if w and w.class_id != "" and Game.profile and w.class_id != Game.profile.class_id:
		sp = ""
	match sp:
		"shockwave":
			var c := player.global_position + facing() * 1.5
			RtFx.burst(player.get_parent(), c, Color(0.3, 1.0, 0.9), 40, 0.25, 7.0)
			RtFx.area_hit(get_tree(), c, 4.0 if not _buff("colossus") else 6.0, RtFx.ENEMY_GROUP, _hit(dmg * 0.9, "melee", {"stagger": 1.2, "heavy": true, "knockback": facing() * 2.0}))
			return
		"soul_bolt", "arcane_missile":
			_fire_bolt(dmg, Color(0.5, 1.0, 1.0) if sp == "soul_bolt" else Color(0.6, 0.6, 1.0), true)
			if sp == "soul_bolt":
				_melee(dmg * 0.5, w.reach, false, 1.0, true)
			return
		"moon_arc":
			RtFx.shoot(player.get_parent(), _muzzle(), _aim_dir(), 20.0, _hit(dmg * 0.8, "magic", {"stagger": 1.0}), Color(1.0, 0.95, 0.7), RtFx.ENEMY_GROUP, {"pierce": true, "life": 0.9, "radius": 1.2})
	if w and w.weapon_kind == "wand":
		_fire_bolt(dmg, Color(0.6, 0.6, 1.0), true)
		return
	_melee(dmg, (w.reach if w else 1.8) + 0.3, true, 1.0, true)


func _hit(amount: float, kind: String, extra: Dictionary = {}) -> Dictionary:
	var h := {"amount": amount, "kind": kind, "source": player}
	var crit_chance := stat("crit_chance") + (25.0 if _buff("vanish") else 0.0)
	if randf() * 100.0 < crit_chance:
		h["amount"] = amount * 1.75
		h["crit"] = true
	if has_special("backstab_bonus"):
		h["backstab_mult"] = 2.0
	for k: String in extra.keys():
		h[k] = extra[k]
	return h


func _melee(dmg: float, reach: float, cleave: bool, stagger: float, heavy: bool) -> void:
	if _buff("colossus"):
		reach += 1.0
	var origin := player.global_position + Vector3.UP * 0.9
	var fwd := facing()
	var targets: Array[Node3D] = []
	for e in get_tree().get_nodes_in_group(RtFx.ENEMY_GROUP):
		var t := e as Node3D
		if t == null or bool(t.get("dead")):
			continue
		var to := t.global_position - player.global_position
		to.y = 0.0
		var d := to.length() - RtFx._radius_of(t)
		if d > reach:
			continue
		if d > 0.3 and fwd.dot(to.normalized()) < (0.25 if cleave else 0.55):
			continue
		targets.append(t)
	# Soft aim: if nothing is in front but the lock target is close, hit it.
	if targets.is_empty() and is_instance_valid(lock_target) and lock_target.global_position.distance_to(player.global_position) - RtFx._radius_of(lock_target) < reach + 0.4:
		targets.append(lock_target)
	if not cleave and targets.size() > 1:
		targets.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.global_position.distance_to(origin) < b.global_position.distance_to(origin))
		targets = [targets[0]]
	for t in targets:
		t.call("take_hit", _hit(dmg, "melee", {"from": player.global_position, "stagger": stagger, "heavy": heavy, "knockback": fwd * (1.2 if heavy else 0.3)}))
		RtFx.burst(player.get_parent(), t.global_position + Vector3.UP * 0.9, Color(1.0, 0.85, 0.6), 8, 0.08, 3.0)
		if _buff("link") and Game.profile:
			Game.profile.stats.heal(dmg * 0.2)
	if targets.is_empty():
		AudioManager.play_sfx("miss", -10.0)


func _muzzle() -> Vector3:
	return player.global_position + Vector3.UP * 1.3 + facing() * 0.6


func _aim_dir() -> Vector3:
	if is_instance_valid(lock_target):
		return (lock_target.global_position + Vector3.UP * 0.8 - _muzzle()).normalized()
	return -player.camera.global_basis.z


func _fire_bolt(dmg: float, col: Color, big: bool) -> void:
	var target := lock_target if is_instance_valid(lock_target) else RtFx.nearest(get_tree(), player.global_position, facing(), RtFx.ENEMY_GROUP, 26.0, 0.6)
	RtFx.shoot(player.get_parent(), _muzzle(), _aim_dir(), 24.0 if not big else 20.0, _hit(dmg, "magic", {"stagger": 1.0 if big else 0.0}), col, RtFx.ENEMY_GROUP,
		{"homing": target, "turn": 5.0, "radius": 0.6 if big else 0.45, "life": 1.6})


func _release_arrow() -> void:
	var b := bow()
	var charge := draw
	draw = -1.0
	if b == null or charge < 0.15:
		return
	if not _spend(5.0):
		return
	var at: Dictionary = ARROW_TYPES[arrow_type]
	if String(at["item"]) != "" and Game.profile:
		if not Game.profile.inventory.has(String(at["item"])):
			arrow_type = 0
			at = ARROW_TYPES[0]
		else:
			Game.profile.inventory.remove(String(at["item"]), 1)
	var dmg := b.damage * (0.35 + 0.65 * charge) * power_mult()
	var extra := {"stagger": 0.6 if charge >= 1.0 else 0.0}
	if at.has("status"):
		extra["status"] = at["status"]
	var silent := has_special("silent")
	if silent:
		extra["silent"] = true
		if charge >= 1.0:
			extra["backstab_mult"] = 1.75
	var h := _hit(dmg, "arrow", extra)
	if silent and charge >= 1.0:
		h["crit"] = true
	var spd := 30.0 + 25.0 * charge
	RtFx.shoot(player.get_parent(), _muzzle(), _aim_dir() + Vector3.UP * 0.02, spd, h, at["color"], RtFx.ENEMY_GROUP, {"gravity": 5.0, "life": 3.0, "radius": 0.5})
	AudioManager.play_sfx("miss", -3.0, 1.6)
	_combat_linger = COMBAT_LINGER


func cycle_arrow() -> void:
	for i in ARROW_TYPES.size():
		arrow_type = (arrow_type + 1) % ARROW_TYPES.size()
		var it := String(ARROW_TYPES[arrow_type]["item"])
		if it == "" or (Game.profile and Game.profile.inventory.has(it)):
			break
	EventBus.notify("Arrows: %s" % ARROW_TYPES[arrow_type]["name"], "info")


## Cycles main-hand weapons carried in the satchel.
func switch_weapon() -> void:
	var prof := Game.profile
	if prof == null:
		return
	var current := weapon()
	var candidates: Array[String] = []
	for s: Dictionary in prof.inventory.slots:
		var d := Database.item(String(s["id"]))
		if d and d.is_weapon() and d.weapon_kind != "bow" and d.equip_slot == "staff":
			candidates.append(d.id)
	if candidates.is_empty():
		EventBus.notify("No other weapon in your satchel.", "info")
		return
	prof.inventory.equip(candidates[0])
	var nw := weapon()
	EventBus.notify("Switched to %s" % (nw.display_name if nw else "bare hands"), "item")


func dodge(move_dir: Vector3) -> void:
	if is_busy() or draw >= 0.0:
		return
	if not _spend(20.0):
		return
	var dir := move_dir if move_dir.length() > 0.1 else -facing()
	var dist := 5.2 * feel("dodge", 1.0) * (1.4 if has_special("phantom_dash") else 1.0)
	var t := 0.26
	_dodge_dir = dir.normalized() * (dist / t)
	_dodge_time = t
	invuln = t + 0.12
	if is_instance_valid(avatar):
		avatar.dodge_spin()
	AudioManager.play_sfx("bounce", -10.0, 1.6)
	RtFx.burst(player.get_parent(), player.global_position + Vector3.UP * 0.5, Color(0.6, 0.5, 1.0), 10, 0.1, 2.0)


func set_blocking(on: bool) -> void:
	if on and not _blocking:
		_block_started = _time
	_blocking = on
	if is_instance_valid(avatar):
		avatar.set_block(on)


func is_blocking() -> bool:
	return _blocking


func toggle_lock() -> void:
	if is_instance_valid(lock_target):
		lock_target = null
		return
	lock_target = RtFx.nearest(get_tree(), player.global_position, facing(), RtFx.ENEMY_GROUP, 24.0, -0.2)
	if lock_target:
		_combat_linger = COMBAT_LINGER


func use_ability_slot(i: int) -> void:
	if Game.profile == null:
		return
	var list := Game.profile.usable_abilities()
	if i >= list.size():
		return
	cast_ability(list[i])


func cast_ability(a: AbilityData) -> bool:
	var prof := Game.profile
	if prof == null or dead or _guard_broken > 0.0:
		return false
	if float(cooldowns.get(a.id, 0.0)) > 0.0:
		AudioManager.play_ui("ui_error")
		return false
	_casts += 1
	var free := has_special("astral_echo") and _casts % 4 == 0
	var cost := 0.0 if free else a.mana_cost
	if prof.stats.mana < cost:
		EventBus.notify("Not enough mana for %s." % a.display_name, "warning")
		_casts -= 1
		return false
	if not AbilityRunner.cast(self, a, 2.0 if free else 1.0):
		_casts -= 1
		return false
	prof.stats.mana -= cost
	prof.stats.changed.emit()
	var cd := a.cooldown * (0.85 if has_special("grimoire") else 1.0)
	cooldowns[a.id] = cd
	if free:
		RtFx.number(player.get_parent(), player.global_position + Vector3.UP * 2.2, "ASTRAL ECHO", UiTheme.GOLD, true)
	if is_instance_valid(avatar):
		avatar.cast()
	ability_cast.emit(a.id)
	EventBus.ability_used.emit(a.id)
	return true


func cooldown_ratio(a: AbilityData) -> float:
	return clampf(float(cooldowns.get(a.id, 0.0)) / maxf(0.01, a.cooldown), 0.0, 1.0)


func _on_buff_end(b: String) -> void:
	match b:
		"colossus":
			player.scale = Vector3.ONE
			EventBus.notify("You shrink back to your usual self.", "info")
		"vanish":
			if is_instance_valid(avatar):
				avatar.visible = true


# ------------------------------------------------------------------ being hit
## Enemies (and their projectiles/zones) call this through PlayerController.
func receive_hit(hit: Dictionary) -> void:
	var prof := Game.profile
	if prof == null or dead:
		return
	_combat_linger = COMBAT_LINGER
	var amount := float(hit.get("amount", 0.0))
	var kind := String(hit.get("kind", "melee"))
	var src: Node = hit.get("source", null)
	var pos := player.global_position + Vector3.UP * 1.8
	if invuln > 0.0:
		RtFx.number(player.get_parent(), pos, "DODGED", UiTheme.GLOW)
		return
	if randf() * 100.0 < stat("evasion") + (60.0 if _in_smoke() else 0.0):
		RtFx.number(player.get_parent(), pos, "EVADED", UiTheme.GLOW)
		return
	var blocked := false
	if _blocking:
		var sh := shield()
		var window := sh.parry_window if sh else 0.14
		var from: Vector3 = hit.get("from", player.global_position)
		var to := from - player.global_position
		to.y = 0.0
		var in_front := to.length() < 0.1 or facing().dot(to.normalized()) > 0.1
		if in_front:
			if _time - _block_started <= window:
				# Perfect parry: nothing gets through and the attacker reels.
				RtFx.number(player.get_parent(), pos, "PARRY!", UiTheme.GOLD, true)
				AudioManager.play_sfx("shield", 0.0, 1.4)
				if src and src.has_method("take_hit") and not bool(hit.get("projectile", false)):
					src.call("take_hit", {"amount": (weapon().damage if weapon() else 6.0) * power_mult(), "kind": "melee", "stagger": 1.8, "from": player.global_position, "source": player})
				stamina = minf(max_stamina, stamina + 15.0)
				return
			var power := sh.block_power if sh else 0.35
			if sh and sh.special == "ethereal" and has_special("ethereal") and kind == "magic":
				power = 1.0
			var cost := amount * 1.2
			if stamina >= cost:
				stamina -= cost
				_stamina_delay = 0.8
				amount *= 1.0 - power
				blocked = true
				AudioManager.play_sfx("shield", -4.0)
				if sh and sh.special == "spore_guard" and has_special("spore_guard") and src and src.has_method("take_hit"):
					src.call("take_hit", {"amount": 5.0 * power_mult(), "kind": "magic", "status": {"spores": 3.0}, "from": player.global_position, "silent": true})
			else:
				stamina = 0.0
				_guard_broken = 0.9
				set_blocking(false)
				RtFx.number(player.get_parent(), pos, "GUARD BROKEN", UiTheme.DANGER, true)
	if shield_hp > 0.0:
		var absorbed := minf(shield_hp, amount)
		shield_hp -= absorbed
		amount -= absorbed
	if kind == "magic":
		amount *= 1.0 - clampf(stat("magic_resist") / 100.0, 0.0, 0.75)
	var defense := stat("defense") + (12.0 if _buff("barkskin") else 0.0)
	amount = maxf(1.0 if amount > 0.0 else 0.0, amount - defense * 0.4)
	if _buff("colossus"):
		amount *= 0.5
	if has_special("thorns") and kind == "melee" and src and src.has_method("take_hit"):
		src.call("take_hit", {"amount": amount * 0.15 + 2.0, "kind": "melee", "from": player.global_position, "silent": true})
	var effect := String(hit.get("effect", ""))
	if effect == "hexed":
		buffs["hexed"] = 4.0
		RtFx.number(player.get_parent(), pos + Vector3.UP * 0.3, "HEXED", Color(0.6, 1.0, 0.3))
	prof.stats.health = maxf(0.0, prof.stats.health - amount)
	prof.stats.changed.emit()
	if amount > 0.0:
		RtFx.number(player.get_parent(), pos, "-%d" % int(round(amount)), UiTheme.DANGER if not blocked else UiTheme.TEXT_DIM)
	EventBus.player_hit.emit(amount, blocked)
	if is_instance_valid(avatar):
		avatar.hurt()
	# Cloak of Vanishing.
	if has_special("vanish") and _vanish_cd <= 0.0 and prof.stats.health < prof.stats.max_health() / 3.0 and prof.stats.health > 0.0:
		_vanish_cd = 30.0
		buffs["vanish"] = 3.0
		if is_instance_valid(avatar):
			avatar.visible = false
		EventBus.notify("The cloak swallows you.", "success")
	if prof.stats.health <= 0.0:
		_die()


func _in_smoke() -> bool:
	for z in get_tree().get_nodes_in_group("rt_smoke"):
		if (z as RtFx.Zone).contains(player):
			return true
	return false


## Enemies lose track of the player while vanished or wrapped in smoke.
func is_hidden_from(_enemy: Node) -> bool:
	return _buff("vanish") or _buff("nightfall_hide") or _in_smoke()


func _die() -> void:
	dead = true
	EventBus.player_died.emit()
	EventBus.notify("The dream goes dark...", "error")
	AudioManager.play_sfx("defeat")
	player.set_enabled(false)
	await get_tree().create_timer(2.0).timeout
	# Wake again at the last safe place; enemies forget you. No item loss.
	var prof := Game.profile
	if prof:
		prof.stats.health = prof.stats.max_health() * 0.6
		prof.stats.mana = prof.stats.max_mana() * 0.5
		prof.stats.changed.emit()
	for e in get_tree().get_nodes_in_group(RtFx.ENEMY_GROUP):
		var wc := e as WorldCreature
		if wc and wc.aware:
			wc.state = WorldCreature.State.RETURN
			wc.aware = false
	var root := get_tree().get_first_node_in_group("game_root")
	var region: Region = root.get("region") if root else null
	if region:
		var sp := region.get_spawn(String(prof.world.flags.get("last_rest", "default")) if prof else "default")
		player.place_at(sp["position"], float(sp["yaw"]))
	dead = false
	buffs.clear()
	shield_hp = 0.0
	stamina = max_stamina
	_combat_linger = 0.0
	player.set_enabled(true)
	EventBus.notify("You wake again, a little wiser.", "info")
