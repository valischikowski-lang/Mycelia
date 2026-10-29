class_name CreatureRig
extends Node3D
## Animation controller for procedurally built creatures / characters.
## Structure: self -> "Body" (animated pivot) -> parts. Optional "Eyes" node
## for blinking. All one-shot animations are awaitable.

signal animation_finished(anim: String)

@export var idle_bob: float = 0.06
@export var idle_speed: float = 2.2
@export var squash: float = 0.05
@export var hop: bool = false

var body: Node3D
var eyes: Node3D
var walking: bool = false
var _t: float = 0.0
var _base_scale: Vector3 = Vector3.ONE
var _blink_timer: float = 2.0
var _busy: bool = false
var _dead: bool = false


func _ready() -> void:
	body = get_node_or_null("Body") as Node3D
	eyes = get_node_or_null("Body/Eyes") as Node3D
	if body:
		_base_scale = body.scale
	_t = randf() * 10.0


func _process(delta: float) -> void:
	if body == null or _dead:
		return
	_t += delta
	if not _busy:
		var speed := idle_speed * (2.2 if walking else 1.0)
		var s := sin(_t * speed)
		if hop and walking:
			body.position.y = absf(s) * 0.25
		else:
			body.position.y = s * idle_bob
		var sq := 1.0 + s * squash
		body.scale = Vector3(_base_scale.x / sqrt(sq), _base_scale.y * sq, _base_scale.z / sqrt(sq))
		body.rotation.z = sin(_t * speed * 0.5) * (0.08 if walking else 0.03)
	if eyes:
		_blink_timer -= delta
		if _blink_timer <= 0.0:
			_blink_timer = randf_range(1.8, 4.5)
			var tw := create_tween()
			tw.tween_property(eyes, "scale:y", 0.1, 0.06)
			tw.tween_property(eyes, "scale:y", 1.0, 0.09)


func face_towards(target: Vector3, instant: bool = false) -> void:
	var flat := Vector3(target.x, global_position.y, target.z)
	if flat.distance_to(global_position) < 0.01:
		return
	# Models face +Z; Basis.looking_at points -Z, so aim at the mirrored point.
	var want := Basis.looking_at(global_position - flat, Vector3.UP)
	var s := global_transform.basis.get_scale()
	if instant:
		global_transform.basis = want.scaled(s)
	else:
		var from := global_transform.basis.orthonormalized()
		var tw := create_tween()
		tw.tween_method(func(w: float) -> void:
			global_transform.basis = from.slerp(want, w).scaled(s), 0.0, 1.0, 0.25)


## Lunge forward toward `target` and back.
func play_attack(target: Vector3) -> void:
	if body == null:
		return
	_busy = true
	var start := body.global_position
	var dir := (target - start)
	dir.y = 0
	var reach := minf(dir.length() * 0.45, 3.0)
	var local_fwd: Vector3 = body.get_parent().global_transform.basis.inverse() * dir.normalized() * reach
	var tw := create_tween().set_trans(Tween.TRANS_BACK)
	tw.tween_property(body, "scale", Vector3(_base_scale.x * 1.15, _base_scale.y * 0.8, _base_scale.z * 1.15), 0.18)
	tw.tween_property(body, "position", local_fwd + Vector3.UP * 0.3, 0.16).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(body, "scale", _base_scale * Vector3(0.9, 1.15, 0.9), 0.16)
	tw.tween_property(body, "position", Vector3.ZERO, 0.3).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(body, "scale", _base_scale, 0.3)
	await tw.finished
	_busy = false
	animation_finished.emit("attack")


## Rise and glow while channelling a spell.
func play_cast() -> void:
	if body == null:
		return
	_busy = true
	var tw := create_tween().set_trans(Tween.TRANS_SINE)
	tw.tween_property(body, "position:y", 0.45, 0.25)
	tw.parallel().tween_property(body, "scale", _base_scale * 1.08, 0.25)
	tw.tween_property(body, "position:y", 0.0, 0.25)
	tw.parallel().tween_property(body, "scale", _base_scale, 0.25)
	await tw.finished
	_busy = false
	animation_finished.emit("cast")


func play_hit() -> void:
	if body == null:
		return
	_busy = true
	_flash(Color(1, 1, 1))
	var tw := create_tween()
	tw.tween_property(body, "rotation:x", -0.35, 0.07)
	tw.parallel().tween_property(body, "scale", _base_scale * Vector3(1.2, 0.75, 1.2), 0.07)
	tw.tween_property(body, "rotation:x", 0.0, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(body, "scale", _base_scale, 0.25)
	await tw.finished
	_busy = false
	animation_finished.emit("hit")


func play_death() -> void:
	if body == null:
		return
	_busy = true
	var tw := create_tween()
	tw.tween_property(body, "rotation:z", 0.5, 0.25)
	tw.tween_property(body, "scale", _base_scale * Vector3(1.4, 0.05, 1.4), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await tw.finished
	_dead = true
	visible = false
	animation_finished.emit("death")


func play_victory() -> void:
	if body == null:
		return
	_busy = true
	var tw := create_tween()
	for i in 2:
		tw.tween_property(body, "position:y", 0.6, 0.18).set_ease(Tween.EASE_OUT)
		tw.tween_property(body, "position:y", 0.0, 0.18).set_ease(Tween.EASE_IN)
	tw.tween_property(body, "rotation:y", TAU, 0.5)
	tw.tween_callback(func() -> void: body.rotation.y = 0.0)
	await tw.finished
	_busy = false


func revive() -> void:
	_dead = false
	visible = true
	if body:
		body.scale = _base_scale
		body.rotation = Vector3.ZERO
		body.position = Vector3.ZERO


## Briefly flashes the whole rig with an additive overlay (hit feedback).
func _flash(color: Color) -> void:
	if body == null:
		return
	var overlay := StandardMaterial3D.new()
	overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	overlay.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	overlay.albedo_color = Color(color, 0.9)
	var meshes := body.find_children("*", "MeshInstance3D", true, false)
	for mi in meshes:
		(mi as MeshInstance3D).material_overlay = overlay
	var tw := create_tween()
	tw.tween_property(overlay, "albedo_color:a", 0.0, 0.25)
	tw.tween_callback(func() -> void:
		for mi in meshes:
			if is_instance_valid(mi):
				(mi as MeshInstance3D).material_overlay = null)
