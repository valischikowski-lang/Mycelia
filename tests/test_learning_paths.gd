extends TestCase
## Learning Paths: five per calling, bought with Mana Essence; upgrades,
## early abilities and world talents really change the game.

func test_every_class_has_five_paths_of_four() -> void:
	for cls: String in ["assassin", "spirit", "wizard", "grimlet"]:
		var t := Database.skill_tree("class_" + cls)
		eq((t.get("branches", []) as Array).size(), 5, "%s has five paths" % cls)
		eq((t.get("nodes", []) as Array).size(), 20, "%s has twenty steps" % cls)
		var c := Database.player_class(cls)
		for b: Dictionary in t["branches"]:
			check(String(b["id"]) in c.learning_paths, "%s path %s matches ClassData" % [cls, b["id"]])
		for n: Dictionary in t["nodes"]:
			for aid: String in (n.get("ability_mods", {}) as Dictionary).keys():
				check(Database.ability(aid) != null and Database.ability(aid).class_id == cls, "%s: %s upgrades a real own ability (%s)" % [cls, n["id"], aid])


func test_buying_with_mana_essence() -> void:
	var p := new_profile()
	p.choose_class("wizard")
	eq(p.unlock_path_node("focused_bolt"), "Not enough Mana Essence", "can't buy without essence")
	p.add_mana_essence(20)
	p.stats.level = 3
	eq(p.unlock_path_node("arcane_mind"), "Requires Focused Bolt", "paths are learned in order")
	eq(p.unlock_path_node("focused_bolt"), "", "first step learned")
	eq(p.mana_essence, 18, "cost paid")
	near(float(p.ability_mods("arcane_bolt").get("power", 0.0)), 0.25, 0.001, "ability upgrade registered")
	var sp0 := p.stats.get_stat("spell_power")
	eq(p.unlock_path_node("arcane_mind"), "", "second step learned")
	check(p.stats.get_stat("spell_power") >= sp0 + 10.0, "passive bonus applied")


func test_early_ability_and_perks() -> void:
	var p := new_profile()
	p.choose_class("grimlet")
	var ids := p.usable_abilities().map(func(a: AbilityData) -> String: return a.id)
	check(not "colossus_growth" in ids, "Colossus Growth locked at level 1")
	p.add_mana_essence(10)
	p.stats.level = 2
	p.unlock_path_node("elder_memory")
	eq(p.unlock_path_node("early_colossus"), "", "Early Growth learned")
	ids = p.usable_abilities().map(func(a: AbilityData) -> String: return a.id)
	check("colossus_growth" in ids, "path unlocks the ability before its level")
	var a := new_profile()
	a.choose_class("assassin")
	a.add_mana_essence(20)
	a.stats.level = 5
	for n: String in ["thick_smoke", "second_self", "quiet_steps"]:
		eq(a.unlock_path_node(n), "", "learned " + n)
	check(a.has_perk("quiet_steps"), "world talent active")
	var d := a.to_dict()
	var b := PlayerProfile.new(Database)
	b.from_dict(d)
	check(b.has_perk("quiet_steps"), "learned steps survive save/load")
	eq(b.mana_essence, a.mana_essence, "essence survives save/load")
