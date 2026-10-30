class_name ClassSelect
extends Control
## THE FOURFOLD THRESHOLD — the story moment where the Dreamer chooses a
## calling. Four Threshold Stones, four trials; the chosen class's avatar
## turns in a small diorama while its lore, kit and abilities are shown.

signal chosen(class_id: String)

const ORDER: PackedStringArray = ["assassin", "spirit", "wizard", "grimlet"]

var _selected: String = "assassin"
var _tabs: Dictionary = {}
var _view_root: Node3D
var _avatar: PlayerAvatar
var _name: Label
var _tagline: Label
var _lore: RichTextLabel
var _details: VBoxContainer
var _confirm: Button
var _overlay: PanelContainer
var _t: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiTheme.get_theme()
	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.0, 0.04, 0.88)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)
	var title := UiTheme.title("The Fourfold Threshold", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var sub := UiTheme.label("Four stones hum in the hollow. Each one is a door, and each door asks a different question. Only one will open for you.", 17, UiTheme.TEXT_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(sub)
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 10)
	col.add_child(tabs)
	for id: String in ORDER:
		var c := Database.player_class(id)
		if c == null:
			continue
		var b := UiTheme.button("%s  %s" % [c.glyph, c.display_name], func() -> void: select(id), 200)
		b.custom_minimum_size.y = 58
		b.add_theme_font_size_override("font_size", 20)
		b.add_theme_color_override("font_color", c.color)
		tabs.add_child(b)
		_tabs[id] = b
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	col.add_child(body)
	# Diorama.
	var vpc := SubViewportContainer.new()
	vpc.stretch = true
	vpc.custom_minimum_size = Vector2(320, 300)
	vpc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vpc.size_flags_stretch_ratio = 0.8
	body.add_child(vpc)
	var vp := SubViewport.new()
	vp.transparent_bg = true
	vp.own_world_3d = true
	vpc.add_child(vp)
	_build_diorama(vp)
	# Info column.
	var info := UiTheme.panel(UiTheme.BG_DEEP, UiTheme.EDGE)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(info)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	info.add_child(scroll)
	var iv := VBoxContainer.new()
	iv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	iv.add_theme_constant_override("separation", 6)
	scroll.add_child(iv)
	_name = UiTheme.title("", 34)
	iv.add_child(_name)
	_tagline = UiTheme.label("", 18, UiTheme.GLOW, UiTheme.bold_font())
	iv.add_child(_tagline)
	_lore = RichTextLabel.new()
	_lore.bbcode_enabled = true
	_lore.fit_content = true
	_lore.scroll_active = false
	_lore.add_theme_font_size_override("normal_font_size", 16)
	_lore.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	iv.add_child(_lore)
	_details = VBoxContainer.new()
	_details.add_theme_constant_override("separation", 4)
	iv.add_child(_details)
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(foot)
	_confirm = UiTheme.button("Undergo the Trial", _on_confirm, 340)
	_confirm.custom_minimum_size.y = 58
	foot.add_child(_confirm)
	select(_selected)


func _build_diorama(vp: SubViewport) -> void:
	_view_root = Node3D.new()
	vp.add_child(_view_root)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.35, 0.3, 0.6)
	e.ambient_light_energy = 0.7
	e.glow_enabled = true
	e.glow_intensity = 0.8
	env.environment = e
	_view_root.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 30, 0)
	key.light_color = Color(0.75, 0.75, 1.0)
	key.light_energy = 0.9
	_view_root.add_child(key)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-1.5, 2.2, -1.5)
	rim.light_color = Color(1.0, 0.7, 0.4)
	rim.light_energy = 2.0
	rim.omni_range = 6.0
	_view_root.add_child(rim)
	# The threshold stone the avatar stands on.
	var kit := MeshKit.new()
	kit.lathe(PackedVector2Array([Vector2(0.9, 0.0), Vector2(1.0, -0.15), Vector2(0.85, -0.3)]), 20, Vector3.ZERO, Basis.IDENTITY,
		func(_t: float, _a: float) -> Color: return Color(0.18, 0.15, 0.3, 0.1), Callable(), true, true)
	var stone := MeshInstance3D.new()
	stone.mesh = kit.commit(MaterialLib.stone())
	_view_root.add_child(stone)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.3, 4.0)
	cam.fov = 40
	_view_root.add_child(cam)
	cam.look_at(Vector3(0, 0.95, 0))


