class_name BouncePad
extends Area3D
## Springy mushroom cap that launches the player. Used to build vertical
## exploration routes to floating islands.

@export var launch_velocity: Vector3 = Vector3(0, 15, 0)
## When set, the launch is solved ballistically so the player lands on this
## global point (independent of where exactly they touched the pad).
@export var has_target: bool = false
@export var target_point: Vector3 = Vector3.ZERO
## Extra height above the higher of start/target at the arc's apex.
@export var clearance: float = 3.0
@export var radius: float = 1.2
## Mesh node that squashes on bounce.
@export var visual_path: NodePath

var _visual: Node3D
var _cool: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = 0.8
	cs.shape = cyl
	add_child(cs)
	body_entered.connect(_on_body)
	if not visual_path.is_empty():
		_visual = get_node_or_null(visual_path) as Node3D


func _physics_process(delta: float) -> void:
	_cool -= delta


func _on_body(body: Node3D) -> void:
	if _cool > 0.0 or not body is PlayerController:
		return
	var p := body as PlayerController
	if p.velocity.y > 2.0:
		return
	_cool = 0.4
	if has_target:
		p.launch(solve_launch(p.global_position, target_point, p.gravity, clearance))
	else:
		p.launch(global_transform.basis * launch_velocity)
	AudioManager.play_sfx("bounce")
	if _visual:
		var base := _visual.scale
		var tw := _visual.create_tween()
		tw.tween_property(_visual, "scale", Vector3(base.x * 1.25, base.y * 0.6, base.z * 1.25), 0.08)
		tw.tween_property(_visual, "scale", base, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Velocity that carries a body from `from` to `to` under `gravity`, peaking
## `clearance` meters above the higher of the two points.
static func solve_launch(from: Vector3, to: Vector3, gravity: float, clearance: float = 3.0) -> Vector3:
	var apex := maxf(from.y, to.y) + clearance
	var vy := sqrt(2.0 * gravity * (apex - from.y))
	var t_up := vy / gravity
	var t_down := sqrt(2.0 * (apex - to.y) / gravity)
	var flat := Vector3(to.x - from.x, 0.0, to.z - from.z)
	var horiz := flat / (t_up + t_down)
	return Vector3(horiz.x, vy, horiz.z)
