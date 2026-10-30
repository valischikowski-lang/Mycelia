class_name SettingsPanel
extends PanelContainer
## Settings UI shared by the main menu, pause menu and Grimoire.
## Every control writes straight into the Settings autoload.

signal close_requested()

var _quality_buttons: Array[Button] = []


func _ready() -> void:
	theme = UiTheme.get_theme()
	add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.BG_DEEP, UiTheme.EDGE))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(620, 460)
	add_child(scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 12)
	scroll.add_child(v)
	v.add_child(UiTheme.title("Settings", 34))
	# Graphics preset.
	v.add_child(_section("Graphics Quality"))
	var qrow := HBoxContainer.new()
	qrow.add_theme_constant_override("separation", 8)
	for i in 3:
		var q := i
		var b := UiTheme.button(["Low", "Medium", "High"][i], func() -> void:
			Settings.set_quality(q as Settings.Quality)
			_refresh_quality(), 150)
		b.toggle_mode = true
		_quality_buttons.append(b)
		qrow.add_child(b)
	v.add_child(qrow)
	_refresh_quality()
	v.add_child(_slider("Render Scale", 0.5, 1.0, Settings.render_scale, func(x: float) -> void:
		Settings.render_scale = x
		Settings.notify_changed("graphics")))
	v.add_child(_slider("Field of View", 60.0, 100.0, Settings.fov, func(x: float) -> void:
		Settings.fov = x
		Settings.notify_changed("graphics")))
	v.add_child(_check("Show FPS / performance", Settings.show_fps, func(on: bool) -> void:
		Settings.show_fps = on
		Settings.notify_changed("graphics")))
	# Controls.
	v.add_child(_section("Controls"))
	v.add_child(_slider("Mouse Sensitivity", 0.03, 0.4, Settings.mouse_sensitivity, func(x: float) -> void:
		Settings.mouse_sensitivity = x
		Settings.notify_changed("controls")))
	v.add_child(_slider("Touch Look Sensitivity", 0.3, 2.5, Settings.touch_sensitivity, func(x: float) -> void:
		Settings.touch_sensitivity = x
		Settings.notify_changed("controls")))
	v.add_child(_check("Invert Look Y", Settings.invert_y, func(on: bool) -> void:
		Settings.invert_y = on
		Settings.notify_changed("controls")))
	v.add_child(_check("Over-the-Shoulder Combat Camera", Settings.combat_camera_third_person, func(on: bool) -> void:
		Settings.combat_camera_third_person = on
		Settings.notify_changed("controls")))
	v.add_child(_check("Head Bobbing", Settings.head_bob, func(on: bool) -> void:
		Settings.head_bob = on
		Settings.notify_changed("controls")))
	v.add_child(_check("Force Touch Controls (testing on PC)", Settings.force_touch_controls, func(on: bool) -> void:
		Settings.force_touch_controls = on
		Settings.notify_changed("controls")))
	# Audio.
	v.add_child(_section("Audio"))
	for bus: String in ["Master", "Music", "Ambient", "Effects", "UI"]:
		var b2 := bus
		v.add_child(_slider(bus, 0.0, 1.0, float(Settings.volumes[bus]), func(x: float) -> void: Settings.set_volume(b2, x)))
	var close := UiTheme.button("Done", func() -> void: close_requested.emit(), 200)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(close)


func _refresh_quality() -> void:
	for i in _quality_buttons.size():
		_quality_buttons[i].button_pressed = i == int(Settings.quality)
		_quality_buttons[i].add_theme_stylebox_override("normal", UiTheme.button_style("selected" if i == int(Settings.quality) else "normal"))


func _section(text: String) -> Label:
	var l := UiTheme.label(text, 22, UiTheme.GLOW, UiTheme.bold_font())
	return l


func _slider(text: String, min_v: float, max_v: float, value: float, on_change: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var l := UiTheme.label(text, 18)
	l.custom_minimum_size.x = 230
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = (max_v - min_v) / 100.0
	s.value = value
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size = Vector2(240, 36)
	var val := UiTheme.label("%.2f" % value, 16, UiTheme.TEXT_DIM)
	val.custom_minimum_size.x = 52
	s.value_changed.connect(func(x: float) -> void:
		val.text = "%.2f" % x
		on_change.call(x))
	row.add_child(s)
	row.add_child(val)
	return row


func _check(text: String, value: bool, on_change: Callable) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = value
	c.add_theme_font_size_override("font_size", 18)
	c.toggled.connect(func(on: bool) -> void:
		AudioManager.play_ui("ui_click")
		on_change.call(on))
	return c