func select(id: String) -> void:
	_selected = id
	var c := Database.player_class(id)
	if c == null:
		return
	for k: String in _tabs.keys():
		(_tabs[k] as Button).modulate = Color.WHITE if k == id else Color(1, 1, 1, 0.55)
	_name.text = "%s  %s" % [c.glyph, c.display_name]
	_name.add_theme_color_override("font_color", c.color)
	_tagline.text = c.tagline
	_lore.text = c.lore + "\n\n[color=#ffd166]Trial:[/color] " + c.trial
	for ch in _details.get_children():
		ch.queue_free()
	_details.add_child(UiTheme.label("Abilities", 20, UiTheme.GOLD, UiTheme.bold_font()))
	for aid: String in c.abilities:
		var a := Database.ability(aid)
		if a:
			_details.add_child(_line("%s  %s" % [a.glyph, a.display_name], a.description + ("  (from level %d)" % a.unlock_level if a.unlock_level > 1 else ""), a.color))
	_details.add_child(UiTheme.label("Starting gear", 20, UiTheme.GOLD, UiTheme.bold_font()))
	for iid: String in c.start_items:
		var d := Database.item(iid)
		if d:
			_details.add_child(_line("%s  %s" % [d.icon_glyph, d.display_name], d.description, d.rarity_color()))
	var stats := PackedStringArray()
	for k: String in c.stat_mods.keys():
		var v := float(c.stat_mods[k])
		stats.append("%s%s %s" % ["+" if v >= 0 else "", str(v), PlayerStats.STAT_NAMES.get(k, k)])
	_details.add_child(UiTheme.label("Nature: " + ", ".join(stats), 15, UiTheme.TEXT_DIM))
	if is_instance_valid(_avatar):
		_avatar.queue_free()
	var eq := {}
	for iid: String in c.start_items:
		var d := Database.item(iid)
		if d and d.equip_slot != "" and not eq.has(d.equip_slot):
			eq[d.equip_slot] = iid
	_avatar = PlayerAvatar.create(c, eq)
	_view_root.add_child(_avatar)
	AudioManager.play_ui("ui_select")


func _line(head: String, text: String, col: Color) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.add_child(UiTheme.label(head, 17, col, UiTheme.bold_font()))
	var l := UiTheme.label(text, 14, UiTheme.TEXT_DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 200
	v.add_child(l)
	return v


func _process(delta: float) -> void:
	_t += delta
	if is_instance_valid(_avatar):
		_avatar.rotation.y = sin(_t * 0.5) * 0.6


func _on_confirm() -> void:
	if is_instance_valid(_overlay):
		return
	var c := Database.player_class(_selected)
	_overlay = UiTheme.panel(UiTheme.BG_DEEP, c.color)
	_overlay.set_anchors_preset(Control.PRESET_CENTER)
	_overlay.offset_left = -330
	_overlay.offset_right = 330
	_overlay.offset_top = -150
	_overlay.offset_bottom = 150
	add_child(_overlay)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	_overlay.add_child(v)
	var t := UiTheme.title("Become a %s?" % c.display_name, 30, c.color)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var l := UiTheme.label("A Threshold, once crossed, stays crossed. The other three callings will see you as a stranger — not always as an enemy.", 17)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	v.add_child(row)
	row.add_child(UiTheme.button("Not yet", func() -> void: _overlay.queue_free(), 180))
	row.add_child(UiTheme.button("Cross the Threshold", func() -> void: _finish(), 260))


func _finish() -> void:
	var id := _selected
	_overlay.queue_free()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.7)
	tw.tween_callback(func() -> void:
		chosen.emit(id)
		queue_free())
