class_name Mechanism
extends Interactable
## Ancient mechanism: activating it emits object_activated(object_id), sets a
## world flag and plays an environmental reaction implemented by the region
## (connect to `activated`). Can require a flag or quest objective first.

signal activated()

@export var object_id: String = ""
@export var required_flag: String = ""
@export var locked_message: String = "It hums, but does not answer you. Not yet."
@export var once: bool = true
@export var activated_prompt: String = "Resonating"


func _after_ready() -> void:
	if prompt == "Interact":
		prompt = "Activate"
	if once and Game.profile and Game.profile.world.has_flag("activated_" + object_id):
		_set_done_visual()


func can_interact(by: Node) -> bool:
	if once and Game.profile and Game.profile.world.has_flag("activated_" + object_id):
		return false
	return super.can_interact(by)


func _on_interact(_by: Node) -> void:
	var prof := Game.profile
	if required_flag != "" and prof and not prof.world.has_flag(required_flag):
		EventBus.notify(locked_message, "warning")
		AudioManager.play_sfx("locked")
		return
	if prof:
		prof.world.set_flag("activated_" + object_id, true)
	AudioManager.play_sfx("mechanism")
	EventBus.object_activated.emit(object_id)
	activated.emit()
	if once:
		_set_done_visual()


func _set_done_visual() -> void:
	if _marker:
		_marker.visible = false
