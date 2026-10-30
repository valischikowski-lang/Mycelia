extends TestCase
## Treasure chests and Class Seals: sealed chests stay shut until the right
## calling's ability (or a Wanderkey) breaks the seal; loot is granted once.

var arena: Node3D
var player: PlayerController


func before_each() -> void:
	Game._bind(PlayerProfile.new(Database))
	Game.profile.new_game()
	arena = Node3D.new()
	host.add_child(arena)


func after_each() -> void:
	if is_instance_valid(arena):
		arena.queue_free()
	Game.profile = null


func _nook(tag: String) -> TreasureChest:
	var chest := TreasureChest.new()
	chest.chest_id = "test_chest_" + tag
	chest.loot = {"glimmer": 25, "mana_essence": 3, "items": {"ember_arrow": 5}}
	arena.add_child(chest)
	var seal := ClassSeal.new()
	seal.seal_id = "test_seal_" + tag
	seal.tag = tag
	arena.add_child(seal)
	chest.seal = seal
	return chest


func _player(cls: String) -> void:
	Game.profile.choose_class(cls)
	Game.profile.stats.level = 5
	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	arena.add_child(player)
	player.place_at(Vector3(0, 0, 3.0), 0.0)
	for i in 3:
		await tree.physics_frame


func test_matching_ability_opens_seal_and_chest_pays_once() -> void:
	var pairs := {"assassin": ["shadow", "shadow_dash"], "spirit": ["astral", "astral_shift"], "wizard": ["rune", "arcane_bolt"], "grimlet": ["root", "root_snare"]}
	for cls: String in pairs.keys():
		before_each()
		var tag: String = pairs[cls][0]
		var chest := _nook(tag)
		await _player(cls)
		check(not chest.can_interact(player), "%s: sealed chest can't be opened" % cls)
		var other: String = "rune" if tag != "rune" else "root"
		chest.seal.on_ability(other)
		check(not chest.seal.is_open(), "%s: a different calling's ability does nothing" % cls)
		Game.profile.stats.mana = 20.0
		player.combat.cast_ability(Database.ability(pairs[cls][1]))
		for i in 90:
			await tree.physics_frame
		check(chest.seal.is_open(), "%s: %s opens the %s seal" % [cls, pairs[cls][1], tag])
		var g := Game.profile.inventory.glimmer
		var me := Game.profile.mana_essence
		chest.interact(player)
		eq(Game.profile.inventory.glimmer, g + 25, "%s: chest gives glimmer" % cls)
		eq(Game.profile.mana_essence, me + 3, "%s: chest gives Mana Essence" % cls)
		check(Game.profile.world.is_consumed(chest.chest_id), "%s: chest remembered as opened" % cls)
		check(not chest.can_interact(player), "%s: chest can't be looted twice" % cls)
		player.queue_free()
		arena.queue_free()
		await tree.process_frame


func test_wanderkey_opens_any_seal() -> void:
	var chest := _nook("mycelium")
	await _player("assassin")
	Game.profile.inventory.add("wanderkey", 1)
	chest.seal.interact(player)
	check(chest.seal.is_open(), "Wanderkey opens a seal of another calling")
	eq(Game.profile.inventory.count("wanderkey"), 0, "Wanderkey is used up")


func test_opened_state_survives_save() -> void:
	var chest := _nook("echo")
	chest.seal.break_seal()
	await _player("spirit")
	chest.interact(player)
	var d := Game.profile.to_dict()
	var p2 := PlayerProfile.new(Database)
	p2.from_dict(d)
	check(p2.world.is_consumed("test_seal_echo"), "seal state saved")
	check(p2.world.is_consumed("test_chest_echo"), "chest state saved")
	eq(p2.mana_essence, Game.profile.mana_essence, "Mana Essence saved")
