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
	_build_combat()
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
	resized.connect(_layout_tracker)
	_ignore_non_buttons(self)


## Only real buttons (and the modal lore panel) may take pointer input; every
## decorative panel, label and container lets touches through to the game.
func _ignore_non_buttons(c: Control) -> void:
	for ch in c.get_children():
		if ch == _lore_panel or not ch is Control:
			continue
		if not ch is BaseButton:
			(ch as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignore_non_buttons(ch as Control)


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
		b.add_to_group("hud_button")
		bar.add_child(b)
	var pb := UiTheme.button("☰", func() -> void: pause_button.emit())
	pb.custom_minimum_size = Vector2(52, 48)
	pb.add_to_group("hud_button")
	bar.add_child(pb)


# ------------------------------------------------------------------ tracker
## The tracker is display-only: it never takes input (the Journal button
## opens the quest log). It shows at most the tracked quest's title, current
## objective and progress plus one compact secondary title, is height-capped,
## and is kept clear of every rect the touch controls reserve.
const TRACKER_WIDTH := 330.0
const TRACKER_MAX_HEIGHT := 190.0
const TRACKER_FADE_DELAY := 8.0

var _tracker_objective: Label
var _tracker_progress: Label
var _tracker_second: Label
var _tracker_idle: float = 0.0
## Screen rects (HUD-local) that HUD elements must never cover; supplied by
## TouchControls whenever its layout changes.
var reserved_rects: Array[Rect2] = []


func _build_tracker() -> void:
	_tracker_panel = UiTheme.panel(Color(0.06, 0.02, 0.12, 0.7), Color(0.55, 0.35, 1.0, 0.5))
	_tracker_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_tracker_panel.offset_left = -TRACKER_WIDTH - 20
	_tracker_panel.offset_right = -20
	_tracker_panel.offset_top = 80
	_tracker_panel.offset_bottom = 80
	_tracker_panel.clip_contents = true
	add_child(_tracker_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	_tracker_panel.add_child(v)
	_tracker_title = _tracker_label(19, UiTheme.GOLD, UiTheme.title_font(), 1)
	v.add_child(_tracker_title)
	_tracker_objective = _tracker_label(16, UiTheme.TEXT, null, 2)
	v.add_child(_tracker_objective)
	_tracker_progress = _tracker_label(15, UiTheme.TEXT_DIM, null, 1)
	v.add_child(_tracker_progress)
	_tracker_second = _tracker_label(15, Color("#c9b8ff"), UiTheme.bold_font(), 1)
	v.add_child(_tracker_second)
	_tracker_body = v
	_set_ignore_recursive(_tracker_panel)


func _tracker_label(font_size: int, color: Color, font: Font, lines: int) -> Label:
	var l := UiTheme.label("", font_size, color, font)
	l.custom_minimum_size.x = TRACKER_WIDTH - 28
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if lines > 1 else TextServer.AUTOWRAP_OFF
	l.max_lines_visible = lines
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	# clip_text collapses wrapped labels to zero height; single lines only.
	l.clip_text = lines == 1
	return l


## Labels that trim with an ellipsis report no text height, so reserve one or
## two lines explicitly depending on how long the text is.
func _fit_lines(l: Label, max_lines: int) -> void:
	var f := l.get_theme_font("font")
	var fs := l.get_theme_font_size("font_size")
	var w := f.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var lines := clampi(int(ceil(w / maxf(1.0, l.custom_minimum_size.x - 8.0))), 1, max_lines)
	l.custom_minimum_size.y = (f.get_height(fs) + 2.0) * lines


static func _set_ignore_recursive(c: Control) -> void:
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for ch in c.get_children():
		if ch is Control:
			_set_ignore_recursive(ch as Control)


func refresh_tracker() -> void:
	var p := Game.profile
	if p == null:
		return
	var q := p.quests
	var ids: Array[String] = q.active_quests()
	if q.tracked != "" and q.tracked in ids:
		ids.erase(q.tracked)
		ids.push_front(q.tracked)
	var lines: Array[Dictionary] = []
	for qid: String in ids:
		var data := Database.quest(qid)
		var cur := q.current_objective(qid)
		if data != null and cur != null:
			lines.append({"id": qid, "data": data, "cur": cur})
	_tracker_panel.visible = not lines.is_empty()
	if lines.is_empty():
		return
	var main: Dictionary = lines[0]
	var data: QuestData = main["data"]
	var qid0 := String(main["id"])
	_tracker_title.text = data.title
	var cur: QuestObjectiveData = main["cur"]
	_tracker_objective.text = "◆ " + cur.description
	_tracker_objective.visible = true
	_fit_lines(_tracker_objective, 2)
	var prog := ""
	if cur.required_amount > 1:
		prog = "%d / %d" % [q.get_progress(qid0, cur.id), cur.required_amount]
	if not data.sequential or data.objectives.size() > 1:
		var done := 0
		for o: QuestObjectiveData in data.objectives:
			if q.is_objective_done(qid0, o.id):
				done += 1
		prog += ("   ·   " if prog != "" else "") + "step %d of %d" % [mini(done + 1, data.objectives.size()), data.objectives.size()]
	_tracker_progress.text = prog
	_tracker_progress.visible = prog != ""
	_tracker_second.visible = lines.size() > 1
	if lines.size() > 1:
		_tracker_second.text = "◇ " + (lines[1]["data"] as QuestData).title + ("  +%d" % (lines.size() - 2) if lines.size() > 2 else "")
	_tracker_idle = 0.0
	_tracker_panel.modulate.a = 1.0
	_layout_tracker()


## Caps the tracker height and keeps it clear of reserved touch areas.
func _layout_tracker() -> void:
	if _tracker_panel == null:
		return
	_tracker_panel.reset_size()
	var want := minf(_tracker_panel.get_combined_minimum_size().y, TRACKER_MAX_HEIGHT)
	var top := _tracker_panel.offset_top
	var x0 := size.x + _tracker_panel.offset_left
	var limit := minf(TRACKER_MAX_HEIGHT, size.y * 0.3)
	for r: Rect2 in reserved_rects:
		if r.position.x + r.size.x > x0 and r.position.x < size.x:
			limit = minf(limit, r.position.y - 12.0 - top)
	# Degrade gracefully on short screens: drop the secondary quest, then
	# squeeze the objective to one line, then the progress line, then the
	# objective (the title always stays).
	var steps: Array[Callable] = [
		func() -> void: _tracker_second.visible = false,
		func() -> void: _fit_lines(_tracker_objective, 1),
		func() -> void: _tracker_progress.visible = false,
		func() -> void: _tracker_objective.visible = false,
	]
	for step in steps:
		if want <= limit:
			break
		step.call()
		_tracker_panel.reset_size()
		want = minf(_tracker_panel.get_combined_minimum_size().y, TRACKER_MAX_HEIGHT)
	_tracker_panel.offset_bottom = top + clampf(minf(want, limit), 0.0, TRACKER_MAX_HEIGHT)
	_tracker_panel.visible = _tracker_panel.visible and limit > 40.0


func tracker_rect() -> Rect2:
	return _tracker_panel.get_global_rect() if _tracker_panel.visible else Rect2()


func set_reserved_rects(rects: Array[Rect2]) -> void:
	reserved_rects = rects
	_layout_tracker()


func _objective_line(qid: String, o: QuestObjectiveData) -> String:
	var prog := ""
	if o.required_amount > 1:
		prog = "  (%d/%d)" % [Game.profile.quests.get_progress(qid, o.id), o.required_amount]
	return "◆ %s%s" % [o.description, prog]


# ------------------------------------------------------------------ combat
var _stamina_bar: ProgressBar
var _boss_panel: PanelContainer
var _boss_name: Label
var _boss_bar: ProgressBar
var _ability_bar: HBoxContainer
var _vignette: ColorRect
var _status_label: Label
var _boss: WorldCreature


func _build_combat() -> void:
	# Stamina under the vitals.
	_stamina_bar = UiTheme.bar(Color(1.0, 0.85, 0.35), Vector2(210, 6))
	_stamina_bar.position = Vector2(108, 134)
	_stamina_bar.size = Vector2(210, 6)
	add_child(_stamina_bar)
	_status_label = UiTheme.label("", 15, UiTheme.GLOW, UiTheme.bold_font())
	_status_label.position = Vector2(108, 142)
	add_child(_status_label)
	# Boss bar, top centre.
	_boss_panel = UiTheme.panel(Color(0.08, 0.0, 0.05, 0.8), Color(1.0, 0.4, 0.3, 0.8))
	_boss_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_boss_panel.offset_left = -260
	_boss_panel.offset_right = 260
	_boss_panel.offset_top = 12
	_boss_panel.visible = false
	add_child(_boss_panel)
	var bv := VBoxContainer.new()
	_boss_panel.add_child(bv)
	_boss_name = UiTheme.label("", 18, Color(1.0, 0.75, 0.6), UiTheme.title_font())
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(_boss_name)
	_boss_bar = UiTheme.bar(Color(1.0, 0.3, 0.35), Vector2(490, 14))
	bv.add_child(_boss_bar)
	# PC ability bar (touch players use the on-screen ability buttons).
	_ability_bar = HBoxContainer.new()
	_ability_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_ability_bar.offset_left = -230
	_ability_bar.offset_right = 230
	_ability_bar.offset_top = -86
	_ability_bar.offset_bottom = -16
	_ability_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_ability_bar.add_theme_constant_override("separation", 10)
	add_child(_ability_bar)
	for i in 5:
		_ability_bar.add_child(AbilitySlot.new(i))
	# Red edge flash when hurt.
	_vignette = ColorRect.new()
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.color = Color(0.8, 0.0, 0.1, 0.0)
	add_child(_vignette)
	EventBus.player_hit.connect(func(amount: float, blocked: bool) -> void:
		if amount <= 0.0:
			return
		_vignette.color.a = 0.08 if blocked else 0.28
		create_tween().tween_property(_vignette, "color:a", 0.0, 0.45))
	EventBus.rt_enemy_aggro.connect(func(e: Node) -> void:
		var wc := e as WorldCreature
		if wc and (wc.is_boss() or bool(wc.profile.get("elite", false))):
			_boss = wc)


func _update_combat() -> void:
	var p := get_tree().get_first_node_in_group("player")
	var pc: PlayerCombat = p.get("combat") if p else null
	_ability_bar.visible = not touch_mode and Game.profile != null and Game.profile.class_id != ""
	if pc == null:
		_stamina_bar.visible = false
		return
	_stamina_bar.max_value = pc.max_stamina
	_stamina_bar.value = pc.stamina
	_stamina_bar.visible = pc.stamina < pc.max_stamina - 0.5 or pc.combat_mode
	var st := PackedStringArray()
	for b: String in pc.buffs.keys():
		st.append(b.capitalize())
	if pc.shield_hp > 0.0:
		st.append("Shield %d" % int(pc.shield_hp))
	if pc.draw >= 0.0:
		st.append(String(PlayerCombat.ARROW_TYPES[pc.arrow_type]["name"]))
	if is_instance_valid(pc.lock_target):
		st.append("◎ " + String((pc.lock_target as WorldCreature).data.display_name if pc.lock_target is WorldCreature else "target"))
	_status_label.text = "  ".join(st)
	if is_instance_valid(_boss) and not _boss.dead and _boss.aware:
		_boss_panel.visible = true
		_boss_name.text = _boss.data.display_name + ("   ◆ %d" % int(_boss.shield_hp) if _boss.shield_hp > 0.0 else "")
		_boss_bar.max_value = _boss.max_hp
		_boss_bar.value = _boss.hp
	else:
		_boss_panel.visible = false
	for c in _ability_bar.get_children():
		(c as AbilitySlot).refresh(pc)


## One PC hotbar slot: glyph, key number and a cooldown overlay.
class AbilitySlot extends Control:
	var index: int
	var _ability: AbilityData
	var _cd: float = 0.0
	var _usable: bool = true

	func _init(i: int) -> void:
		index = i
		custom_minimum_size = Vector2(64, 64)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func refresh(pc: PlayerCombat) -> void:
		var list := Game.profile.usable_abilities() if Game.profile else ([] as Array[AbilityData])
		_ability = list[index] if index < list.size() else null
		_cd = pc.cooldown_ratio(_ability) if _ability else 0.0
		_usable = _ability != null and Game.profile.stats.mana >= _ability.mana_cost
		tooltip_text = (_ability.display_name + " — " + _ability.description) if _ability else ""
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 2.0
		if _ability == null:
			draw_arc(c, r, 0, TAU, 32, Color(1, 1, 1, 0.15), 2.0, true)
			return
		var col := _ability.color
		draw_circle(c, r, Color(col.r * 0.35, col.g * 0.35, col.b * 0.35, 0.85))
		draw_arc(c, r, 0, TAU, 32, Color(col, 0.9), 2.5, true)
		var f := UiTheme.bold_font()
		var ts := f.get_string_size(_ability.glyph, HORIZONTAL_ALIGNMENT_CENTER, -1, 28)
		draw_string(f, c - Vector2(ts.x * 0.5, -10), _ability.glyph, HORIZONTAL_ALIGNMENT_CENTER, -1, 28, Color.WHITE if _usable else Color(0.6, 0.6, 0.8))
		if _cd > 0.0:
			draw_arc(c, r * 0.5, -PI * 0.5, -PI * 0.5 + TAU * _cd, 32, Color(0, 0, 0, 0.65), r, true)
		draw_string(f, Vector2(4, 16), str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UiTheme.GOLD)
		draw_string(f, Vector2(size.x - 18, size.y - 4), "%d" % int(_ability.mana_cost), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UiTheme.MANA)


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


func _process(delta: float) -> void:
	_update_combat()
	# Auto-dim the tracker when nothing changes; it brightens again on updates.
	_tracker_idle += delta
	if _tracker_panel and _tracker_idle > TRACKER_FADE_DELAY:
		_tracker_panel.modulate.a = move_toward(_tracker_panel.modulate.a, 0.45, delta)
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
