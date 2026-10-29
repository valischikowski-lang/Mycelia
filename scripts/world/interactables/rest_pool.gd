class_name RestPool
extends Interactable
## A glowing dream pool: restores health and mana and is a safe autosave point.


func _after_ready() -> void:
	if prompt == "Interact":
		prompt = "Rest at"
	if display_name == "":
		display_name = "Dream Pool"
	cooldown = 2.0


func _on_interact(_by: Node) -> void:
	if Game.profile == null:
		return
	Game.profile.stats.full_restore()
	AudioManager.play_sfx("heal")
	EventBus.notify("You drink from the pool. Health and mana restored.", "success")
	SpellFX.burst(get_parent(), global_position + Vector3.UP * 0.5, Color(0.3, 1.0, 0.9), 60)
	SaveManager.autosave("rest")
