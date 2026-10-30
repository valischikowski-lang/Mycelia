extends TestCase


func _snapshot(deck: PackedStringArray) -> Dictionary:
	return {"name": "Tester", "level": 1, "health": 100, "max_health": 100, "mana": 6, "max_mana": 6,
		"defense": 4, "spell_power": 0, "magic_power": 10, "crit_chance": 0, "bonuses": {}, "deck": deck}


func _battle(enc_id: String, deck: PackedStringArray, seed_value: int = 1) -> BattleState:
	return BattleState.create(Database.encounter(enc_id), _snapshot(deck), seed_value,
		func(id: String) -> SpellData: return Database.spell(id),
		func(id: String) -> StatusEffectData: return Database.status_effect(id))


func test_deck_draw_and_reshuffle() -> void:
	var b := _battle("enc_sporeling", PackedStringArray(["thornlash", "thornlash", "sporeburst", "prism_ward", "mycelial_mend", "sporeburst"]))
	b.start_player_turn()
	eq(b.deck.hand.size(), 4, "draws four cards")
	eq(b.deck.total(), 6, "no cards lost")
	for i in 3:
		b.deck.play(0)
	b.deck.fill_hand()
	eq(b.deck.hand.size(), 4, "refills hand")
	b.deck.draw(10)
	eq(b.deck.total(), 6, "reshuffle keeps card count")
	check(b.deck.reshuffles >= 1, "discard reshuffled into draw pile")


func test_mana_validation() -> void:
	var b := _battle("enc_sporeling", PackedStringArray(["starfall_seed", "starfall_seed", "starfall_seed", "starfall_seed"]))
	b.start_player_turn()
	b.mana = 2
	eq(b.can_cast(0), "Not enough mana", "expensive card rejected")
	eq(b.cast(0, 1).size(), 0, "cast refused without mana")
	eq(b.deck.hand.size(), 4, "card stays in hand")
	b.mana = 6
	eq(b.can_cast(0), "", "castable with mana")
	b.cast(0, 1)
	eq(b.mana, 1, "mana deducted")


func test_damage_and_elements() -> void:
	near(ElementChart.multiplier("fungal", "nature"), 1.5, 0.001, "fungal beats nature")
	near(ElementChart.multiplier("nature", "fungal"), 0.75, 0.001, "nature weak to fungal")
	near(ElementChart.multiplier("crystal", "crystal"), 1.0, 0.001, "neutral")
	var b := _battle("enc_bloom_guardian", PackedStringArray(["sporeburst"]))
	var guardian := b.enemies[0]
	var ev := b.deal_damage(b.player, guardian, 10, "fungal", 0.0, 0.0)
	var dmg := int(ev[0]["amount"])
	# 10 * 1.5 (element) * (1 - 6/46 defense)
	eq(dmg, int(round(10 * 1.5 * (1.0 - 6.0 / 46.0))), "damage formula with element and defense")
	eq(guardian.hp, guardian.max_hp - dmg, "hp reduced")


func test_shield_absorbs() -> void:
	var b := _battle("enc_sporeling", PackedStringArray(["prism_ward"]))
	b.player.add_status(Database.status_effect("prism_shield"), 16)
	var e := b.enemies[0]
	var ev := b.deal_damage(e, b.player, 10, "fungal", 0.0, 0.0)
	eq(int(ev[0]["amount"]), 0, "shield absorbs everything")
	check(int(ev[0]["absorbed"]) > 0, "absorbed reported")
	eq(b.player.hp, 100, "no hp lost")


func test_healing_caps_at_max() -> void:
	var b := _battle("enc_sporeling", PackedStringArray(["mycelial_mend", "mycelial_mend", "mycelial_mend", "mycelial_mend"]))
	b.start_player_turn()
	b.player.hp = 90
	var ev := b.cast(0, 0)
	eq(b.player.hp, 100, "heal capped at max hp")
	var heal_ev := ev.filter(func(e: Dictionary) -> bool: return e["type"] == "heal")
	eq(int(heal_ev[0]["amount"]), 10, "reports actual healing")


