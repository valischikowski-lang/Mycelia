extends Node
## Main menu: a living diorama of the meadow behind a glowing title.

const TITLE_SHADER := preload("res://shaders/title_shimmer.gdshader")

var _camera: Camera3D
var _t: float = 0.0
var _ui: Control
var _menu: VBoxContainer
var _settings: SettingsPanel
var _credits: PanelContainer
var _confirm: PanelContainer
var _continue_btn: Button


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_diorama()
	_build_ui()
	AudioManager.play_music("music_menu")
	AudioManager.play_ambience("meadow_ambience")
	Settings.apply_to_viewport(get_viewport())


func _build_diorama() -> void:
	var region := Region.new()
	region.biome_id = "dreaming_meadow"
	add_child(region)
	await region.build()
	var biome := region.biome
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# Ground: a floating disc island the title "sits" on.
	var isl := IslandGenerator.build(rng, biome, 22.0, 16.0, {"waterfall": true, "fall_height": 30.0, "roots": 14})
	var imi := MeshInstance3D.new()
	imi.mesh = isl["mesh"]
	region.add_child(imi)
	var wf := MeshInstance3D.new()
	wf.mesh = isl["waterfall_mesh"]
	region.add_child(wf)
	var kit := MeshKit.new()
	for i in 14:
		var cls := "giant" if i < 2 else ("twisted" if i < 5 else "medium")
		var p := MushroomGenerator.random_params(rng, biome, cls)
		if cls == "giant":
			p.stem_height *= 0.6
			p.cap_radius *= 0.6
			p.cap_height *= 0.6
			p.stem_width *= 0.6
		var a := rng.randf() * TAU
		var d := rng.randf_range(2.0, 17.0) if cls != "giant" else rng.randf_range(8.0, 14.0)
		MushroomGenerator.build_into(kit, p, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(cos(a) * d, 0.2, sin(a) * d)))
	var mmi := MeshInstance3D.new()
	mmi.mesh = kit.commit(MaterialLib.mushroom_breathing())
	region.add_child(mmi)
	for i in 3:
		var tr := TreeGenerator.build(rng, biome, rng.randf_range(7, 11), 0.5)
		var tmi := MeshInstance3D.new()
		tmi.mesh = tr["mesh"]
		var a := rng.randf() * TAU
		tmi.position = Vector3(cos(a) * 12.0, 0.0, sin(a) * 12.0)
		region.add_child(tmi)
	for i in 10:
		var f := FlowerGenerator.build(rng, biome, rng.randf_range(1.0, 2.4), rng.randf_range(0.5, 1.0))
		var a := rng.randf() * TAU
		f.position = Vector3(cos(a), 0, sin(a)) * rng.randf_range(3.0, 16.0)
		region.add_child(f)
	for i in 5:
		var fi := MeadowLandmarks.floating_island(region, Vector3(rng.randf_range(-60, 60), rng.randf_range(10, 35), rng.randf_range(-70, -20)), rng.randf_range(4, 9), 5.0, {"bob": 1.0, "orbit": 3.0})
		fi.name = "MenuIsland%d" % i
	var keeper := CreatureBuilder.build("keeper")
	keeper.position = Vector3(3.0, 0.2, 6.0)
	keeper.rotation.y = 0.6
	region.add_child(keeper)
	var crone := CreatureBuilder.build("witch", Color.WHITE, {"seed": 7})
	crone.position = Vector3(-3.5, 0.2, 5.0)
	crone.rotation.y = -0.4
	region.add_child(crone)
	for i in 3:
		var dr := CreatureBuilder.build("sky_drifter", Color.WHITE, {"seed": i})
		dr.position = Vector3(rng.randf_range(-25, 25), rng.randf_range(10, 22), rng.randf_range(-30, 0))
		dr.scale = Vector3.ONE * 1.6
		region.add_child(dr)
	var motes := SpellFX.ambient_motes(Color(0.7, 1.0, 0.7), 120, Vector3(25, 8, 25), 0.12)
	motes.position = Vector3(0, 6, 0)
	region.add_child(motes)
	_camera = Camera3D.new()
	_camera.fov = 62
	region.add_child(_camera)
	_camera.current = true


