extends TestCase
## Real-time combat: melee, heavy, block/parry, dodge, bow, all 20 class
## abilities, enemy attacks, boss phases and encounter completion — with
## the real PlayerController on a flat test floor.

var arena: Node3D
var player: PlayerController


func before_each() -> void:
	Game._bind(PlayerProfile.new(Database))
	Game.profile.new_game()
	Game.session_active = true
	arena = Node3D.new()
	host.add_child(arena)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
	cs.shape = box
	cs.position.y = -0.5
	body.add_child(cs)
	arena.add_child(body)
	TouchInput.reset()


func after_each() -> void:
	TouchInput.reset()
	if is_instance_valid(arena):
		arena.queue_free()
	Game.in_combat = false
	Game.profile = null


func _setup(cls: String) -> void:
	Game.profile.choose_class(cls)
	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	arena.add_child(player)
	player.place_at(Vector3(0, 0.1, 0), 0.0)
	await _frames(3)


func _enemy(id: String, pos: Vector3, encounter: String = "") -> WorldCreature:
	var c := WorldCreature.new()
	c.creature_id = id
	c.encounter_id = encounter
	arena.add_child(c)
	c.global_position = pos
	c.home = pos
	await _frames(2)
	return c


func _frames(n: int) -> void:
	for i in n:
		await tree.physics_frame


func _seconds(s: float) -> void:
	await _frames(int(s * 60.0))


func test_light_combo_and_heavy_attack() -> void:
	await _setup("grimlet")
	var e := await _enemy("crystal_beetle", Vector3(0, 0, -1.8))
	e.aware = true
	var hp0 := e.hp
	player.combat.light_attack()
	await _frames(2)
	check(e.hp < hp0, "light attack damages the enemy in front (%.0f -> %.0f)" % [hp0, e.hp])
	var hp1 := e.hp
	await _seconds(1.0)
	player.combat.heavy_attack()
	await _frames(2)
	check(hp1 - e.hp > (hp0 - hp1) * 1.3, "heavy attack hits harder than a light one")
	check(player.combat.stamina < player.combat.max_stamina, "attacks cost stamina")
	check(player.combat.combat_mode, "attacking enters combat mode")


func test_backstab_and_weak_spot() -> void:
	await _setup("assassin")
	var e := await _enemy("crystal_beetle", Vector3(0, 0, -1.6))
	e.aware = true
	# Beetle faces the player (+Z towards player) => front hit is guarded.
	e.rig.basis = Basis.looking_at(Vector3(0, 0, -1), Vector3.UP)
	var hp0 := e.hp
	player.combat.light_attack()
	await _frames(2)
	var front := hp0 - e.hp
	await _seconds(0.6)
	e.rig.basis = Basis.looking_at(Vector3(0, 0, 1), Vector3.UP)
	var hp1 := e.hp
	player.combat.light_attack()
	await _frames(2)
	var back := hp1 - e.hp
	check(back > front * 2.0, "hits from behind on a beetle are far stronger (front %.1f, back %.1f)" % [front, back])


func test_enemy_attacks_block_parry_dodge() -> void:
	await _setup("spirit")
	var e := await _enemy("sporeling", Vector3(0, 0, -1.4))
	var st := Game.profile.stats
	var hit := {"amount": 20.0, "kind": "melee", "source": e, "from": e.global_position}
	var h0 := st.health
	player.take_hit(hit.duplicate())
	var plain := h0 - st.health
	check(plain > 5.0, "unblocked hit hurts (%.1f)" % plain)
	# Block (held long enough to miss the parry window).
	TouchInput.block_held = true
	await _seconds(0.5)
	var h1 := st.health
	player.take_hit(hit.duplicate())
	var blocked := h1 - st.health
	check(blocked < plain * 0.6, "shield block reduces damage (%.1f vs %.1f)" % [blocked, plain])
	TouchInput.block_held = false
	# Perfect parry.
	await _frames(2)
	player.combat.set_blocking(true)
	e.state = WorldCreature.State.WINDUP
	var h2 := st.health
	player.take_hit(hit.duplicate())
	near(st.health, h2, 0.01, "perfect parry negates the hit")
	check(e.state == WorldCreature.State.STAGGER or e.hp < e.max_hp, "parry punishes the attacker")
	player.combat.set_blocking(false)
	# Dodge i-frames.
	await _seconds(0.6)
	player.combat.dodge(Vector3.RIGHT)
	var h3 := st.health
	player.take_hit(hit.duplicate())
	near(st.health, h3, 0.01, "dodging makes you untouchable for a moment")
	await _seconds(0.4)
	check(player.global_position.x > 2.0, "dodge moves the player (x=%.1f)" % player.global_position.x)


func test_enemy_ai_attacks_player() -> void:
	await _setup("wizard")
	var e := await _enemy("sporeling", Vector3(0, 0, -6))
	e.hostile_override = true
	var h0 := Game.profile.stats.health
	await _seconds(6.0)
	check(e.aware, "sporeling noticed the player")
	check(Game.profile.stats.health < h0, "sporeling's telegraphed attacks connect")


