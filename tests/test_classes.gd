extends TestCase
## The four callings: data completeness, choosing a class, starting kit,
## stat modifiers and save compatibility.

const IDS := ["assassin", "spirit", "wizard", "grimlet"]


func test_class_data_complete() -> void:
	for id: String in IDS:
		var c := Database.player_class(id)
		check(c != null, "%s exists" % id)
		if c == null:
			continue
		eq(c.abilities.size(), 5, "%s has five abilities" % id)
		eq(c.start_items.size(), 5, "%s has five signature items" % id)
		eq(c.learning_paths.size(), 5, "%s has five learning paths" % id)
		for a: String in c.abilities:
			var ad := Database.ability(a)
			check(ad != null and ad.kind != "" and ad.class_id == id, "%s ability %s valid" % [id, a])
		for i: String in c.start_items:
			var d := Database.item(i)
			check(d != null and d.equip_slot != "" and d.class_id == id, "%s item %s valid" % [id, i])


func test_choose_class_equips_kit() -> void:
	for id: String in IDS:
		var p := new_profile()
		var hp_before := p.stats.max_health()
		check(p.choose_class(id), "%s chosen" % id)
		check(not p.choose_class("wizard"), "%s: class can't be re-chosen" % id)
		eq(p.class_id, id, "class stored")
		check(p.inventory.equipment.has("staff"), "%s: weapon equipped" % id)
		check(p.inventory.equipment.has("robe"), "%s: armour equipped" % id)
		check(p.inventory.equipment.has("ranged"), "%s: a bow is equipped" % id)
		var w := Database.item(String(p.inventory.equipment["staff"]))
		check(w.is_weapon(), "%s: main weapon is a weapon (%s)" % [id, w.weapon_kind])
		eq(p.hotbar.size(), 5, "%s: hotbar filled" % id)
		check(p.usable_abilities().size() >= 4, "%s: abilities usable at level 1" % id)
		if id == "grimlet":
			check(p.stats.max_health() > hp_before + 30, "grimlet is sturdier")
			check(p.inventory.has("mycelium_hammer"), "grimlet keeps the hammer in the bag for switching")
		if id == "wizard":
			check(p.stats.max_mana() > 6, "wizard has more mana")


func test_save_roundtrip_and_old_saves() -> void:
	var p := new_profile()
	p.choose_class("spirit")
	var d := p.to_dict()
	var q := PlayerProfile.new(Database)
	q.from_dict(d)
	eq(q.class_id, "spirit", "class survives save/load")
	eq(q.hotbar.size(), 5, "hotbar survives save/load")
	eq(q.inventory.equipment.get("offhand", ""), "ethereal_shield", "new slots survive save/load")
	# A save from before the callings existed.
	d.erase("class_id")
	d.erase("hotbar")
	var old := PlayerProfile.new(Database)
	old.from_dict(d)
	eq(old.class_id, "", "old saves load without a class (Threshold will ask)")
	check(old.choose_class("grimlet"), "old save can then choose a class")