func _process(delta: float) -> void:
	_t += delta
	if _camera:
		var a := _t * 0.05 + 0.6
		_camera.position = Vector3(sin(a) * 30.0, 9.0 + sin(_t * 0.2) * 1.5, cos(a) * 30.0)
		_camera.look_at(Vector3(0, 6.0, 0))
		DreamFlower.focus_point = _camera.position


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_ui = Control.new()
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.theme = UiTheme.get_theme()
	layer.add_child(_ui)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grad := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.03, 0.0, 0.08, 0.75))
	g.set_color(1, Color(0.03, 0.0, 0.08, 0.0))
	grad.gradient = g
	grad.fill_from = Vector2(0, 0)
	grad.fill_to = Vector2(0.6, 0)
	var tr := TextureRect.new()
	tr.texture = grad
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(tr)
	var left := VBoxContainer.new()
	left.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	left.offset_left = 70
	left.offset_right = 640
	left.offset_top = 70
	left.add_theme_constant_override("separation", 6)
	_ui.add_child(left)
	var title := UiTheme.title("MYCELIA", 104)
	var tm := ShaderMaterial.new()
	tm.shader = TITLE_SHADER
	tm.set_shader_parameter("width", 520.0)
	# Dark fantasy: sickly green, bruise violet and lantern amber.
	tm.set_shader_parameter("color_a", Color("#7dff8a"))
	tm.set_shader_parameter("color_b", Color("#8a4dff"))
	tm.set_shader_parameter("color_c", Color("#ffb347"))
	title.material = tm
	left.add_child(title)
	var sub := UiTheme.label("— THE DREAMING REALMS —", 24, UiTheme.TEXT_DIM, UiTheme.bold_font())
	left.add_child(sub)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 40
	left.add_child(spacer)
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 12)
	left.add_child(_menu)
	var has_save := SaveManager.has_any_save()
	_continue_btn = UiTheme.button("Continue", func() -> void: SceneFlow.continue_game(), 340)
	_continue_btn.disabled = not has_save
	_menu.add_child(UiTheme.button("New Game", _on_new_game, 340))
	_menu.add_child(_continue_btn)
	_menu.add_child(UiTheme.button("Settings", func() -> void: _show_panel(_settings), 340))
	_menu.add_child(UiTheme.button("Credits", func() -> void: _show_panel(_credits), 340))
	if not OS.has_feature("mobile") and not OS.has_feature("web"):
		_menu.add_child(UiTheme.button("Exit", func() -> void: get_tree().quit(), 340))
	for b in _menu.get_children():
		(b as Button).add_theme_font_size_override("font_size", 24)
		(b as Button).custom_minimum_size.y = 60
	(_continue_btn if has_save else _menu.get_child(0) as Button).call_deferred("grab_focus")
	var ver := UiTheme.label("v%s · Godot %s" % [ProjectSettings.get_setting("application/config/version", "0.1"), Engine.get_version_info()["string"]], 14, UiTheme.TEXT_DIM)
	ver.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.offset_left = -360
	ver.offset_top = -36
	ver.offset_right = -20
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ui.add_child(ver)
	# Panels.
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(center)
	_settings = SettingsPanel.new()
	_settings.visible = false
	_settings.close_requested.connect(func() -> void: _show_panel(null))
	center.add_child(_settings)
	_credits = _build_credits()
	center.add_child(_credits)
	_confirm = _build_confirm()
	center.add_child(_confirm)


func _show_panel(p: Control) -> void:
	for c: Control in [_settings, _credits, _confirm]:
		c.visible = c == p
	_menu.visible = p == null
	AudioManager.play_ui("ui_open" if p else "ui_close")


func _on_new_game() -> void:
	if SaveManager.has_any_save():
		_show_panel(_confirm)
	else:
		SceneFlow.start_new_game()


func _build_confirm() -> PanelContainer:
	var p := UiTheme.panel(UiTheme.BG_DEEP, UiTheme.GOLD)
	p.visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	p.add_child(v)
	v.add_child(UiTheme.title("Begin a new dream?", 30))
	var l := UiTheme.label("Your autosave will be replaced when the new journey saves.\nManual save slots are kept.", 18)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 480
	v.add_child(l)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(UiTheme.button("Begin", func() -> void: SceneFlow.start_new_game(), 200))
	row.add_child(UiTheme.button("Back", func() -> void: _show_panel(null), 200))
	v.add_child(row)
	return p


func _build_credits() -> PanelContainer:
	var p := UiTheme.panel(UiTheme.BG_DEEP, UiTheme.EDGE)
	p.visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	v.add_child(UiTheme.title("Credits", 34))
	var txt := RichTextLabel.new()
	txt.bbcode_enabled = true
	txt.fit_content = true
	txt.custom_minimum_size = Vector2(560, 0)
	txt.text = "[b]MYCELIA — The Dreaming Realms[/b]\nAn original world built with the Godot Engine.\n\n" + \
		"All 3D models, materials, shaders, music and sound effects are generated procedurally by the project's own code.\n\n" + \
		"Fonts: [i]Inter[/i] (SIL Open Font License 1.1) and [i]Caladea[/i] (SIL Open Font License 1.1).\n" + \
		"Engine: Godot Engine (MIT License) — godotengine.org\n\n" + \
		"Thank you for dreaming with us."
	v.add_child(txt)
	var b := UiTheme.button("Back", func() -> void: _show_panel(null), 200)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(b)
	return p
