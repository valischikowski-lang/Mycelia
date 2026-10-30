class_name PlayerController
extends CharacterBody3D
## First-person explorer. Reads keyboard/mouse/gamepad through the InputMap
## and touch through TouchInput; both feed the same movement model.

signal target_changed(target: Interactable)
signal landed(fall_speed: float)

@export_group("Movement")
@export var walk_speed: float = 3.2
@export var run_speed: float = 6.2
@export var sprint_speed: float = 9.6
@export var acceleration: float = 34.0
@export var air_acceleration: float = 9.0
@export var deceleration: float = 42.0
@export var jump_velocity: float = 6.6
@export var gravity: float = 19.0
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.15
@export var max_fall_speed: float = 40.0
@export_group("Camera")
@export var eye_height: float = 1.62
@export var pitch_min_deg: float = -86.0
@export var pitch_max_deg: float = 86.0
@export var look_smoothing: float = 0.0
@export_group("Interaction")
@export var interact_range: float = 3.8
@export var proximity_range: float = 2.6
@export_group("World")
## Soft circular boundary (xz) keeping the player inside the region.
@export var world_radius: float = 128.0

var head: Node3D
var camera: Camera3D
var ray: RayCast3D
var input_enabled: bool = true
var look_enabled: bool = true
var current_target: Interactable

var _pitch: float = 0.0
var _coyote: float = 0.0
var _jump_buffer: float = 0.0
var _bob_t: float = 0.0
var _last_step_phase: float = 0.0
var _was_on_floor: bool = true
var _fall_speed: float = 0.0
var _launch_lock: float = 0.0
var _probe_timer: float = 0.0


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	floor_max_angle = deg_to_rad(48.0)
	floor_snap_length = 0.4
	if get_node_or_null("Collision") == null:
		var cs := CollisionShape3D.new()
		cs.name = "Collision"
		var cap := CapsuleShape3D.new()
		cap.radius = 0.38
		cap.height = 1.76
		cs.shape = cap
		cs.position.y = 0.88
		add_child(cs)
	head = get_node_or_null("Head") as Node3D
	if head == null:
		head = Node3D.new()
		head.name = "Head"
		add_child(head)
	head.position.y = eye_height
	camera = head.get_node_or_null("Camera3D") as Camera3D
	if camera == null:
		camera = Camera3D.new()
		camera.name = "Camera3D"
		head.add_child(camera)
	camera.near = 0.08
	camera.far = 900.0
	camera.fov = Settings.fov
	camera.current = true
	ray = RayCast3D.new()
	ray.target_position = Vector3(0, 0, -interact_range)
	ray.collision_mask = 4
	ray.collide_with_areas = true
	ray.collide_with_bodies = false
	camera.add_child(ray)
	Settings.changed.connect(_on_settings_changed)


func _on_settings_changed(section: String) -> void:
	if section == "graphics" or section == "controls":
		camera.fov = Settings.fov


func set_enabled(on: bool) -> void:
	input_enabled = on
	look_enabled = on
	if not on:
		_set_target(null)
		TouchInput.reset()


func place_at(pos: Vector3, yaw: float) -> void:
	global_position = pos
	rotation = Vector3(0, yaw, 0)
	_pitch = 0.0
	head.rotation = Vector3.ZERO
	velocity = Vector3.ZERO


func get_yaw() -> float:
	return rotation.y


## Launch upwards/forwards (bounce mushrooms, geysers).
func launch(v: Vector3) -> void:
	velocity = v
	_launch_lock = 0.25
	_coyote = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if not look_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var m := event as InputEventMouseMotion
		_apply_look(m.relative * Settings.mouse_sensitivity)


func _apply_look(delta_deg: Vector2) -> void:
	rotate_y(deg_to_rad(-delta_deg.x))
	var dy := delta_deg.y * (-1.0 if Settings.invert_y else 1.0)
	_pitch = clampf(_pitch - deg_to_rad(dy), deg_to_rad(pitch_min_deg), deg_to_rad(pitch_max_deg))
	head.rotation.x = _pitch


