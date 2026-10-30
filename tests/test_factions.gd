extends TestCase
## Factions: reputation tiers, disguises, prices, mentor goodwill and the
## guards' warn-warn-fight escalation for trespassers.

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


func after_each() -> void:
	if is_instance_valid(arena):
		arena.queue_free()
	Game.profile = null


func test_starting_reputation_and_tiers() -> void:
	var p := Game.profile
	p.choose_class("grimlet")
	eq(p.factions.standing("rootborn_hold", 0.0), "friendly", "own faction starts friendly")
	eq(p.factions.standing("unseen_covenant", 0.0), "wary", "other factions start wary")
	p.factions.change("unseen_covenant", -50)
	eq(p.factions.standing("unseen_covenant", 0.0), "hostile", "reputation can sink to hostile")
	check(p.factions.price_mult("rootborn_hold", 0.0) < 1.0, "kin get a discount")
	check(p.factions.price_mult("lantern_choir", 0.0) > 1.0, "strangers pay more")


func test_disguise_makes_you_neutral() -> void:
	var p := Game.profile
	p.choose_class("wizard")
	p.inventory.add("covenant_veil", 1)
	var msg := p.use_item("covenant_veil")
	check(msg != "", "veil can be used")
	eq(p.factions.standing("unseen_covenant", p.play_time), "neutral", "disguised as one of the Covenant")
	p.play_time += 9 * 60.0
	eq(p.factions.standing("unseen_covenant", p.play_time), "wary", "disguise wears off")


func test_goodwill_dialogue_condition_and_reward() -> void:
	var p := Game.profile
	p.choose_class("assassin")
	var r0 := p.factions.get_rep("rootborn_hold")
	p.inventory.add("sporeling_cap", 4)
	check(DialogueLogic.check("has_item:sporeling_cap:4", p), "goodwill condition met")
	for a: String in ["take_item:sporeling_cap:4", "rep:rootborn_hold:25", "give_essence:2"]:
		DialogueLogic.run(a, p)
	eq(p.factions.get_rep("rootborn_hold"), r0 + 25, "goodwill raises reputation")
	eq(p.factions.standing("rootborn_hold", 0.0), "neutral", "from wary to neutral")
	check(DialogueLogic.check("standing:rootborn_hold:neutral", p), "standing condition")
	check(not DialogueLogic.check("class:grimlet", p), "class condition")


func _guard(fid: String) -> FactionNPC:
	var g := FactionNPC.new()
	g.faction_id = fid
	g.role = "guard"
	g.npc_id = "test_guard"
	g.display_name = "Test Guard"
	g.visual_kind = "assassin"
	g.core_center = Vector3.ZERO
	g.core_radius = 10.0
	arena.add_child(g)
	g.global_position = Vector3(2, 0, 0)
	return g


func _spawn_player() -> void:
	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	arena.add_child(player)
	player.place_at(Vector3(0, 0.1, 3), 0.0)


func test_guards_warn_then_fight_outsiders() -> void:
	Game.profile.choose_class("wizard")
	var g := _guard("unseen_covenant")
	_spawn_player()
	var rep0 := Game.profile.factions.get_rep("unseen_covenant")
	for i in 60 * 5:
		await tree.process_frame
	check(g.visible, "guard only warns at first")
	eq(g._warned, 1, "first warning given")
	for i in 60 * 9:
		await tree.process_frame
	check(not g.visible, "after two warnings the guard attacks")
	check(is_instance_valid(g._fighter) and g._fighter.aware, "the guard fights in real time")
	check(Game.profile.factions.get_rep("unseen_covenant") < rep0, "trespassing costs reputation")


func test_guards_leave_kin_and_disguised_alone() -> void:
	Game.profile.choose_class("assassin")
	var g := _guard("unseen_covenant")
	_spawn_player()
	for i in 60 * 15:
		await tree.process_frame
	check(g.visible and g._warned == 0, "kin may walk freely")
	g.queue_free()
	player.queue_free()
	await tree.process_frame
	before_each()
	Game.profile.choose_class("spirit")
	Game.profile.inventory.add("covenant_veil", 1)
	Game.profile.use_item("covenant_veil")
	var g2 := _guard("unseen_covenant")
	_spawn_player()
	for i in 60 * 15:
		await tree.process_frame
	check(g2.visible and g2._warned == 0, "a disguise gets you past the guards")
