extends TestCase


func test_profile_roundtrip() -> void:
	var p := new_profile()
	p.stats.add_xp(200)
	p.inventory.add("dream_mote", 4)
	p.inventory.add("keeper_staff", 1)
	p.inventory.equip("keeper_staff")
	p.learn_spell("shardstorm")
	p.spellbook.set_copies("shardstorm", 3)
	p.world.set_flag("rift_seen")
	p.world.discover("lantern_cap")
	p.world.consume("fragment_shrine")
	p.world.add_lore("waking_stone", "The Waking Stone", "text")
	p.quests.handle_event(QuestObjectiveData.Type.VISIT, "awakening_hollow")
	var json := JSON.stringify(p.to_dict())
	var p2 := PlayerProfile.new(Database)
	p2.from_dict(JSON.parse_string(json))
	eq(p2.stats.level, p.stats.level, "level")
	eq(p2.stats.xp, p.stats.xp, "xp")
	eq(p2.inventory.count("dream_mote"), 4, "items")
	eq(p2.inventory.equipment.get("staff", ""), "keeper_staff", "equipment")
	near(p2.stats.get_stat("spell_power"), p.stats.get_stat("spell_power"), 0.01, "derived stats rebuilt")
	eq(p2.spellbook.copies("shardstorm"), 3, "deck")
	check(p2.world.has_flag("rift_seen"), "flags")
	check(p2.world.is_discovered("lantern_cap"), "discoveries")
	check(p2.world.is_consumed("fragment_shrine"), "consumed world objects")
	eq(String((p2.world.lore_entries["waking_stone"] as Dictionary)["title"]), "The Waking Stone", "lore entries")
	check(p2.quests.is_objective_done("first_awakening", "wake_up"), "quest progress")


func test_slot_write_read_delete() -> void:
	var p := new_profile()
	p.inventory.add("dream_mote", 2)
	var data := SaveSchema.defaults()
	data["saved_at"] = 12345
	data["position"] = [1.0, 2.0, 3.0]
	data["profile"] = p.to_dict()
	check(SaveManager.write_slot("slot3", data), "writes slot")
	var back := SaveManager.read_slot("slot3")
	eq(int(back["saved_at"]), 12345, "timestamp")
	eq(int(back["version"]), SaveSchema.CURRENT_VERSION, "version stamped")
	var info := SaveManager.slot_info("slot3")
	eq(int(info["level"]), 1, "slot info level")
	# Second write keeps a backup; corrupt the main file and expect fallback.
	SaveManager.write_slot("slot3", data)
	var f := FileAccess.open(SaveManager.slot_path("slot3"), FileAccess.WRITE)
	f.store_string("{ this is not json")
	f.close()
	var recovered := SaveManager.read_slot("slot3")
	check(not recovered.is_empty(), "falls back to .bak when main file is corrupt")
	SaveManager.delete_slot("slot3")
	check(SaveManager.slot_info("slot3").is_empty(), "slot deleted")


func test_migration_from_v1() -> void:
	var v1 := {"version": 1, "region": "dreaming_meadow", "profile": {"currency": 42, "inventory": {"slots": [{"id": "dream_mote", "count": 2}]}, "stats": {"level": 3}}}
	var d := SaveSchema.upgrade(v1)
	eq(int(d["version"]), SaveSchema.CURRENT_VERSION, "upgraded to current")
	eq(int(d["profile"]["inventory"]["glimmer"]), 42, "currency moved into inventory")
	check(d["profile"].has("world"), "world block added")
	eq(float(d["yaw"]), 0.0, "yaw default added")
	var p := PlayerProfile.new(Database)
	p.from_dict(d["profile"])
	eq(p.stats.level, 3, "migrated profile loads")
	eq(p.inventory.glimmer, 42, "migrated glimmer")


func test_validation_and_defaults() -> void:
	check(SaveSchema.upgrade("garbage").is_empty(), "non-dict rejected")
	check(SaveSchema.upgrade({"profile": "nope"}).is_empty(), "bad profile rejected")
	var d := SaveSchema.upgrade({"version": 3, "profile": {}, "position": ["x", 1, 2]})
	check(d["position"] == null, "invalid position dropped")
	var p := PlayerProfile.new(Database)
	p.from_dict(d["profile"])
	check(not p.spellbook.known.is_empty(), "missing spellbook gets starter spells")
	eq(p.stats.level, 1, "missing stats default to level 1")
