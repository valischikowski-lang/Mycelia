class_name Interactable
extends Area3D
## Base class for everything the player can interact with. Subclasses
## override _on_interact() and optionally get_prompt()/can_interact().
##
## Detected by the player's camera ray (collision layer 3) or by a proximity
## cone fallback (group "interactable").

signal interacted(by: Node)
signal highlighted(on: bool)

@export var prompt: String = "Interact"
@export var display_name: String = ""
@export var radius: float = 0.9
@export var cooldown: float = 0.5
@export var enabled: bool = true
@export var show_marker: bool = true
@export var marker_height: float = 1.2
@export var marker_color: Color = Color(0.6, 1.0, 1.0)

var _last_time: float = -100.0
var _marker: Label3D


func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 4
	collision_mask = 0
	monitoring = false
	monitorable = true
	var has_shape := false
	for c in get_children():
		if c is CollisionShape3D:
			has_shape = true
	if not has_shape:
		var cs := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = radius
		cs.shape = sphere
		add_child(cs)
	if show_marker:
		_marker = Label3D.new()
		_marker.text = "✦"
		_marker.font_size = 64
		_marker.pixel_size = 0.004
		_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_marker.modulate = Color(marker_color, 0.55)
		_marker.outline_size = 0
		_marker.no_depth_test = false
		_marker.position = Vector3(0, marker_height, 0)
		_marker.shaded = false
		add_child(_marker)
	_after_ready()


func _after_ready() -> void:
	pass


func _process(delta: float) -> void:
	if _marker and _marker.visible:
		_marker.position.y = marker_height + sin(Time.get_ticks_msec() * 0.003 + position.x) * 0.08


func can_interact(_by: Node) -> bool:
	return enabled and is_visible_in_tree() and Time.get_ticks_msec() * 0.001 - _last_time >= cooldown


func get_prompt() -> String:
	if display_name != "":
		return "%s  %s" % [prompt, display_name]
	return prompt


func interact(by: Node) -> void:
	if not can_interact(by):
		return
	_last_time = Time.get_ticks_msec() * 0.001
	_on_interact(by)
	interacted.emit(by)


func _on_interact(_by: Node) -> void:
	pass


func set_highlighted(on: bool) -> void:
	if _marker:
		_marker.modulate = Color(marker_color, 1.0 if on else 0.55)
		_marker.font_size = 88 if on else 64
	highlighted.emit(on)


func set_enabled(on: bool) -> void:
	enabled = on
	if _marker:
		_marker.visible = on