func test_dot_ticks_and_expires() -> void:
	var b := _battle("enc_sporeling", PackedStringArray(["sporeburst"]))
	var e := b.enemies[0]
	b.apply_status(b.player, e, Database.status_effect("spore_rot"))
	var hp := e.hp
	b.tick_statuses(e)
	eq(e.hp, hp - 3, "spore rot deals 3")
	b.tick_statuses(e)
	b.tick_statuses(e)
	check(not e.has_status("spore_rot"), "expires after its duration")


func test_stun_interrupts_charge() -> void:
	var b := _battle("enc_spore_golem", PackedStringArray(["rootbind"]))
	var golem := b.enemies[0]
	golem.charging = Database.spell("thornlash")
	golem.charge_left = 1
	var ev := b.apply_status(b.player, golem, Database.status_effect("rooted"))
	eq(String(ev["type"]), "interrupted", "rooting a charging enemy interrupts it")
	check(golem.charging == null, "charge cleared")
	var turn := b.enemy_turn(golem)
	eq(String(turn[-1]["type"]), "stunned", "stunned enemy skips its action")


func test_enemy_ai_heals_when_hurt() -> void:
	var b := _battle("enc_dream_fox", PackedStringArray(["thornlash"]), 3)
	var fox := b.enemies[0]
	fox.hp = int(fox.max_hp * 0.2)
	var choice := EnemyAI.choose(b, fox)
	eq((choice["ability"] as SpellData).id, "moonlight_lick", "tactical fox heals at low health")
	fox.hp = fox.max_hp
	choice = EnemyAI.choose(b, fox)
	check((choice["ability"] as SpellData).id != "moonlight_lick", "doesn't heal at full health")


func test_boss_phase_and_charge() -> void:
	var b := _battle("enc_spore_golem", PackedStringArray(["thornlash"]), 7)
	var golem := b.enemies[0]
	golem.hp = int(golem.max_hp * 0.4)
	var ev := b.enemy_turn(golem)
	eq(golem.phase, 1, "boss enters phase 2 below 50%")
	check(ev.any(func(e: Dictionary) -> bool: return e["type"] == "phase"), "phase event emitted")


func test_victory_defeat_and_rewards() -> void:
	var b := _battle("enc_sporelings", PackedStringArray(["thornlash"]))
	eq(b.outcome(), "", "ongoing")
	for e: Combatant in b.enemies:
		e.hp = 0
	eq(b.outcome(), "victory", "all enemies down")
	var r := b.compute_rewards(1)
	check(int(r["xp"]) >= 40, "xp from two sporelings")
	check(int(r["glimmer"]) >= 4, "glimmer rolled")
	var b2 := _battle("enc_sporeling", PackedStringArray(["thornlash"]))
	b2.player.hp = 0
	eq(b2.outcome(), "defeat", "player down")


func test_determinism() -> void:
	var deck := PackedStringArray(["thornlash", "sporeburst", "sporeburst", "prism_ward", "mycelial_mend", "thornlash"])
	var logs: Array = []
	for run in 2:
		var b := _battle("enc_crystal_beetle", deck, 99)
		var log: Array = []
		for turn in 4:
			b.start_player_turn()
			log.append(b.deck.hand.duplicate())
			var idx := 0
			while idx < b.deck.hand.size() and b.can_cast(idx) != "":
				idx += 1
			if idx < b.deck.hand.size():
				log.append(JSON.stringify(b.cast(idx, 1)))
			log.append(JSON.stringify(b.enemy_turn(b.enemies[0])))
		logs.append(log)
	eq(JSON.stringify(logs[0]), JSON.stringify(logs[1]), "same seed => identical battle")


func test_meditate_and_flee() -> void:
	var b := _battle("enc_sporeling", PackedStringArray(["thornlash"]))
	b.mana = 1
	b.meditate()
	eq(b.mana, 4, "meditate restores 3 mana")
	var b2 := _battle("enc_corrupted_sporeling", PackedStringArray(["thornlash"]))
	var ev := b2.try_flee()
	eq(String(ev[0]["type"]), "text", "can't flee story battles")
