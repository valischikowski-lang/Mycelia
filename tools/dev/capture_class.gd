extends Node
## Dev tool: screenshots of the Fourfold Threshold for each class.
##   godot --rendering-driver opengl3 res://tools/dev/capture_class.tscn -- <out_dir>

func _ready() -> void:
	var out := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://class"
	DirAccess.make_dir_recursive_absolute(out)
	var layer := CanvasLayer.new()
	add_child(layer)
	var cs := ClassSelect.new()
	layer.add_child(cs)
	for id: String in ClassSelect.ORDER:
		cs.select(id)
		for i in 30:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(out.path_join(id + ".png"))
	get_tree().quit()
