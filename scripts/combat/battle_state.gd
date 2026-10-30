class_name BattleState
extends RefCounted
## Authoritative combat rules. Pure logic: no nodes, no rendering, seeded
## RNG. Every operation returns a list of event dictionaries that the
## presentation layer replays. A future server can run this class unchanged
## and stream the events to clients.
##
## Event types: cast, damage, heal, miss, status_applied, status_tick,
## status_expired, shield, mana, draw, stunned, interrupted, charge_start,
## charge_release, phase, death, text, flee.

const K := StatusEffectData.Kind
const TT := SpellData.TargetType
const MEDITATE_MANA := 3
const FLEE_CHANCE := 0.75

var rng := RandomNumberGenerator.new()
var encounter: EncounterData
var player: Combatant
var enemies: Array[Combatant] = []
var deck := Deck.new()
var mana: int = 0
var max_mana: int = 6
var mana_regen: int = 2
var round_number: int = 0
var bonuses: Dictionary = {}
var spell_power: float = 0.0
var magic_power: float = 10.0
var crit_chance: float = 5.0
var replaced_this_turn: bool = false
var spell_lookup: Callable
var status_lookup: Callable


## snapshot: {name, health, max_health, mana, max_mana, defense, spell_power,
##            magic_power, crit_chance, bonuses: {}, deck: PackedStringArray}
static func create(enc: EncounterData, snapshot: Dictionary, seed_value: int, spells: Callable, statuses: Callable) -> BattleState:
	var b := BattleState.new()
	b.rng.seed = seed_value
	b.encounter = enc
	b.spell_lookup = spells
	b.status_lookup = statuses
	var p := Combatant.new()
	p.uid = 0
	p.team = 0
	p.display_name = String(snapshot.get("name", "Dreamer"))
	p.max_hp = int(snapshot.get("max_health", 100))
	p.hp = clampi(int(snapshot.get("health", p.max_hp)), 1, p.max_hp)
	p.base_defense = int(snapshot.get("defense", 4))
	p.element = "fungal"
	p.speed = 12
	p.level = int(snapshot.get("level", 1))
	b.player = p
	b.max_mana = int(snapshot.get("max_mana", 6))
	b.mana = clampi(int(snapshot.get("mana", b.max_mana)), 0, b.max_mana)
	b.spell_power = float(snapshot.get("spell_power", 0.0))
	b.magic_power = float(snapshot.get("magic_power", 10.0))
	b.crit_chance = float(snapshot.get("crit_chance", 5.0))
	b.bonuses = snapshot.get("bonuses", {})
	b.mana_regen = 2 + int(b.bonuses.get("mana_regen", 0))
	var uid := 1
	for cd: CreatureData in enc.enemies:
		var e := Combatant.new()
		e.uid = uid
		uid += 1
		e.team = 1
		e.data = cd
		e.display_name = cd.display_name
		e.max_hp = cd.max_health
		e.hp = cd.max_health
		e.base_defense = cd.defense
		e.power = cd.power
		e.element = cd.element
		e.speed = cd.speed
		e.level = cd.level
		b.enemies.append(e)
	# Disambiguate duplicate names ("Sporeling A", "Sporeling B").
	var counts := {}
	for e: Combatant in b.enemies:
		counts[e.display_name] = int(counts.get(e.display_name, 0)) + 1
	var seen := {}
	for e: Combatant in b.enemies:
		if int(counts[e.display_name]) > 1:
			var n := int(seen.get(e.display_name, 0))
			seen[e.display_name] = n + 1
			e.display_name = "%s %s" % [e.display_name, char(65 + n)]
	b.deck.setup(snapshot.get("deck", PackedStringArray()), b.rng)
	return b


func get_combatant(uid: int) -> Combatant:
	if uid == 0:
		return player
	for e: Combatant in enemies:
		if e.uid == uid:
			return e
	return null


func living_enemies() -> Array[Combatant]:
	return enemies.filter(func(e: Combatant) -> bool: return e.is_alive())


func outcome() -> String:
	if not player.is_alive():
		return "defeat"
	if living_enemies().is_empty():
		return "victory"
	return ""


func spell(id: String) -> SpellData:
	return spell_lookup.call(id) as SpellData


# ------------------------------------------------------------------ player turn
func start_player_turn() -> Array[Dictionary]:
	var ev: Array[Dictionary] = []
	round_number += 1
	replaced_this_turn = false
	if round_number > 1:
		var before := mana
		mana = mini(max_mana, mana + mana_regen)
		if mana != before:
			ev.append({"type": "mana", "amount": mana - before, "total": mana})
	var drawn := deck.fill_hand()
	if drawn > 0:
		ev.append({"type": "draw", "count": drawn})
	return ev


