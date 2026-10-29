class_name PauseMenu
extends Control
## In-game pause menu. Pauses the tree; works with mouse, touch and gamepad.

signal resumed()

var _main: VBoxContainer
var _settings: SettingsPanel
var _slots_box: VBoxContainer
var _center: CenterContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.0, 0.07, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_center = CenterContainer.new()
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_center)
	var panel := UiTheme.panel(UiTheme.BG_DEEP, UiTheme.EDGE)
	_center.add_child(panel)
	_main = VBoxContainer.new()
	_main.add_theme_constant_override("separation", 10)
	panel.add_child(_main)
	var t := UiTheme.title("Paused", 40)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_main.add_child(t)
	_main.add_child(UiTheme.button("Resume", resume, 320))
	_main.add_child(UiTheme.button("Save Game", _show_slots.bind(true), 320))
	_main.add_child(UiTheme.button("Load Game", _show_slots.bind(false), 320))
	_main.add_child(UiTheme.button("Settings", _open_settings, 320))
	_main.add_child(UiTheme.button("Main Menu", _to_menu, 320))
	if not OS.has_feature("mobile") and not OS.has_feature("web"):
		_main.add_child(UiTheme.button("Quit to Desktop", _quit, 320))
	_slots_box = VBoxContainer.new()
	_slots_box.visible = false
	_slots_box.add_theme_constant_override("separation", 8)
	_main.add_child(_slots_box)
	_settings = SettingsPanel.new()
	_settings.visible = false
	_settings.close_requested.connect(func() -> void:
		_settings.visible = false
		panel.visible = true)
	_center.add_child(_settings)


func open() -> void:
	visible = true
	get_tree().paused = true
	_slots_box.visible = false
	AudioManager.play_ui("ui_open")
	await get_tree().process_frame
	if _main.get_child_count() > 1:
		(_main.get_child(1) as Button).grab_focus()


func resume() -> void:
	if not visible:
		return
	visible = false
	_settings.visible = false
	get_tree().paused = false
	AudioManager.play_ui("ui_close")
	resumed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if _settings.visible:
			_settings.visible = false
			(_center.get_child(0) as Control).visible = true
		else:
			resume()


func _show_slots(saving: bool) -> void:
	for c in _slots_box.get_children():
		c.queue_free()
	_slots_box.visible = true
	_slots_box.add_child(UiTheme.label("Choose a slot to %s:" % ("save into" if saving else "load"), 18, UiTheme.GLOW))
	for slot: String in SaveManager.SLOTS:
		if saving and slot == "auto":
			continue
		var info := SaveManager.slot_info(slot)
		var desc := "Empty" if info.is_empty() else "Lv %d · %s · %s" % [int(info["level"]), Time.get_datetime_string_from_unix_time(int(info["saved_at"]), true).replace("T", " "), _fmt_time(float(info["play_time"]))]
		var name := "Autosave" if slot == "auto" else slot.capitalize().replace("Slot", "Slot ")
		var s := slot
		var b := UiTheme.button("%s — %s" % [name, desc], func() -> void:
			if saving:
				if SaveManager.save_game(s):
					EventBus.notify("Saved to %s" % name, "success")
				_show_slots(true)
			elif not info.is_empty():
				get_tree().paused = false
				SceneFlow.load_slot(s), 520)
		b.disabled = not saving and info.is_empty()
		b.add_theme_font_size_override("font_size", 16)
		_slots_box.add_child(b)


func _fmt_time(sec: float) -> String:
	var m := int(sec / 60.0)
	return "%dh %02dm" % [m / 60, m % 60]


func _open_settings() -> void:
	(_center.get_child(0) as Control).visible = false
	_settings.visible = true


func _to_menu() -> void:
	SaveManager.autosave("force")
	visible = false
	SceneFlow.go_to_main_menu()


func _quit() -> void:
	SaveManager.autosave("force")
	get_tree().quit()
