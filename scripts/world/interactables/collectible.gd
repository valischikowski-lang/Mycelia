class_name Collectible
extends Interactable
## A world pickup with a unique persistent id. Once collected it is recorded
## in WorldState and will not respawn.

@export var item_id: String = ""
@export var amount: int = 1
## Unique id for persistence (e.g. "meadow_fragment_lake").
@export var world_id: String = ""
@export var bob: bool = true
@export var spin_speed: float = 0.8
@export var xp_reward: int = 0

var visual: Node3D
var _base_y: float = 0.0
var _t: float = 0.0


func _after_ready() -> void:
	prompt = "Collect"
	var d := Database.item(item_id)
	if d and display_name == "":
		display_name = d.display_name
	if Game.profile and world_id != "" and Game.profile.world.is_consumed(world_id):
		queue_free()
		return
	visual = get_node_or_null("Visual") as Node3D
	if visual:
		_base_y = visual.position.y


func _process(delta: float) -> void:
	super._process(delta)
	if visual:
		_t += delta
		visual.rotation.y += spin_speed * delta
		if bob:
			visual.position.y = _base_y + sin(_t * 2.0) * 0.12


func _on_interact(_by: Node) -> void:
	var prof := Game.profile
	if prof == null:
		return
	var added := prof.inventory.add(item_id, amount)
	if added <= 0:
		EventBus.notify("Your satchel is full.", "warning")
		return
	if world_id != "":
		prof.world.consume(world_id)
	var d := Database.item(item_id)
	EventBus.notify("+%d %s" % [added, d.display_name if d else item_id], "item")
	AudioManager.play_sfx("pickup")
	EventBus.item_collected.emit(item_id, added)
	if xp_reward > 0:
		Game.grant_xp(xp_reward)
	enabled = false
	SpellFX.burst(get_parent(), global_position + Vector3.UP * 0.4, d.icon_color if d else Color.CYAN, 40)
	var tw := create_tween()
	if visual:
		tw.tween_property(visual, "scale", Vector3.ONE * 0.01, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)