func _physics_process(delta: float) -> void:
	if look_enabled:
		var td := TouchInput.consume_look()
		if td != Vector2.ZERO:
			_apply_look(td)
		var joy := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
		if joy.length() > 0.18:
			_apply_look(joy * 180.0 * delta)

	var move := Vector2.ZERO
	var sprint := false
	var walk := false
	var jump_pressed := false
	if input_enabled:
		move = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if TouchInput.move.length() > 0.01:
			move = TouchInput.move
		sprint = Input.is_action_pressed("sprint") or TouchInput.sprint_held
		walk = Input.is_action_pressed("walk")
		jump_pressed = Input.is_action_just_pressed("jump") or TouchInput.consume_jump()
		if Input.is_action_just_pressed("interact") or TouchInput.consume_interact():
			try_interact()

	var on_floor := is_on_floor()
	if on_floor:
		_coyote = coyote_time
	else:
		_coyote -= delta
	if jump_pressed:
		_jump_buffer = jump_buffer_time
	else:
		_jump_buffer -= delta
	_launch_lock -= delta

	# Gravity.
	if not on_floor or _launch_lock > 0.0:
		velocity.y = maxf(velocity.y - gravity * delta, -max_fall_speed)
		_fall_speed = maxf(_fall_speed, -velocity.y)

	if _jump_buffer > 0.0 and _coyote > 0.0:
		velocity.y = jump_velocity
		_jump_buffer = 0.0
		_coyote = 0.0
		AudioManager.play_sfx("jump", -6.0)

	# Speed from input magnitude: partial joystick = walk, full = run.
	var mag := clampf(move.length(), 0.0, 1.0)
	var target_speed := run_speed
	if walk:
		target_speed = walk_speed
	elif sprint:
		target_speed = sprint_speed
	if TouchInput.move.length() > 0.01 and not sprint:
		target_speed = lerpf(walk_speed, run_speed, smoothstep(0.35, 0.9, mag))
	var dir := (transform.basis * Vector3(move.x, 0, move.y))
	dir.y = 0
	if dir.length() > 1.0:
		dir = dir.normalized()
	var wanted := dir * target_speed
	var horiz := Vector3(velocity.x, 0, velocity.z)
	var accel := acceleration if on_floor else air_acceleration
	if wanted.length() < 0.01:
		# On the ground stop quickly; in the air keep momentum (bounce arcs, long jumps).
		accel = deceleration if on_floor else 0.8
	horiz = horiz.move_toward(wanted, accel * delta)
	velocity.x = horiz.x
	velocity.z = horiz.z

	move_and_slide()
	_keep_in_bounds()

	var now_on_floor := is_on_floor()
	if now_on_floor and not _was_on_floor:
		if _fall_speed > 4.0:
			landed.emit(_fall_speed)
			AudioManager.play_sfx("land", linear_to_db(clampf(_fall_speed / 14.0, 0.2, 1.0)))
		_fall_speed = 0.0
	_was_on_floor = now_on_floor

	_update_head_bob(delta, horiz.length(), now_on_floor)
	DreamFlower.focus_point = global_position
	_probe_timer -= delta
	if _probe_timer <= 0.0:
		_probe_timer = 0.08
		_update_target()


func _keep_in_bounds() -> void:
	var flat := Vector2(global_position.x, global_position.z)
	if flat.length() > world_radius:
		var clamped := flat.normalized() * world_radius
		global_position.x = clamped.x
		global_position.z = clamped.y


func _update_head_bob(delta: float, speed: float, on_floor: bool) -> void:
	var target_y := eye_height
	if on_floor and speed > 0.5:
		_bob_t += delta * (6.0 + speed * 0.9)
		if Settings.head_bob:
			target_y += sin(_bob_t * 2.0) * 0.045 * clampf(speed / run_speed, 0.0, 1.3)
		var phase := fmod(_bob_t, PI)
		if phase < _last_step_phase:
			AudioManager.play_sfx("footstep", -14.0 + clampf(speed - 4.0, -4.0, 4.0), randf_range(0.85, 1.15))
		_last_step_phase = phase
	head.position.y = lerpf(head.position.y, target_y, minf(1.0, delta * 12.0))


## Finds the best interactable: camera ray first, then a forgiving proximity
## cone (important for touch players who don't aim precisely).
func _update_target() -> void:
	if not input_enabled:
		_set_target(null)
		return
	var found: Interactable = null
	ray.force_raycast_update()
	if ray.is_colliding():
		var col := ray.get_collider()
		if col is Interactable and (col as Interactable).can_interact(self):
			found = col
	if found == null:
		var best_score := -INF
		var fwd := -camera.global_transform.basis.z
		for n in get_tree().get_nodes_in_group("interactable"):
			var it := n as Interactable
			if it == null or not it.is_inside_tree() or not it.can_interact(self):
				continue
			var to := it.global_position - camera.global_position
			var d := to.length()
			if d > proximity_range + it.radius:
				continue
			var facing := fwd.dot(to.normalized())
			if facing < 0.45:
				continue
			var score := facing * 2.0 - d * 0.5
			if score > best_score:
				best_score = score
				found = it
	_set_target(found)


func _set_target(t: Interactable) -> void:
	if t == current_target:
		return
	if is_instance_valid(current_target):
		current_target.set_highlighted(false)
	current_target = t
	if t:
		t.set_highlighted(true)
		EventBus.interaction_target_changed.emit(t.get_prompt(), true)
	else:
		EventBus.interaction_target_changed.emit("", false)
	target_changed.emit(t)


func refresh_prompt() -> void:
	if is_instance_valid(current_target):
		EventBus.interaction_target_changed.emit(current_target.get_prompt(), true)


func try_interact() -> void:
	_update_target()
	if is_instance_valid(current_target):
		current_target.interact(self)
		refresh_prompt()


## Wake-up intro: the player rises from lying in the moss.
func play_wake_up() -> void:
	set_enabled(false)
	head.position.y = 0.35
	head.rotation = Vector3(deg_to_rad(70), 0, deg_to_rad(-25))
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_interval(1.2)
	tw.tween_property(head, "rotation", Vector3(deg_to_rad(25), 0, deg_to_rad(-8)), 1.6)
	tw.tween_property(head, "position:y", 1.0, 1.0)
	tw.parallel().tween_property(head, "rotation", Vector3.ZERO, 1.4)
	tw.tween_property(head, "position:y", eye_height, 0.6)
	await tw.finished
	_pitch = 0.0
	set_enabled(true)
