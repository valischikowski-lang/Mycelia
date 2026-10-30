extends TestCase

const T := QuestObjectiveData.Type
const S := QuestData.State


func test_auto_start() -> void:
	var p := new_profile()
	eq(p.quests.get_state("first_awakening"), S.ACTIVE, "main quest auto-starts")
	eq(p.quests.get_state("wanderer_of_dreams"), S.ACTIVE, "discovery quest auto-starts")
	eq(p.quests.get_state("hum_beneath"), S.LOCKED, "follow-up locked")
	eq(p.quests.get_state("lights_of_glimmermere"), S.AVAILABLE, "side quest available")
	eq(p.quests.tracked, "first_awakening", "main quest tracked")


func test_sequential_progress() -> void:
	var p := new_profile()
	var q := p.quests
	q.handle_event(T.TALK, "mushroom_keeper")
	check(not q.is_objective_done("first_awakening", "talk_keeper"), "out-of-order objective ignored")
	q.handle_event(T.VISIT, "awakening_hollow")
	q.handle_event(T.VISIT, "keeper_grove")
	q.handle_event(T.TALK, "mushroom_keeper")
	eq(q.current_objective("first_awakening").id, "collect_fragments", "advanced to fragments")


func test_collect_counts_inventory() -> void:
	var p := new_profile()
	var q := p.quests
	p.inventory.add("spore_fragment", 2)
	q.handle_event(T.VISIT, "awakening_hollow")
	q.handle_event(T.VISIT, "keeper_grove")
	q.handle_event(T.TALK, "mushroom_keeper")
	eq(q.get_progress("first_awakening", "collect_fragments"), 2, "existing items counted when objective becomes current")
	p.inventory.add("spore_fragment", 1)
	q.handle_event(T.COLLECT, "spore_fragment")
	eq(q.current_objective("first_awakening").id, "return_keeper", "collect complete")


func test_full_chain_and_rewards() -> void:
	var p := new_profile()
	var q := p.quests
	var completed: Array[String] = []
	q.quest_completed.connect(func(id: String) -> void:
		completed.append(id)
		var data := Database.quest(id)
		p.grant_rewards({"xp": data.reward_xp, "glimmer": data.reward_glimmer, "items": data.reward_items, "spells": Array(data.reward_spells)}))
	for e: Array in [[T.VISIT, "awakening_hollow"], [T.VISIT, "keeper_grove"], [T.TALK, "mushroom_keeper"]]:
		q.handle_event(e[0], e[1])
	p.inventory.add("spore_fragment", 3)
	q.handle_event(T.COLLECT, "spore_fragment")
	for e: Array in [[T.TALK, "mushroom_keeper"], [T.ACTIVATE, "learn_fungal_magic"], [T.VISIT, "corrupted_sighting"], [T.DEFEAT, "enc_corrupted_sporeling"], [T.TALK, "mushroom_keeper"]]:
		q.handle_event(e[0], e[1])
	check("first_awakening" in completed, "first quest completes")
	eq(q.get_state("first_awakening"), S.COMPLETED, "state completed")
	eq(q.get_state("hum_beneath"), S.ACTIVE, "next main quest auto-starts")
	check(p.inventory.count("moss_woven_robe") == 1, "reward item granted")


func test_unsequenced_quest() -> void:
	var p := new_profile()
	var q := p.quests
	q.handle_event(T.DISCOVER, "drift_isle")
	q.handle_event(T.DISCOVER, "lantern_cap")
	check(q.is_objective_done("wanderer_of_dreams", "d_isle"), "any order for non-sequential quests")
	check(q.is_active("wanderer_of_dreams"), "still active until all done")


func test_serialization() -> void:
	var p := new_profile()
	p.quests.handle_event(T.VISIT, "awakening_hollow")
	var d: Dictionary = JSON.parse_string(JSON.stringify(p.quests.to_dict()))
	var p2 := new_profile()
	p2.quests.from_dict(d)
	check(p2.quests.is_objective_done("first_awakening", "wake_up"), "progress survives roundtrip")
	eq(p2.quests.tracked, "first_awakening", "tracked survives")


func test_dialogue_conditions() -> void:
	var p := new_profile()
	check(DialogueLogic.check("objective_current:first_awakening:wake_up", p), "objective_current")
	check(DialogueLogic.check("!flag:anything", p), "negation")
	check(DialogueLogic.check("quest_state:lights_of_glimmermere:AVAILABLE", p), "quest_state")
	check(not DialogueLogic.check("has_item:spore_fragment:1", p), "has_item false")
	p.inventory.add("spore_fragment", 1)
	check(DialogueLogic.check("has_item:spore_fragment:1", p), "has_item true")
	check(DialogueLogic.check("level:1", p), "level")