## Returns "" if castable, otherwise the reason.
func can_cast(hand_index: int) -> String:
	if hand_index < 0 or hand_index >= deck.hand.size():
		return "No such card"
	var sp := spell(deck.hand[hand_index])
	if sp == null:
		return "Unknown spell"
	if sp.mana_cost > mana:
		return "Not enough mana"
	return ""


func cast(hand_index: int, target_uid: int) -> Array[Dictionary]:
	if can_cast(hand_index) != "":
		return []
	var id := deck.play(hand_index)
	var sp := spell(id)
	mana -= sp.mana_cost
	var ev: Array[Dictionary] = []
	if sp.mana_cost > 0:
		ev.append({"type": "mana", "amount": -sp.mana_cost, "total": mana})
	ev.append_array(resolve(player, sp, target_uid))
	if sp.mana_gain > 0:
		mana = mini(max_mana, mana + sp.mana_gain)
		ev.append({"type": "mana", "amount": sp.mana_gain, "total": mana})
	if sp.draw_cards > 0:
		var n := deck.draw(sp.draw_cards)
		ev.append({"type": "draw", "count": n})
	return ev


func meditate() -> Array[Dictionary]:
	var before := mana
	mana = mini(max_mana, mana + MEDITATE_MANA)
	return [{"type": "cast", "caster": 0, "targets": [0], "spell": "", "style": "meditate"}, {"type": "mana", "amount": mana - before, "total": mana}, {"type": "text", "text": "You listen to the Mycelium and gather your mana."}]


func replace_card(hand_index: int) -> Array[Dictionary]:
	if replaced_this_turn or hand_index < 0 or hand_index >= deck.hand.size():
		return []
	replaced_this_turn = true
	var old := deck.replace(hand_index)
	return [{"type": "replace", "old": old, "index": hand_index}]


func try_flee() -> Array[Dictionary]:
	if encounter and not encounter.can_flee:
		return [{"type": "text", "text": "There is no escape from this one."}]
	var ok := rng.randf() < FLEE_CHANCE
	return [{"type": "flee", "success": ok}]


# ------------------------------------------------------------------ resolution
func _targets_for(caster: Combatant, sp: SpellData, target_uid: int) -> Array[Combatant]:
	var foes: Array[Combatant] = []
	if caster.team == 0:
		foes = living_enemies()
	elif player.is_alive():
		foes = [player]
	match sp.target_type:
		TT.SELF:
			return [caster]
		TT.ALL_ENEMIES:
			return foes
		TT.RANDOM_ENEMY:
			if foes.is_empty():
				return []
			return [foes[rng.randi() % foes.size()]]
	var t := get_combatant(target_uid)
	if t == null or not t.is_alive() or t.team == caster.team:
		if foes.is_empty():
			return []
		t = foes[0]
	return [t]


## Resolves a spell/ability from caster. Shared by player and creatures.
func resolve(caster: Combatant, sp: SpellData, target_uid: int) -> Array[Dictionary]:
	var ev: Array[Dictionary] = []
	var targets := _targets_for(caster, sp, target_uid)
	var uids: Array[int] = []
	for t: Combatant in targets:
		uids.append(t.uid)
	ev.append({"type": "cast", "caster": caster.uid, "targets": uids, "spell": sp.id, "style": sp.vfx_style, "element": sp.element, "name": sp.display_name})
	if sp.special == "chaos_rift":
		for t: Combatant in targets:
			ev.append_array(_chaos_rift(caster, t, sp))
		return ev
	for t: Combatant in targets:
		var offensive := t.team != caster.team
		if offensive and sp.base_damage > 0:
			if rng.randf() > sp.accuracy - t.evasion():
				ev.append({"type": "miss", "source": caster.uid, "target": t.uid})
				continue
			ev.append_array(deal_damage(caster, t, sp.base_damage, sp.element, sp.armor_pierce, sp.damage_variance))
		if sp.healing_value > 0:
			ev.append_array(heal(t if not offensive else caster, _heal_amount(caster, sp.healing_value)))
		if not t.is_alive():
			continue
		for fx: StatusEffectData in sp.status_effects:
			var recipient := caster if fx.apply_to_self else t
			if not recipient.is_alive():
				continue
			if fx.chance < 1.0 and rng.randf() > fx.chance:
				ev.append({"type": "text", "text": "%s resisted %s." % [recipient.display_name, fx.display_name]})
				continue
			ev.append(apply_status(caster, recipient, fx))
	return ev