func test_bow_draw_and_arrow() -> void:
	await _setup("assassin")
	var e := await _enemy("sporeling", Vector3(0, 0, -14))
	player.combat.lock_target = e
	var hp0 := e.hp
	player.combat.draw = 1.0
	player.combat._release_arrow()
	await _seconds(1.0)
	check(e.hp < hp0, "a fully drawn arrow hits (%.0f -> %.0f)" % [hp0, e.hp])
	check(not e.aware, "Nightpiercer arrows are silent")


func test_every_class_ability_works() -> void:
	for cls: String in ["assassin", "spirit", "wizard", "grimlet"]:
		before_each_inner()
		await _setup(cls)
		Game.profile.stats.level = 5
		Game.profile.stats.bonuses["max_mana"] = 50.0
		Game.profile.stats.mana = 50.0
		var c := Database.player_class(cls)
		for aid: String in c.abilities:
			var a := Database.ability(aid)
			var e := await _enemy("crystal_beetle", Vector3(0, 0, -2.5))
			player.place_at(Vector3(0, 0.1, 0), 0.0)
			player.combat.lock_target = e
			await _frames(2)
			var mana0 := Game.profile.stats.mana
			var hp0 := e.hp
			var ok := player.combat.cast_ability(a)
			check(ok, "%s: %s casts" % [cls, aid])
			var echo := player.combat.has_special("astral_echo") and player.combat._casts % 4 == 0
			check(Game.profile.stats.mana < mana0 or echo, "%s: %s costs mana (or is a free Astral Echo)" % [cls, aid])
			check(float(player.combat.cooldowns.get(aid, 0.0)) > 0.0, "%s: %s goes on cooldown" % [cls, aid])
			check(not player.combat.cast_ability(a), "%s: %s can't be spammed" % [cls, aid])
			await _seconds(1.5)
			var effect := e.hp < hp0 or not e.statuses.is_empty() or player.combat.buffs.size() > 0 or player.combat.shield_hp > 0.0 \
				or tree.get_nodes_in_group("rt_decoy").size() > 0 or player.scale.x > 1.01
			check(effect, "%s: %s has a real effect" % [cls, aid])
			if is_instance_valid(e):
				e.queue_free()
			for n in tree.get_nodes_in_group("rt_decoy"):
				n.queue_free()
			player.combat.buffs.clear()
			player.combat.shield_hp = 0.0
			player.scale = Vector3.ONE
			await _frames(2)
		player.queue_free()
		await _frames(2)


func before_each_inner() -> void:
	Game._bind(PlayerProfile.new(Database))
	Game.profile.new_game()


func test_boss_phases_and_encounter_won() -> void:
	await _setup("grimlet")
	var won: Array = []
	var cb := func(id: String) -> void: won.append(id)
	EventBus.encounter_won.connect(cb)
	var boss := await _enemy("spore_golem", Vector3(0, 0, -6), "enc_spore_golem")
	boss.hostile_override = true
	boss.notice()
	check(boss.is_boss(), "golem is a boss")
	boss.take_hit({"amount": boss.max_hp * 0.55, "kind": "magic", "from": player.global_position})
	eq(boss.phase, 1, "golem enters phase 2 below half health")
	boss.take_hit({"amount": boss.max_hp, "kind": "magic", "from": player.global_position})
	check(boss.dead, "golem can be defeated")
	await _frames(3)
	check("enc_spore_golem" in won, "defeating the boss wins its encounter")
	check(Game.profile.world.won_encounters.has("enc_spore_golem"), "unique boss is remembered")
	EventBus.encounter_won.disconnect(cb)


func test_pack_encounter_needs_all_members() -> void:
	await _setup("wizard")
	var won: Array = []
	var cb := func(id: String) -> void: won.append(id)
	EventBus.encounter_won.connect(cb)
	var leader := await _enemy("hollow_crone", Vector3(0, 0, -8), "enc_coven")
	leader.hostile_override = true
	leader.notice()
	await _frames(2)
	eq(leader.pack.size(), 1, "the coven's second crone joins")
	leader.take_hit({"amount": 999.0, "kind": "magic", "from": player.global_position})
	await _frames(2)
	check(won.is_empty(), "encounter not won while a crone still stands")
	leader.pack[0].take_hit({"amount": 999.0, "kind": "magic", "from": player.global_position})
	await _frames(2)
	check("enc_coven" in won, "encounter won when the whole pack is down")
	EventBus.encounter_won.disconnect(cb)


func test_player_death_respawns_without_loss() -> void:
	await _setup("spirit")
	var glim := Game.profile.inventory.glimmer
	Game.profile.stats.health = 1.0
	player.take_hit({"amount": 50.0, "kind": "melee", "from": Vector3(0, 0, -1)})
	check(player.combat.dead, "player falls at 0 health")
	await _seconds(2.5)
	check(not player.combat.dead, "player wakes again")
	check(Game.profile.stats.health > 0.0, "health restored")
	eq(Game.profile.inventory.glimmer, glim, "no glimmer lost")
