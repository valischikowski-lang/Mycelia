extends Node
func _ready() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var h := HUD.new()
	layer.add_child(h)
	await get_tree().process_frame
	await get_tree().process_frame
	print("hud size=", h.size, " pos=", h.position, " anchors=", h.anchor_left, ",", h.anchor_right, " vp=", get_viewport().get_visible_rect().size)
	get_tree().quit()
