extends TestCase


func test_xp_and_level_up() -> void:
	var p := new_profile()
	var need := p.stats.xp_to_next()
	check(need > 0, "level 1 requires xp")
	var hp1 := p.stats.max_health()
	eq(p.stats.add_xp(need - 1), 0, "just below threshold: no level")
	eq(p.stats.level, 1, "still level 1")
	eq(p.stats.add_xp(1), 1, "crossing the threshold levels up")
	eq(p.stats.level, 2, "now level 2")
	eq(p.stats.skill_points, 1, "skill point granted")
	check(p.stats.max_health() > hp1, "health grows with level")
	near(p.stats.health, float(p.stats.max_health()), 0.01, "level up refills health")


func test_multi_level() -> void:
	var p := new_profile()
	var gained := p.stats.add_xp(5000)
	check(gained >= 3, "large xp grants several levels (%d)" % gained)
	eq(p.stats.skill_points, gained, "one point per level")


func test_level_unlocks_spell() -> void:
	var p := new_profile()
	Game._bind(p)
	p.stats.add_xp(p.stats.xp_to_next())
	check(p.spellbook.knows("rootbind"), "reaching level 2 teaches Rootbind")
	Game.profile = null


func test_spell_learning_adds_to_deck() -> void:
	var p := new_profile()
	var before := p.spellbook.deck_size()
	check(p.learn_spell("sporeburst"), "learns new spell")
	check(not p.learn_spell("sporeburst"), "doesn't relearn")
	eq(p.spellbook.deck_size(), before + 2, "two copies added to deck")
	check(not p.learn_spell("no_such_spell"), "unknown spells rejected")


func test_deck_rules() -> void:
	var p := new_profile()
	p.learn_spell("sporeburst")
	check(p.spellbook.set_copies("sporeburst", 3), "3 copies allowed")
	check(not p.spellbook.set_copies("sporeburst", 4) or p.spellbook.copies("sporeburst") == 3, "max copies enforced")
	check(not p.spellbook.set_copies("thornlash", 0) or p.spellbook.deck_size() >= Spellbook.DECK_MIN, "deck minimum enforced")
	check(not p.spellbook.set_copies("starfall_seed", 1), "unknown spell can't enter deck")


func test_skill_tree() -> void:
	var p := new_profile()
	eq(p.unlock_skill("fungal", "spore_affinity"), "Not enough skill points", "needs a point")
	p.stats.skill_points = 3
	var sp_before := p.stats.get_stat("spell_power")
	eq(p.unlock_skill("fungal", "spore_affinity"), "", "unlocks tier 1")
	near(p.stats.get_stat("spell_power"), sp_before + 5.0, 0.01, "skill bonus applied")
	eq(p.unlock_skill("fungal", "virulent_spores"), "Requires level 2", "level gate")
	p.stats.level = 4
	eq(p.unlock_skill("fungal", "rot_bloom"), "Requires Virulent Spores", "prerequisite gate")
	eq(p.unlock_skill("fungal", "virulent_spores"), "", "tier 2 unlocks")
	eq(p.stats.skill_points, 1, "points spent")
	p.stats.skill_points = 2
	eq(p.unlock_skill("fungal", "rot_bloom"), "", "tier 3 unlocks")
	check(p.spellbook.knows("rot_bloom"), "skill unlocks its spell")
	near(float(p.stats.bonuses.get("dot_bonus", 0.0)), 2.0, 0.01, "dot bonus present")


func test_rewards_bundle() -> void:
	var p := new_profile()
	var g := p.inventory.glimmer
	var s := p.grant_rewards({"xp": 10, "glimmer": 7, "items": {"dream_mote": 2}, "spells": ["shardstorm"], "skill_points": 1})
	eq(p.inventory.glimmer, g + 7, "glimmer granted")
	eq(p.inventory.count("dream_mote"), 2, "items granted")
	check(p.spellbook.knows("shardstorm"), "spell granted")
	eq(p.stats.skill_points, 1, "skill point granted")
	eq(int(s["xp"]), 10, "summary reports xp")
