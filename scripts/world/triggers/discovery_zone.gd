class_name DiscoveryZone
extends Area3D
## Fires location_visited / area_discovered when the player enters.
## Discoveries grant XP once and appear on the map.

@export var area_id: String = ""
@export var display_name: String = ""
@export var radius: float = 8.0
@export var height: float = 12.0
@export var xp_reward: int = 15
## If false the zone only reports visits (used for quest locations).
@export var is_discovery: bool = true
@export var silent: bool = false

var _inside: bool = false


func _ready() -> void:
	add_to_group("discovery_zone")
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = height
	cs.shape = cyl
	add_child(cs)
	body_entered.connect(_on_enter)
	body_exited.connect(func(b: Node3D) -> void:
		if b.is_in_group("player"):
			_inside = false)


func _on_enter(body: Node3D) -> void:
	if not body.is_in_group("player") or _inside:
		return
	_inside = true
	EventBus.location_visited.emit(area_id)
	if not is_discovery or Game.profile == null:
		return
	if Game.profile.world.discover(area_id):
		EventBus.area_discovered.emit(area_id)
		if not silent:
			SceneFlow.show_discovery(display_name)
			AudioManager.play_sfx("discovery")
		if xp_reward > 0:
			Game.grant_xp(xp_reward)
