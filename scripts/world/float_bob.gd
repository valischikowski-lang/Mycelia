class_name FloatBob
extends Node
## Makes its parent Node3D float: gentle bobbing, slow sway and an optional
## slow orbit around its starting point (moving islands above the clouds).

@export var amplitude: float = 0.5
@export var speed: float = 0.35
@export var sway: float = 0.03
## Orbit radius in meters (0 = stay in place).
@export var orbit: float = 0.0
@export var orbit_speed: float = 0.02

var _origin: Vector3
var _t: float = 0.0
var _parent: Node3D


func _ready() -> void:
	_parent = get_parent() as Node3D
	if _parent:
		_origin = _parent.position
	_t = fmod(_origin.x * 0.37 + _origin.z * 0.11, TAU)


func _process(delta: float) -> void:
	if _parent == null:
		return
	_t += delta
	var p := _origin + Vector3(0, sin(_t * speed) * amplitude, 0)
	if orbit > 0.0:
		var a := _t * orbit_speed
		p += Vector3(cos(a) * orbit - orbit, 0, sin(a) * orbit)
	_parent.position = p
	_parent.rotation.z = sin(_t * speed * 0.7) * sway
	_parent.rotation.x = cos(_t * speed * 0.6) * sway
