extends Node
## Top-level flow between the main menu, the game scene and regions, with a
## global transition overlay. HUD-level popups (lore, discovery banners) are
## forwarded to whichever HUD is active via the "hud" group.

const MAIN_MENU := "res://scenes/menus/main_menu.tscn"
const GAME_SCENE := "res://scenes/main/game.tscn"
const TRANSITION_SHADER := preload("res://shaders/transition.gdshader")

var _layer: CanvasLayer
var _overlay: ColorRect
var _mat: ShaderMaterial
var busy: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)
	_overlay = ColorRect.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = TRANSITION_SHADER
	_mat.set_shader_parameter("progress", 0.0)
	_overlay.material = _mat
	_overlay.visible = false
	_layer.add_child(_overlay)


func _set_progress(v: float) -> void:
	_mat.set_shader_parameter("progress", v)
	var vp := get_viewport().get_visible_rect().size
	_mat.set_shader_parameter("aspect", vp.x / maxf(vp.y, 1.0))


func fade_out(duration: float = 0.6) -> void:
	_overlay.visible = true
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_method(_set_progress, 0.0, 1.0, duration).set_trans(Tween.TRANS_SINE)
	await tw.finished


func fade_in(duration: float = 0.8) -> void:
	_overlay.visible = true
	var tw := create_tween()
	tw.tween_method(_set_progress, 1.0, 0.0, duration).set_trans(Tween.TRANS_SINE)
	await tw.finished
	_overlay.visible = false
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE


func cover_instantly() -> void:
	_overlay.visible = true
	_set_progress(1.0)


func start_new_game() -> void:
	if busy:
		return
	busy = true
	await fade_out()
	Game.start_new_game()
	_change(GAME_SCENE)


func continue_game() -> void:
	var slot := SaveManager.latest_slot()
	if slot != "":
		load_slot(slot)


func load_slot(slot: String) -> void:
	if busy:
		return
	busy = true
	await fade_out()
	if not SaveManager.load_game(slot):
		busy = false
		await fade_in()
		return
	_change(GAME_SCENE)


func go_to_main_menu() -> void:
	if busy:
		return
	busy = true
	await fade_out()
	get_tree().paused = false
	Game.end_session()
	_change(MAIN_MENU)
	await get_tree().process_frame
	await fade_in()


func travel_to_region(region_id: String, spawn: String) -> void:
	if busy:
		return
	busy = true
	SaveManager.autosave("force")
	await fade_out()
	Game.current_region = region_id
	Game.pending_spawn = {"spawn": spawn}
	_change(GAME_SCENE)


func _change(path: String) -> void:
	get_tree().paused = false
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("SceneFlow: cannot open %s" % path)
	busy = false


## Called by the game root once the region finished building.
func region_ready() -> void:
	await fade_in(1.0)


func show_lore(title: String, text: String) -> void:
	get_tree().call_group("hud", "show_lore", title, text)


func show_discovery(area_name: String) -> void:
	get_tree().call_group("hud", "show_discovery", area_name)
