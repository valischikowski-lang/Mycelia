class_name HUD
extends Control
## Exploration HUD: vitals, quest tracker, crosshair, interaction prompt,
## toasts, discovery banners, lore popups and quick-menu buttons.

signal menu_button(tab: String)
signal pause_button()
signal lore_closed()

var _hp_bar: ProgressBar
var _mp_bar: ProgressBar
var _xp_bar: ProgressBar
var _hp_label: Label
var _mp_label: Label
var _level_label: Label
var _glimmer_label: Label
var _tracker_title: Label
var _tracker_body: VBoxContainer
var _tracker_panel: PanelContainer
var _crosshair: Crosshair
var _prompt_panel: PanelContainer
var _prompt_label: Label
var _toasts: VBoxContainer
var _banner: Control
var _banner_title: Label
var _banner_sub: Label
var _lore_panel: PanelContainer
var _lore_title: Label
var _lore_text: RichTextLabel
var _fps_label: Label
var _region_label: Label
var touch_mode: bool = false


func _ready() -> void:
	add_to_group("hud")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiTheme.get_theme()
	_build_vitals()
	_build_buttons()
	_build_tracker()
	_build_center()
	_build_toasts()
	_build_banner()
	_build_lore()
	_fps_label = UiTheme.label("", 16, UiTheme.SUCCESS)
	_fps_label.position = Vector2(24, 0)
	_fps_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_fps_label.offset_top = -30
	_fps_label.offset_bottom = -8
	_fps_label.offset_left = 24
	add_child(_fps_label)
	EventBus.stats_changed.connect(refresh_vitals)
	EventBus.currency_changed.connect(func(_a: int) -> void: refresh_vitals())
	EventBus.quest_tracker_changed.connect(refresh_tracker)
	EventBus.interaction_target_changed.connect(_on_target)
	EventBus.notification_requested.connect(toast)
	EventBus.level_up.connect(func(_l: int) -> void: refresh_vitals())
	refresh_vitals()
	refresh_tracker()
	_on_target("", false)


# ------------------------------------------------------------------ vitals
func _build_vitals() -> void:
	var panel := UiTheme.panel()
	panel.position = Vector2(20, 18)
	add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	var badge := PanelContainer.new()
	var bs := UiTheme.panel_style(Color(0.25, 0.08, 0.4, 0.95), UiTheme.GOLD, 30, 8)
	bs.content_margin_left = 12
	bs.content_margin_right = 12
	badge.add_theme_stylebox_override("panel", bs)
	badge.custom_minimum_size = Vector2(62, 62)
	_level_label = UiTheme.title("1", 30)
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(_level_label)
	row.add_child(badge)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	row.add_child(col)
	var hp_row := HBoxContainer.new()
	_hp_bar = UiTheme.bar(UiTheme.HEALTH, Vector2(210, 16))
	_hp_label = UiTheme.label("", 15)
	_hp_label.custom_minimum_size.x = 70
	hp_row.add_child(UiTheme.label("♥", 16, UiTheme.HEALTH))
	hp_row.add_child(_hp_bar)
	hp_row.add_child(_hp_label)
	col.add_child(hp_row)
	var mp_row := HBoxContainer.new()
	_mp_bar = UiTheme.bar(UiTheme.MANA, Vector2(210, 16))
	_mp_label = UiTheme.label("", 15)
	_mp_label.custom_minimum_size.x = 70
	mp_row.add_child(UiTheme.label("❖", 16, UiTheme.MANA))
	mp_row.add_child(_mp_bar)
	mp_row.add_child(_mp_label)
	col.add_child(mp_row)
	var xp_row := HBoxContainer.new()
	_xp_bar = UiTheme.bar(UiTheme.XP, Vector2(210, 8))
	_glimmer_label = UiTheme.label("", 15, UiTheme.GOLD)
	xp_row.add_child(UiTheme.label("✦", 14, UiTheme.XP))
	xp_row.add_child(_xp_bar)
	xp_row.add_child(_glimmer_label)
	col.add_child(xp_row)
	_region_label = UiTheme.label("", 14, UiTheme.TEXT_DIM)
	col.add_child(_region_label)


func set_region_name(n: String) -> void:
	_region_label.text = n


func refresh_vitals() -> void:
	var p := Game.profile
	if p == null:
		return
	var s := p.stats
	_level_label.text = str(s.level)
	_hp_bar.max_value = s.max_health()
	_hp_bar.value = s.health
	_hp_label.text = "%d/%d" % [int(s.health), s.max_health()]
	_mp_bar.max_value = s.max_mana()
	_mp_bar.value = s.mana
	_mp_label.text = "%d/%d" % [int(s.mana), s.max_mana()]
	_xp_bar.max_value = s.xp_to_next()
	_xp_bar.value = s.xp
	_glimmer_label.text = "  ◈ %d" % p.inventory.glimmer


