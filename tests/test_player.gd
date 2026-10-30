extends TestCase
## Physics integration tests for the first-person controller.

var world: Node3D
var player: PlayerController


func before_each() -> void:
	world = Node3D.new()
	host.add_child(world)
	var floor_body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, 1, 80)
	cs.shape = box
	cs.position = Vector3(0, -0.5, 0)
	floor_body.add_child(cs)
	world.add_child(floor_body)
	var wall := StaticBody3D.new()
	var wcs := CollisionShape3D.new()
	var wbox := BoxShape3D.new()
	wbox.size = Vector3(10, 4, 1)
	wcs.shape = wbox
	wcs.position = Vector3(0, 2, -8)
	wall.add_child(wcs)
	world.add_child(wall)
	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	world.add_child(player)
	player.place_at(Vector3(0, 0.05, 0), 0.0)
	TouchInput.reset()


func after_each() -> void:
	for a: String in ["move_forward", "jump", "sprint", "move_left"]:
		Input.action_release(a)
	TouchInput.reset()
	world.queue_free()


func _frames(n: int) -> void:
	for i in n:
		await tree.physics_frame


func test_lands_on_floor() -> void:
	player.place_at(Vector3(0, 3, 0), 0.0)
	await _frames(60)
	check(player.is_on_floor(), "gravity brings player to the floor")
	near(player.global_position.y, 0.0, 0.1, "rests on top of floor")


func test_walk_forward() -> void:
	await _frames(5)
	var z0 := player.global_position.z
	Input.action_press("move_forward")
	await _frames(30)
	Input.action_release("move_forward")
	check(player.global_position.z < z0 - 1.5, "moves forward (-Z) when pressing forward (dz=%.2f)" % (player.global_position.z - z0))


func test_sprint_faster_than_run() -> void:
	# Face away from the test wall so nothing blocks the run.
	player.place_at(Vector3(0, 0.05, 0), PI)
	await _frames(5)
	Input.action_press("move_forward")
	await _frames(40)
	var run_speed := Vector2(player.velocity.x, player.velocity.z).length()
	Input.action_press("sprint")
	await _frames(40)
	var sprint_speed := Vector2(player.velocity.x, player.velocity.z).length()
	Input.action_release("sprint")
	Input.action_release("move_forward")
	check(sprint_speed > run_speed + 2.0, "sprint (%.1f) faster than run (%.1f)" % [sprint_speed, run_speed])


func test_deceleration() -> void:
	Input.action_press("move_forward")
	await _frames(30)
	Input.action_release("move_forward")
	await _frames(30)
	near(Vector2(player.velocity.x, player.velocity.z).length(), 0.0, 0.05, "stops after releasing input")


func test_jump() -> void:
	await _frames(10)
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	await _frames(10)
	check(player.global_position.y > 0.5, "jump lifts the player (y=%.2f)" % player.global_position.y)
	await _frames(90)
	check(player.is_on_floor(), "lands again")


func test_wall_collision() -> void:
	Input.action_press("move_forward")
	await _frames(150)
	Input.action_release("move_forward")
	check(player.global_position.z > -7.6, "wall blocks movement (z=%.2f)" % player.global_position.z)


func test_camera_pitch_limits() -> void:
	player._apply_look(Vector2(0, -5000))
	near(rad_to_deg(player.head.rotation.x), player.pitch_max_deg, 0.5, "pitch clamped looking up")
	player._apply_look(Vector2(0, 10000))
	near(rad_to_deg(player.head.rotation.x), player.pitch_min_deg, 0.5, "pitch clamped looking down")


func test_touch_input_moves_player() -> void:
	await _frames(5)
	var x0 := player.global_position.x
	TouchInput.move = Vector2(1, 0)
	await _frames(30)
	TouchInput.move = Vector2.ZERO
	check(player.global_position.x > x0 + 1.0, "virtual joystick strafes right")
	TouchInput.look_delta = Vector2(30, 0)
	var yaw := player.rotation.y
	await _frames(2)
	check(not is_equal_approx(player.rotation.y, yaw), "touch look rotates camera")


func test_input_disabled() -> void:
	player.set_enabled(false)
	Input.action_press("move_forward")
	await _frames(20)
	Input.action_release("move_forward")
	near(Vector2(player.velocity.x, player.velocity.z).length(), 0.0, 0.01, "no movement while UI has control")