func _scaling(caster: Combatant) -> float:
	if caster.team == 0:
		return (1.0 + spell_power / 100.0) * (1.0 + (magic_power - 10.0) / 60.0)
	return 1.0 + caster.power / 100.0


func _heal_amount(caster: Combatant, base: int) -> int:
	if caster.team == 0:
		return int(round(base * (1.0 + spell_power / 200.0 + float(bonuses.get("heal_bonus", 0.0)))))
	return int(round(base * (1.0 + caster.power / 200.0)))


func deal_damage(caster: Combatant, target: Combatant, base: int, element: String, pierce: float, variance: float) -> Array[Dictionary]:
	var ev: Array[Dictionary] = []
	var roll := rng.randf_range(1.0 - variance, 1.0 + variance)
	var elem := ElementChart.multiplier(element, target.element)
	var crit_c := crit_chance if caster.team == 0 else 5.0
	var crit := rng.randf() * 100.0 < crit_c
	var def := target.defense() * (1.0 - pierce)
	var reduction := def / (def + 40.0)
	var raw := base * roll * _scaling(caster) * elem * caster.damage_out_mult() * target.damage_in_mult() * (1.0 - reduction) * (1.5 if crit else 1.0)
	var amount := maxi(1, int(round(raw)))
	var absorbed := target.absorb(amount)
	var dealt := amount - absorbed
	target.hp = maxi(0, target.hp - dealt)
	ev.append({"type": "damage", "source": caster.uid, "target": target.uid, "amount": dealt, "absorbed": absorbed, "crit": crit, "element": element, "mult": elem, "hp": target.hp})
	if absorbed > 0:
		ev.append({"type": "shield", "target": target.uid, "amount": -absorbed, "total": target.shield()})
	if not target.is_alive():
		ev.append({"type": "death", "target": target.uid})
		if target.charging:
			target.charging = null
	return ev


func heal(target: Combatant, amount: int) -> Array[Dictionary]:
	var before := target.hp
	target.hp = mini(target.max_hp, target.hp + amount)
	return [{"type": "heal", "target": target.uid, "amount": target.hp - before, "hp": target.hp}]


func apply_status(caster: Combatant, target: Combatant, fx: StatusEffectData) -> Dictionary:
	var mag := fx.magnitude
	if caster.team == 0:
		match fx.kind:
			K.DOT:
				mag += float(bonuses.get("dot_bonus", 0.0))
			K.SHIELD:
				mag = round(mag * (1.0 + float(bonuses.get("shield_bonus", 0.0)) + spell_power / 200.0))
			K.HOT:
				mag = round(mag * (1.0 + float(bonuses.get("heal_bonus", 0.0))))
			K.SUMMON:
				mag = round(mag * _scaling(caster))
	elif fx.kind == K.DOT or fx.kind == K.SUMMON:
		mag = round(mag * _scaling(caster))
	target.add_status(fx, mag)
	if fx.kind == K.STUN and target.charging:
		target.charging = null
		target.charge_left = 0
		return {"type": "interrupted", "target": target.uid, "status": fx.id, "name": fx.display_name}
	var e := {"type": "status_applied", "target": target.uid, "status": fx.id, "name": fx.display_name, "kind": fx.kind, "magnitude": mag}
	if fx.kind == K.SHIELD:
		e["shield_total"] = target.shield()
	return e


func _chaos_rift(caster: Combatant, target: Combatant, sp: SpellData) -> Array[Dictionary]:
	var ev: Array[Dictionary] = []
	var roll := rng.randf()
	if roll < 0.15:
		ev.append({"type": "text", "text": "The rift hiccups... and mends %s instead!" % target.display_name})
		ev.append_array(heal(target, 10))
	else:
		var base := rng.randi_range(4, 30)
		ev.append_array(deal_damage(caster, target, base, "chaos", 0.0, 0.0))
		if roll > 0.85 and caster.is_alive():
			ev.append({"type": "text", "text": "The rift spits sparkles back at you. They feel nice."})
			ev.append_array(heal(caster, 10))
		if target.is_alive() and rng.randf() < 0.5:
			var curse: StatusEffectData = status_lookup.call("glitter_curse")
			if curse:
				ev.append(apply_status(caster, target, curse))
	return ev