# ------------------------------------------------------------------ buttons
func _build_buttons() -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	bar.offset_left = -470
	bar.offset_right = -20
	bar.offset_top = 18
	bar.alignment = BoxContainer.ALIGNMENT_END
	bar.add_theme_constant_override("separation", 8)
	add_child(bar)
	var entries := [["✧ Grimoire", "inventory"], ["☾ Map", "map"], ["✎ Journal", "journal"]]
	for e: Array in entries:
		var tab := String(e[1])
		var b := UiTheme.button(String(e[0]), func() -> void: menu_button.emit(tab))
		b.custom_minimum_size = Vector2(0, 48)
		b.add_theme_font_size_override("font_size", 17)
		bar.add_child(b)
	var pb := UiTheme.button("☰", func() -> void: pause_button.emit())
	pb.custom_minimum_size = Vector2(52, 48)
	bar.add_child(pb)


# ------------------------------------------------------------------ tracker
func _build_tracker() -> void:
	_tracker_panel = UiTheme.panel(Color(0.06, 0.02, 0.12, 0.7), Color(0.55, 0.35, 1.0, 0.5))
	_tracker_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_tracker_panel.offset_left = -380
	_tracker_panel.offset_right = -20
	_tracker_panel.offset_top = 80
	_tracker_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_tracker_panel.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			menu_button.emit("journal"))
	add_child(_tracker_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	_tracker_panel.add_child(v)
	_tracker_title = UiTheme.label("", 19, UiTheme.GOLD, UiTheme.title_font())
	_tracker_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_tracker_title)
	_tracker_body = VBoxContainer.new()
	_tracker_body.add_theme_constant_override("separation", 2)
	_tracker_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_tracker_body)


func refresh_tracker() -> void:
	var p := Game.profile
	if p == null:
		return
	var q := p.quests
	for c in _tracker_body.get_children():
		c.queue_free()
	var shown := 0
	var main_title := ""
	var ids: Array[String] = q.active_quests()
	if q.tracked != "" and q.tracked in ids:
		ids.erase(q.tracked)
		ids.push_front(q.tracked)
	for qid: String in ids:
		if shown >= 2:
			break
		var data := Database.quest(qid)
		var cur := q.current_objective(qid)
		if data == null or cur == null:
			continue
		if shown == 0:
			main_title = data.title
		else:
			_tracker_line(data.title, 17, Color("#c9b8ff"), UiTheme.bold_font())
		if data.sequential:
			_tracker_line(_objective_line(qid, cur), 16, UiTheme.TEXT)
		else:
			var remaining := 0
			for o: QuestObjectiveData in data.objectives:
				if not q.is_objective_done(qid, o.id):
					remaining += 1
			_tracker_line("◇ %d of %d remaining" % [remaining, data.objectives.size()], 16, UiTheme.TEXT_DIM)
		shown += 1
	_tracker_panel.visible = shown > 0
	_tracker_title.text = main_title
	_tracker_panel.reset_size()


func _tracker_line(text: String, size: int, color: Color, font: Font = null) -> void:
	var l := UiTheme.label(text, size, color, font)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 320
	_tracker_body.add_child(l)


func _objective_line(qid: String, o: QuestObjectiveData) -> String:
	var prog := ""
	if o.required_amount > 1:
		prog = "  (%d/%d)" % [Game.profile.quests.get_progress(qid, o.id), o.required_amount]
	return "◆ %s%s" % [o.description, prog]


# ------------------------------------------------------------------ center
func _build_center() -> void:
	_crosshair = Crosshair.new()
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair.custom_minimum_size = Vector2(40, 40)
	_crosshair.position = Vector2(-20, -20)
	_crosshair.size = Vector2(40, 40)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_crosshair)
	_prompt_panel = UiTheme.panel(Color(0.08, 0.03, 0.16, 0.85), UiTheme.GLOW)
	_prompt_panel.set_anchors_preset(Control.PRESET_CENTER)
	_prompt_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt_panel.offset_top = 46
	_prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_prompt_panel)
	_prompt_label = UiTheme.label("", 20, Color.WHITE, UiTheme.bold_font())
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_panel.add_child(_prompt_label)


func _on_target(prompt: String, has_target: bool) -> void:
	_crosshair.active = has_target
	_prompt_panel.visible = has_target
	if has_target:
		var key := "Tap ✋" if touch_mode else "[%s]" % InputConfig.key_name("interact")
		_prompt_label.text = "%s  %s" % [key, prompt]
		await get_tree().process_frame
		_prompt_panel.reset_size()
		_prompt_panel.offset_left = -_prompt_panel.size.x * 0.5
		_prompt_panel.offset_right = _prompt_panel.size.x * 0.5


func set_crosshair_visible(v: bool) -> void:
	_crosshair.visible = v


# ------------------------------------------------------------------ toasts
func _build_toasts() -> void:
	_toasts = VBoxContainer.new()
	_toasts.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toasts.offset_top = 130
	_toasts.offset_left = -300
	_toasts.offset_right = 300
	_toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	_toasts.add_theme_constant_override("separation", 6)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toasts)


