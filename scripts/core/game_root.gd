class_name GameRoot
extends Node
## Root of the in-game scene. Loads the current region, spawns the player,
## owns the UI layer and coordinates modal UI (dialogue, menus, combat) with
## player control and mouse capture.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const COMBAT_SCRIPT := "res://scripts/combat/combat_manager.gd"
const GRIMOIRE_SCRIPT := "res://scripts/ui/grimoire/grimoire_menu.gd"
const SHOP_SCRIPT := "res://scripts/ui/shop_panel.gd"

var world_root: Node3D
var region: Region
var player: PlayerController
var ui_layer: CanvasLayer
var hud: HUD
var dialogue_box: DialogueBox
var touch: TouchControls
var pause_menu: PauseMenu
var loading: LoadingScreen
var grimoire: Control
var shop: Control
var combat: Node
var _modals: Array[String] = []
var _ready_for_input: bool = false


func _ready() -> void:
	add_to_group("game_root")
	world_root = Node3D.new()
	world_root.name = "World"
	add_child(world_root)
	add_child(PerfLogger.new())
	_build_ui()
	Settings.apply_to_viewport(get_viewport())
	Settings.changed.connect(func(section: String) -> void:
		if section == "graphics":
			Settings.apply_to_viewport(get_viewport())
		if section == "controls":
			_update_touch_visibility())
	if Game.profile == null:
		# Started the scene directly (editor F6): begin a fresh session.
		Game.start_new_game()
	await _load_region(Game.current_region)


func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.name = "UI"
	ui_layer.layer = 10
	add_child(ui_layer)
	hud = HUD.new()
	hud.menu_button.connect(open_grimoire)
	hud.pause_button.connect(open_pause)
	ui_layer.add_child(hud)
	touch = TouchControls.new()
	touch.reserved_changed.connect(hud.set_reserved_rects)
	ui_layer.add_child(touch)
	hud.set_reserved_rects(touch.reserved_rects())
	dialogue_box = DialogueBox.new()
	dialogue_box.opened.connect(func() -> void: open_modal("dialogue"))
	dialogue_box.closed.connect(func() -> void: close_modal("dialogue"))
	ui_layer.add_child(dialogue_box)
	if ResourceLoader.exists(GRIMOIRE_SCRIPT):
		grimoire = (load(GRIMOIRE_SCRIPT) as GDScript).new()
		grimoire.connect("closed", func() -> void: close_modal("grimoire"))
		ui_layer.add_child(grimoire)
	if ResourceLoader.exists(SHOP_SCRIPT):
		shop = (load(SHOP_SCRIPT) as GDScript).new()
		shop.connect("closed", func() -> void: close_modal("shop"))
		ui_layer.add_child(shop)
	pause_menu = PauseMenu.new()
	pause_menu.resumed.connect(func() -> void: close_modal("pause"))
	ui_layer.add_child(pause_menu)
	loading = LoadingScreen.new()
	ui_layer.add_child(loading)
	if ResourceLoader.exists(COMBAT_SCRIPT):
		combat = (load(COMBAT_SCRIPT) as GDScript).new()
		combat.name = "CombatManager"
		add_child(combat)
		combat.set("game_root", self)
	EventBus.dialogue_requested.connect(_on_dialogue_requested)
	EventBus.combat_requested.connect(_on_combat_requested)
	EventBus.shop_requested.connect(_on_shop_requested)
	EventBus.menu_requested.connect(open_grimoire)
	_update_touch_visibility()


func _update_touch_visibility() -> void:
	var t := Settings.uses_touch()
	touch.visible = t and _modals.is_empty()
	hud.touch_mode = t


