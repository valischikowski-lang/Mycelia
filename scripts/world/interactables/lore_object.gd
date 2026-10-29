class_name LoreObject
extends Interactable
## Inspectable object that reveals a piece of lore (stored in the journal)
## and optionally activates an objective / grants a small reward once.

@export var lore_id: String = ""
@export var lore_title: String = ""
@export_multiline var lore_text: String = ""
@export var activate_id: String = ""
@export var xp_reward: int = 10


func _after_ready() -> void:
	if prompt == "Interact":
		prompt = "Inspect"


func _on_interact(_by: Node) -> void:
	var prof := Game.profile
	var first := prof != null and prof.world.add_lore(lore_id)
	SceneFlow.show_lore(lore_title, lore_text)
	if first:
		EventBus.lore_discovered.emit(lore_id)
		EventBus.notify("Lore recorded in your Journal: %s" % lore_title, "lore")
		if xp_reward > 0:
			Game.grant_xp(xp_reward)
	if activate_id != "":
		EventBus.object_activated.emit(activate_id)
	AudioManager.play_sfx("inspect")
