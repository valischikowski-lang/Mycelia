extends Node
## Dev tool: screenshot of the main menu.
func _ready() -> void:
	var out := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://menu.png"
	add_child(load("res://scenes/menus/main_menu.tscn").instantiate())
	for i in 90:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out)
	get_tree().quit()
