extends TestCase
## Loads the real Dreaming Meadow and rides every aimed bounce mushroom with
## the real player physics, checking that each hop lands where it should.

var region: Region
var player: PlayerController


func before_each() -> void:
	Game._bind(PlayerProfile.new(Database))
	Game.profile.new_game()
	region = (load("res://scenes/world/dreaming_meadow.tscn") as PackedScene).instantiate()
	host.add_child(region)


func after_each() -> void:
	if is_instance_valid(region):
		region.queue_free()
	Game.profile = null


func _ride(pad: BouncePad) -> Dictionary:
	# Drop the player onto the pad from just above it, without any input.
	player.place_at(pad.global_position + Vector3(0, 0.6, 0), 0.0)
	for i in 300:
		await tree.physics_frame
		if i > 20 and player.is_on_floor():
			break
	return {"pos": player.global_position, "floor": player.is_on_floor()}


func test_every_aimed_pad_lands_on_target() -> void:
	await region.build()
	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	region.add_child(player)
	var pads: Array[BouncePad] = []
	for n in region.find_children("*", "BouncePad", true, false):
		var bp := n as BouncePad
		if bp.has_target:
			pads.append(bp)
	check(pads.size() >= 4, "found aimed pads (%d)" % pads.size())
	for pad in pads:
		var r: Dictionary = await _ride(pad)
		var pos: Vector3 = r["pos"]
		print("    pad %s at %s -> target %s, landed %s" % [pad.get_parent().name, pad.global_position, pad.target_point, pos])
		var flat := Vector2(pos.x - pad.target_point.x, pos.z - pad.target_point.z).length()
		check(bool(r["floor"]), "%s: landed on something" % pad.get_parent().name)
		check(flat < 2.6, "%s: lands near target (off by %.2f m)" % [pad.get_parent().name, flat])
		check(absf(pos.y - pad.target_point.y) < 1.6, "%s: lands at target height (dy %.2f)" % [pad.get_parent().name, pos.y - pad.target_point.y])


func test_solver_math() -> void:
	var v := BouncePad.solve_launch(Vector3.ZERO, Vector3(6, 9, -7), 19.0, 2.5)
	# Integrate the same way the controller does (60 Hz, no air drag on input-free flight).
	var p := Vector3.ZERO
	var vel := v
	var best := INF
	for i in 400:
		vel.y -= 19.0 / 60.0
		p += vel / 60.0
		if vel.y < 0.0:
			best = minf(best, p.distance_to(Vector3(6, 9, -7)))
	check(best < 0.4, "trajectory passes through the target (closest %.2f m)" % best)
