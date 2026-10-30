extends TestCase


func test_add_and_stack() -> void:
	var p := new_profile()
	var inv := p.inventory
	eq(inv.add("dewdrop_tonic", 5), 5, "adds 5 tonics")
	eq(inv.count("dewdrop_tonic"), 5, "count after add")
	eq(inv.slots.size(), 1, "stacked in one slot")
	eq(inv.add("dewdrop_tonic", 20), 20, "adds 20 more")
	eq(inv.slots.size(), 2, "stack limit 20 spills into a second slot")
	eq(inv.count("dewdrop_tonic"), 25, "total 25")


func test_remove() -> void:
	var inv := new_profile().inventory
	inv.add("sporeling_cap", 3)
	eq(inv.remove("sporeling_cap", 2), 2, "removes 2")
	eq(inv.count("sporeling_cap"), 1, "one left")
	eq(inv.remove("sporeling_cap", 5), 1, "removes only what exists")
	eq(inv.slots.size(), 0, "slot cleared when empty")
	eq(inv.remove("nothing", 1), 0, "removing unknown is a no-op")


func test_capacity() -> void:
	var inv := new_profile().inventory
	inv.capacity = 2
	inv.add("keeper_staff", 1)
	inv.add("lumen_ring", 1)
	eq(inv.add("dreamers_cap", 1), 0, "full satchel rejects new stacks")
	check(inv.is_full(), "reports full")


func test_equipment_and_bonuses() -> void:
	var p := new_profile()
	var base_sp := p.stats.get_stat("spell_power")
	p.inventory.add("keeper_staff", 1)
	check(p.inventory.equip("keeper_staff"), "equips staff")
	eq(p.inventory.equipment.get("staff", ""), "keeper_staff", "staff slot filled")
	eq(p.inventory.count("keeper_staff"), 0, "staff removed from bag")
	near(p.stats.get_stat("spell_power"), base_sp + 8.0, 0.01, "equipment bonus applied")
	p.inventory.add("apprentice_wand", 1)
	check(p.inventory.equip("apprentice_wand"), "swaps staff")
	eq(p.inventory.count("keeper_staff"), 1, "previous staff returned to bag")
	check(p.inventory.unequip("staff"), "unequips")
	near(p.stats.get_stat("spell_power"), base_sp, 0.01, "bonus removed")
	check(not p.inventory.equip("dewdrop_tonic"), "consumables can't be equipped")


func test_currency() -> void:
	var inv := new_profile().inventory
	var start := inv.glimmer
	inv.add_glimmer(10)
	eq(inv.glimmer, start + 10, "glimmer added")
	check(not inv.spend_glimmer(9999), "cannot overspend")
	check(inv.spend_glimmer(5), "spend ok")
	eq(inv.glimmer, start + 5, "glimmer spent")


func test_use_consumable() -> void:
	var p := new_profile()
	p.stats.health = 10
	p.inventory.add("dewdrop_tonic", 1)
	var msg := p.use_item("dewdrop_tonic")
	check(msg != "", "use returns a message")
	near(p.stats.health, 50.0, 0.01, "tonic heals 40")
	eq(p.inventory.count("dewdrop_tonic"), 0, "tonic consumed")
	p.inventory.add("scroll_wild_bloom", 1)
	p.use_item("scroll_wild_bloom")
	check(p.spellbook.knows("wild_bloom"), "scroll teaches spell")


func test_serialization() -> void:
	var p := new_profile()
	p.inventory.add("dream_mote", 3)
	p.inventory.add("lumen_ring", 1)
	p.inventory.equip("lumen_ring")
	var d := p.inventory.to_dict()
	var p2 := new_profile()
	p2.inventory.from_dict(JSON.parse_string(JSON.stringify(d)))
	eq(p2.inventory.count("dream_mote"), 3, "count survives JSON roundtrip")
	eq(p2.inventory.equipment.get("ring", ""), "lumen_ring", "equipment survives")
	p2.inventory.from_dict({"slots": [{"id": "not_a_real_item", "count": 4}, {"bad": true}]})
	eq(p2.inventory.slots.size(), 0, "invalid entries are dropped")