func toast(text: String, kind: String = "info") -> void:
	var colors := {
		"info": UiTheme.TEXT, "item": UiTheme.GLOW, "quest": UiTheme.GOLD, "quest_complete": UiTheme.GOLD,
		"objective": UiTheme.SUCCESS, "level": UiTheme.ACCENT, "spell": Color(0.8, 0.6, 1.0), "warning": Color(1.0, 0.7, 0.4),
		"error": UiTheme.DANGER, "lore": Color(0.75, 0.85, 1.0), "success": UiTheme.SUCCESS, "save": UiTheme.TEXT_DIM,
	}
	var col: Color = colors.get(kind, UiTheme.TEXT)
	var p := UiTheme.panel(Color(0.06, 0.02, 0.12, 0.8), Color(col, 0.7))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UiTheme.label(text, 18 if kind != "quest_complete" and kind != "level" else 21, col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 420
	p.add_child(l)
	p.modulate.a = 0.0
	_toasts.add_child(p)
	while _toasts.get_child_count() > 5:
		_toasts.get_child(0).queue_free()
		_toasts.remove_child(_toasts.get_child(0))
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.25)
	tw.tween_interval(3.2 if kind != "quest_complete" else 5.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.6)
	tw.tween_callback(p.queue_free)


# ------------------------------------------------------------------ banner
func _build_banner() -> void:
	_banner = VBoxContainer.new()
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_top = 210
	_banner.offset_left = -400
	_banner.offset_right = 400
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.modulate.a = 0.0
	add_child(_banner)
	_banner_sub = UiTheme.label("— Discovered —", 20, UiTheme.GLOW)
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_child(_banner_sub)
	_banner_title = UiTheme.title("", 48)
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_child(_banner_title)


func show_discovery(area_name: String) -> void:
	show_banner(area_name, "— Discovered —")


func show_banner(title: String, sub: String) -> void:
	_banner_title.text = title
	_banner_sub.text = sub
	var tw := create_tween()
	_banner.scale = Vector2.ONE
	tw.tween_property(_banner, "modulate:a", 1.0, 0.6)
	tw.tween_interval(2.6)
	tw.tween_property(_banner, "modulate:a", 0.0, 1.0)


# ------------------------------------------------------------------ lore popup
func _build_lore() -> void:
	_lore_panel = UiTheme.panel(UiTheme.BG_DEEP, UiTheme.GOLD)
	_lore_panel.set_anchors_preset(Control.PRESET_CENTER)
	_lore_panel.offset_left = -330
	_lore_panel.offset_right = 330
	_lore_panel.offset_top = -200
	_lore_panel.offset_bottom = 200
	_lore_panel.visible = false
	add_child(_lore_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	_lore_panel.add_child(v)
	_lore_title = UiTheme.title("", 30)
	_lore_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lore_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_lore_title)
	_lore_text = RichTextLabel.new()
	_lore_text.bbcode_enabled = true
	_lore_text.custom_minimum_size = Vector2(600, 220)
	_lore_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lore_text.add_theme_font_size_override("normal_font_size", 19)
	v.add_child(_lore_text)
	var close := UiTheme.button("Close", hide_lore, 200)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(close)


func show_lore(title: String, text: String) -> void:
	_lore_title.text = title
	_lore_text.text = text
	_lore_panel.visible = true
	_lore_panel.modulate.a = 0.0
	create_tween().tween_property(_lore_panel, "modulate:a", 1.0, 0.25)
	get_tree().call_group("game_root", "open_modal", "lore")
	AudioManager.play_ui("ui_open")


func hide_lore() -> void:
	if not _lore_panel.visible:
		return
	_lore_panel.visible = false
	get_tree().call_group("game_root", "close_modal", "lore")
	lore_closed.emit()


func is_lore_open() -> bool:
	return _lore_panel.visible


func _process(_delta: float) -> void:
	_fps_label.visible = Settings.show_fps
	if Settings.show_fps:
		_fps_label.text = "%d FPS · %d draws · %d objs · %.0f MB" % [
			Engine.get_frames_per_second(),
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0]


## Small animated crosshair that blooms when something is interactable.
class Crosshair extends Control:
	var active: bool = false:
		set(v):
			active = v
			queue_redraw()
	var _t: float = 0.0

	func _process(delta: float) -> void:
		_t += delta
		if active:
			queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		if active:
			var r := 11.0 + sin(_t * 6.0) * 1.5
			draw_arc(c, r, 0, TAU, 32, Color(0.4, 1.0, 0.95, 0.9), 2.0, true)
			draw_circle(c, 3.0, Color(1.0, 0.9, 0.5))
		else:
			draw_circle(c, 2.5, Color(1, 1, 1, 0.75))
			draw_arc(c, 6.0, 0, TAU, 24, Color(1, 1, 1, 0.25), 1.0, true)