func _load_region(region_id: String) -> void:
	loading.visible = true
	var info: Dictionary = Database.REGIONS.get(region_id, Database.REGIONS["dreaming_meadow"])
	var scene: PackedScene = load(String(info["scene"]))
	region = scene.instantiate() as Region
	world_root.add_child(region)
	region.build_progress.connect(loading.set_progress)
	SceneFlow.region_ready()
	await region.build()
	hud.set_region_name(region.biome.display_name)
	player = PLAYER_SCENE.instantiate() as PlayerController
	world_root.add_child(player)
	var spawn := Game.pending_spawn
	var intro := bool(spawn.get("intro", false))
	if spawn.has("position"):
		player.place_at(spawn["position"], float(spawn.get("yaw", 0.0)))
	else:
		var sp := region.get_spawn(String(spawn.get("spawn", "default")))
		player.place_at(sp["position"], float(sp["yaw"]))
	Game.pending_spawn = {}
	loading.set_progress(1.0, "Awake.")
	var tw := create_tween()
	tw.tween_property(loading, "modulate:a", 0.0, 0.8)
	tw.tween_callback(func() -> void: loading.visible = false)
	_ready_for_input = true
	_apply_control_state()
	if intro:
		hud.show_banner("The Dreaming Meadow", "— You wake to the sound of humming —")
		await player.play_wake_up()
		EventBus.location_visited.emit("awakening_hollow")
		_apply_control_state()
		SaveManager.autosave("force")
	else:
		EventBus.notify("Welcome back to %s." % region.biome.display_name, "info")


# ------------------------------------------------------------------ modals
func open_modal(modal: String) -> void:
	if not modal in _modals:
		_modals.append(modal)
	_apply_control_state()


func close_modal(modal: String) -> void:
	_modals.erase(modal)
	_apply_control_state()


func has_modal() -> bool:
	return not _modals.is_empty()


func _apply_control_state() -> void:
	var free_play := _modals.is_empty() and _ready_for_input
	if player:
		player.set_enabled(free_play)
	touch.visible = Settings.uses_touch() and free_play
	if touch.visible == false:
		touch.release_all()
	hud.visible = not ("combat" in _modals)
	hud.set_crosshair_visible(free_play)
	if free_play and not Settings.uses_touch() and DisplayServer.window_is_focused():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if not _ready_for_input:
		return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if "combat" in _modals:
			return
		if hud.is_lore_open():
			hud.hide_lore()
		elif "grimoire" in _modals and grimoire:
			grimoire.call("close")
		elif "shop" in _modals and shop:
			shop.call("close")
		elif "dialogue" in _modals:
			dialogue_box.close()
		else:
			open_pause()
		return
	if event.is_action_pressed("debug_perf"):
		Settings.show_fps = not Settings.show_fps
		Settings.notify_changed("graphics")
	if not _modals.is_empty():
		if "grimoire" in _modals and grimoire:
			for pair: Array in [["menu_inventory", "inventory"], ["menu_spellbook", "spellbook"], ["menu_journal", "journal"], ["menu_map", "map"], ["menu_skills", "skills"], ["menu_character", "character"]]:
				if event.is_action_pressed(String(pair[0])):
					grimoire.call("close")
					get_viewport().set_input_as_handled()
					return
		return
	for pair: Array in [["menu_inventory", "inventory"], ["menu_spellbook", "spellbook"], ["menu_journal", "journal"], ["menu_map", "map"], ["menu_skills", "skills"], ["menu_character", "character"]]:
		if event.is_action_pressed(String(pair[0])):
			open_grimoire(String(pair[1]))
			get_viewport().set_input_as_handled()
			return
	# Click back into the game recaptures the mouse on PC.
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and not Settings.uses_touch():
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _ready_for_input and _modals.is_empty() and not Settings.uses_touch():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		SaveManager.autosave("force")


func open_pause() -> void:
	if not _modals.is_empty() and not ("grimoire" in _modals):
		return
	if grimoire and "grimoire" in _modals:
		grimoire.call("close")
	open_modal("pause")
	pause_menu.open()


func open_grimoire(tab: String = "inventory") -> void:
	if grimoire == null or ("combat" in _modals) or ("dialogue" in _modals):
		return
	if "grimoire" in _modals:
		grimoire.call("show_tab", tab)
		return
	open_modal("grimoire")
	grimoire.call("open", tab)


func _on_dialogue_requested(npc: Node, dialogue_id: String) -> void:
	if "combat" in _modals or dialogue_box.is_open():
		return
	dialogue_box.open(npc, dialogue_id)


func _on_shop_requested(shop_id: String) -> void:
	if shop == null:
		return
	if dialogue_box.is_open():
		dialogue_box.close()
	open_modal("shop")
	shop.call("open", shop_id)


func _on_combat_requested(encounter_id: String, source: Node) -> void:
	if combat == null or "combat" in _modals or Game.in_combat:
		return
	if dialogue_box.is_open():
		dialogue_box.close()
	if hud.is_lore_open():
		hud.hide_lore()
	open_modal("combat")
	await combat.call("start_encounter", encounter_id, source)
	close_modal("combat")
