class_name DreamFlower
extends Node3D
## Animated dream flower: petals slowly open and close ("breathing"), and the
## head curiously turns to follow a nearby player.

## World point flowers are curious about (updated by the player controller).
static var focus_point: Vector3 = Vector3(1e9, 0, 0)

const CURIOUS_RANGE := 11.0
const ACTIVE_RANGE := 28.0

var phase: float = 0.0
var speed: float = 0.4
var _t: float = 0.0
var _head: Node3D
var _pivots: Array[Node3D] = []
var _rest_basis: Basis


func _ready() -> void:
	_head = get_node_or_null("Head") as Node3D
	if _head == null:
		set_process(false)
		return
	_rest_basis = _head.transform.basis
	for c in _head.get_children():
		if c is Node3D and not c is MeshInstance3D:
			_pivots.append(c as Node3D)
	_t = phase


func _process(delta: float) -> void:
	var head_pos := _head.global_position
	var dist := head_pos.distance_to(focus_point)
	if dist > ACTIVE_RANGE:
		return
	_t += delta * speed
	var curious := clampf(1.0 - (dist - 3.0) / (CURIOUS_RANGE - 3.0), 0.0, 1.0)
	# Flowers open up wide when someone is near.
	var breath := 0.5 + 0.5 * sin(_t)
	var open := clampf(lerpf(breath, 1.0, curious), 0.0, 1.0)
	var angle := lerpf(-1.15, -0.12, open)
	for i in _pivots.size():
		_pivots[i].rotation.x = angle + sin(_t * 2.0 + i) * 0.04
	var target := _rest_basis
	if curious > 0.0:
		var to := (focus_point + Vector3.UP * 1.2 - head_pos)
		to = global_transform.basis.inverse() * to
		var up := (Vector3.UP * 1.6 + to.normalized() * curious).normalized()
		var ref := Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT
		var x := up.cross(ref).normalized()
		var z := x.cross(up).normalized()
		target = Basis(x, up, z)
	_head.transform.basis = _head.transform.basis.slerp(target.orthonormalized(), minf(1.0, delta * 3.0)).orthonormalized()