# ------------------------------------------------------------------ statuses
## Ticks DOT/HOT/SUMMON for `who` and decrements durations.
func tick_statuses(who: Combatant) -> Array[Dictionary]:
	var ev: Array[Dictionary] = []
	for s: Dictionary in who.statuses.duplicate():
		if not who.is_alive():
			break
		var d: StatusEffectData = s["data"]
		var mag := int(round(float(s["magnitude"])))
		match d.kind:
			K.DOT:
				var absorbed := who.absorb(mag)
				var dealt := mag - absorbed
				who.hp = maxi(0, who.hp - dealt)
				ev.append({"type": "status_tick", "target": who.uid, "status": d.id, "name": d.display_name, "amount": -dealt, "hp": who.hp, "color": d.color})
				if not who.is_alive():
					ev.append({"type": "death", "target": who.uid})
			K.HOT:
				var h := heal(who, mag)[0]
				ev.append({"type": "status_tick", "target": who.uid, "status": d.id, "name": d.display_name, "amount": int(h["amount"]), "hp": who.hp, "color": d.color})
			K.SUMMON:
				var foes: Array[Combatant] = living_enemies() if who.team == 0 else ([player] as Array[Combatant])
				if not foes.is_empty():
					var t: Combatant = foes[rng.randi() % foes.size()]
					ev.append({"type": "cast", "caster": who.uid, "targets": [t.uid], "spell": "", "style": "fungal_spore", "element": d.element, "name": d.display_name, "summon": true})
					ev.append_array(deal_damage(who, t, mag, d.element, 0.0, 0.1))
	for s: Dictionary in who.statuses.duplicate():
		s["remaining"] = int(s["remaining"]) - 1
		if int(s["remaining"]) <= 0:
			who.statuses.erase(s)
			var d2: StatusEffectData = s["data"]
			ev.append({"type": "status_expired", "target": who.uid, "status": d2.id, "name": d2.display_name})
	return ev


# ------------------------------------------------------------------ enemies
func enemy_turn(enemy: Combatant) -> Array[Dictionary]:
	var ev: Array[Dictionary] = []
	if not enemy.is_alive() or not player.is_alive():
		return ev
	for k: String in enemy.cooldowns.keys():
		enemy.cooldowns[k] = maxi(0, int(enemy.cooldowns[k]) - 1)
	# Boss phase changes.
	if enemy.data and not enemy.data.phase_thresholds.is_empty():
		var thresholds := enemy.data.phase_thresholds
		while enemy.phase < thresholds.size() and enemy.hp_ratio() <= thresholds[enemy.phase]:
			enemy.phase += 1
			ev.append({"type": "phase", "source": enemy.uid, "phase": enemy.phase, "text": "%s awakens fully! The ground itself answers its call." % enemy.display_name})
	if enemy.is_stunned():
		ev.append({"type": "stunned", "target": enemy.uid})
		return ev
	# Release a charged attack.
	if enemy.charging:
		enemy.charge_left -= 1
		if enemy.charge_left <= 0:
			var sp := enemy.charging
			enemy.charging = null
			ev.append({"type": "charge_release", "source": enemy.uid, "name": sp.display_name})
			ev.append_array(resolve(enemy, sp, 0))
			return ev
		ev.append({"type": "text", "text": "%s keeps gathering power..." % enemy.display_name})
		return ev
	var choice := EnemyAI.choose(self, enemy)
	var ability: SpellData = choice.get("ability")
	if ability == null:
		return ev
	if ability.cooldown > 0:
		enemy.cooldowns[ability.id] = ability.cooldown + 1
	if ability.charge_turns > 0:
		enemy.charging = ability
		enemy.charge_left = ability.charge_turns
		ev.append({"type": "charge_start", "source": enemy.uid, "name": ability.display_name, "text": "%s begins charging %s! Shield yourself — or root it in place!" % [enemy.display_name, ability.display_name]})
		return ev
	ev.append_array(resolve(enemy, ability, int(choice.get("target", 0))))
	return ev


# ------------------------------------------------------------------ rewards
func compute_rewards(player_level: int) -> Dictionary:
	var xp := 0
	var glimmer := 0
	var items: Dictionary = {}
	for e: Combatant in enemies:
		var cd := e.data
		if cd == null:
			continue
		# Diminishing XP for creatures far below the player's level.
		var gap := maxi(0, player_level - cd.level - 2)
		xp += int(round(cd.xp_reward * maxf(0.3, 1.0 - gap * 0.2)))
		glimmer += rng.randi_range(cd.glimmer_min, cd.glimmer_max)
		for l: Dictionary in cd.loot_table:
			if rng.randf() <= float(l.get("chance", 0.0)):
				var id := String(l.get("item_id", ""))
				items[id] = int(items.get(id, 0)) + rng.randi_range(int(l.get("min", 1)), int(l.get("max", 1)))
	if encounter:
		xp += encounter.bonus_xp
		glimmer += encounter.bonus_glimmer
		for id: String in encounter.bonus_items.keys():
			items[id] = int(items.get(id, 0)) + int(encounter.bonus_items[id])
	return {"xp": xp, "glimmer": glimmer, "items": items}
