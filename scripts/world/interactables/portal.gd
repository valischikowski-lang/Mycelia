class_name RegionPortal
extends Interactable
## Travels to another region. Regions that aren't built yet show a sealed
## message instead, so the world can be extended without touching this code.

@export var target_region: String = ""
@export var target_spawn: String = "default"
@export var visit_id: String = ""
@export_multiline var sealed_text: String = "The gate is sealed by a membrane of dreaming light."


func _after_ready() -> void:
	if prompt == "Interact":
		prompt = "Enter"
	var info: Dictionary = Database.REGIONS.get(target_region, {})
	if display_name == "":
		display_name = String(info.get("name", target_region))


func _on_interact(_by: Node) -> void:
	if visit_id != "":
		EventBus.location_visited.emit(visit_id)
	var info: Dictionary = Database.REGIONS.get(target_region, {})
	if not bool(info.get("available", false)):
		SceneFlow.show_lore(display_name, sealed_text)
		AudioManager.play_sfx("locked")
		return
	SceneFlow.travel_to_region(target_region, target_spawn)
