extends TestCase
## Plays the opening of the main story through the real dialogue runner,
## quest log and event bus — the same path the game uses.

var _lines: Array = []


func before_each() -> void:
	Game._bind(PlayerProfile.new(Database))
	Game.profile.new_game()


func after_each() -> void:
	Game.profile = null


func _choose_first(r: DialogueRunner) -> void:
	r.choose(0)


func test_first_quest_through_dialogue() -> void:
	var p := Game.profile
	EventBus.location_visited.emit("awakening_hollow")
	EventBus.location_visited.emit("keeper_grove")
	var r := DialogueRunner.new()
	r.line.connect(func(sp: String, t: String, opts: Array) -> void: _lines.append([sp, t, opts]))
	EventBus.npc_talked.emit("mushroom_keeper")
	check(r.start("keeper_main", p), "dialogue starts")
	check(String(_lines[-1][1]).contains("Umbel"), "intro introduces Umbel")
	eq(p.quests.current_objective("first_awakening").id, "collect_fragments", "talking advanced the quest")
	r.close()
	# Collect fragments the way the world does it.
	for i in 3:
		p.inventory.add("spore_fragment", 1)
		EventBus.item_collected.emit("spore_fragment", 1)
	EventBus.npc_talked.emit("mushroom_keeper")
	_lines.clear()
	r.start("keeper_main", p)
	check(String(_lines[-1][1]).contains("All three"), "keeper reacts to fragments")
	_choose_first(r)
	check(p.spellbook.knows("sporeburst"), "learned Sporeburst")
	check(p.spellbook.knows("mycelial_mend"), "learned Mycelial Mend")
	eq(p.inventory.count("spore_fragment"), 0, "fragments handed over")
	eq(p.quests.current_objective("first_awakening").id, "spot_creature", "next: investigate")
	_choose_first(r)
	_choose_first(r)
	check(not r.active, "conversation ends")


func test_side_quest_offer() -> void:
	var p := Game.profile
	var r := DialogueRunner.new()
	r.start("petalune", p)
	r.choose(0)
	r.choose(0)
	eq(p.quests.get_state("lights_of_glimmermere"), QuestData.State.ACTIVE, "Petalune's quest accepted via dialogue")


func test_all_dialogue_links_resolve() -> void:
	for id: String in ["keeper_main", "petalune", "ollo"]:
		var d := Database.dialogue(id)
		check(not d.is_empty(), "%s exists" % id)
		var nodes: Dictionary = d.get("nodes", {})
		for e: Variant in d.get("entry", []):
			var g := String((e as Dictionary).get("goto", "end"))
			check(g == "end" or nodes.has(g), "%s entry -> %s" % [id, g])
		for nid: String in nodes.keys():
			var node: Dictionary = nodes[nid]
			if node.has("next"):
				check(nodes.has(String(node["next"])), "%s.%s next" % [id, nid])
			for o: Variant in node.get("options", []):
				var g2 := String((o as Dictionary).get("goto", "end"))
				check(g2 == "end" or nodes.has(g2), "%s.%s option -> %s" % [id, nid, g2])
