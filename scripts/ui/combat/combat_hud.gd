class_name CombatHUD
extends Control
## Combat interface. Emits `action` dictionaries consumed by CombatManager:
## {type: card|target|cancel|meditate|replace|flee|continue, index?, uid?}

signal action(a: Dictionary)

var state: BattleState
var arena: CombatArena
var _plates: HBoxContainer
var _plate_nodes: Dictionary = {}
var _banner: Label
var _round: Label
var _intro: PanelContainer
var _intro_label: Label
var _hand: HBoxContainer
var _cards: Array[SpellCardView] = []
var _player_hp: ProgressBar
var _player_hp_label: Label
var _player_shield: Label
var _player_status: HBoxContainer
var _mana_row: HBoxContainer
var _mana_label: Label
var _deck_label: Label
var _actions: VBoxContainer
var _meditate_btn: Button
var _swap_btn: Button
var _flee_btn: Button
var _cancel_btn: Button
var _hint: Label
var _log: VBoxContainer
var _target_layer: Control
var _target_row: HBoxContainer
var _targeting: bool = false
var _valid_targets: Array = []
var _pulse: float = 0.0
var _result_panel: PanelContainer
var _hand_enabled: bool = false
var _replace_mode: bool = false
var _selected_index: int = -1


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiTheme.get_theme()
	_target_layer = Control.new()
	_target_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_target_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_target_layer)
	_build_top()
	_build_player()
	_build_hand()
	_build_actions()
	_build_log()
	_intro = UiTheme.panel(Color(0.05, 0.02, 0.1, 0.85), UiTheme.ACCENT)
	_intro.set_anchors_preset(Control.PRESET_CENTER)
	_intro.offset_left = -360
	_intro.offset_right = 360
	_intro.offset_top = -60
	_intro.offset_bottom = 40
	_intro_label = UiTheme.label("", 24, Color.WHITE, UiTheme.title_font())
	_intro_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intro_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_intro.add_child(_intro_label)
	_intro.visible = false
	add_child(_intro)


# ------------------------------------------------------------------ layout
func _build_top() -> void:
	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top.offset_left = -600
	top.offset_right = 600
	top.offset_top = 12
	top.alignment = BoxContainer.ALIGNMENT_BEGIN
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	top.add_child(row)
	_round = UiTheme.label("", 16, UiTheme.TEXT_DIM)
	row.add_child(_round)
	_banner = UiTheme.title("", 30)
	row.add_child(_banner)
	_plates = HBoxContainer.new()
	_plates.alignment = BoxContainer.ALIGNMENT_CENTER
	_plates.add_theme_constant_override("separation", 14)
	top.add_child(_plates)


func _build_player() -> void:
	var panel := UiTheme.panel()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	panel.offset_left = 16
	panel.offset_bottom = -16
	panel.offset_top = -172
	panel.offset_right = 330
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	var name_row := HBoxContainer.new()
	name_row.add_child(UiTheme.label(Game.profile.display_name if Game.profile else "Dreamer", 20, UiTheme.GOLD, UiTheme.title_font()))
	_player_shield = UiTheme.label("", 18, Color(0.5, 0.95, 1.0), UiTheme.bold_font())
	name_row.add_child(_player_shield)
	v.add_child(name_row)
	var hp_row := HBoxContainer.new()
	_player_hp = UiTheme.bar(UiTheme.HEALTH, Vector2(200, 18))
	_player_hp_label = UiTheme.label("", 16)
	hp_row.add_child(_player_hp)
	hp_row.add_child(_player_hp_label)
	v.add_child(hp_row)
	var mana_row := HBoxContainer.new()
	_mana_row = HBoxContainer.new()
	_mana_row.add_theme_constant_override("separation", 3)
	mana_row.add_child(_mana_row)
	_mana_label = UiTheme.label("", 16, UiTheme.MANA, UiTheme.bold_font())
	mana_row.add_child(_mana_label)
	v.add_child(mana_row)
	_player_status = HBoxContainer.new()
	_player_status.add_theme_constant_override("separation", 6)
	v.add_child(_player_status)
	_deck_label = UiTheme.label("", 13, UiTheme.TEXT_DIM)
	v.add_child(_deck_label)


func _build_hand() -> void:
	_hand = HBoxContainer.new()
	_hand.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hand.offset_left = -380
	_hand.offset_right = 380
	_hand.offset_top = -262
	_hand.offset_bottom = -14
	_hand.alignment = BoxContainer.ALIGNMENT_CENTER
	_hand.add_theme_constant_override("separation", 14)
	_hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hand)
	_target_row = HBoxContainer.new()
	_target_row.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_target_row.offset_left = -420
	_target_row.offset_right = 420
	_target_row.offset_top = -150
	_target_row.offset_bottom = -30
	_target_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_target_row.add_theme_constant_override("separation", 18)
	_target_row.visible = false
	add_child(_target_row)
	_hint = UiTheme.label("", 18, UiTheme.GLOW, UiTheme.bold_font())
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_left = -400
	_hint.offset_right = 400
	_hint.offset_top = -300
	_hint.offset_bottom = -270
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_constant_override("outline_size", 6)
	_hint.add_theme_color_override("font_outline_color", Color(0.1, 0.0, 0.2))
	add_child(_hint)


func _build_actions() -> void:
	_actions = VBoxContainer.new()
	_actions.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_actions.offset_left = -228
	_actions.offset_right = -16
	_actions.offset_top = -260
	_actions.offset_bottom = -16
	_actions.alignment = BoxContainer.ALIGNMENT_END
	_actions.add_theme_constant_override("separation", 8)
	add_child(_actions)
	_meditate_btn = UiTheme.button("Meditate  +%d ❖" % BattleState.MEDITATE_MANA, func() -> void: _emit({"type": "meditate"}))
	_meditate_btn.tooltip_text = "Skip casting to restore mana."
	_swap_btn = UiTheme.button("Swap a Card", _toggle_replace)
	_swap_btn.tooltip_text = "Once per turn: discard one card and draw another (free)."
	_flee_btn = UiTheme.button("Flee", func() -> void: _emit({"type": "flee"}))
	_cancel_btn = UiTheme.button("Cancel", func() -> void: _emit({"type": "cancel"}))
	for b: Button in [_cancel_btn, _swap_btn, _meditate_btn, _flee_btn]:
		b.add_theme_font_size_override("font_size", 18)
		_actions.add_child(b)
	_cancel_btn.visible = false


func _build_log() -> void:
	var panel := UiTheme.panel(Color(0.04, 0.01, 0.08, 0.55), Color(0.5, 0.35, 0.9, 0.35))
	panel.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	panel.offset_left = 16
	panel.offset_right = 330
	panel.offset_top = -150
	panel.offset_bottom = 60
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	_log = VBoxContainer.new()
	_log.add_theme_constant_override("separation", 2)
	_log.alignment = BoxContainer.ALIGNMENT_END
	panel.add_child(_log)


# ------------------------------------------------------------------ binding
func setup(s: BattleState, a: CombatArena) -> void:
	state = s
	arena = a
	for c in _plates.get_children():
		c.queue_free()
	_plate_nodes.clear()
	for e: Combatant in s.enemies:
		var plate := _make_plate(e)
		_plates.add_child(plate)
		_plate_nodes[e.uid] = plate
	refresh()


func _make_plate(e: Combatant) -> PanelContainer:
	var p := UiTheme.panel(Color(0.08, 0.02, 0.14, 0.85), ElementChart.color(e.element))
	p.custom_minimum_size.x = 230
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	var uid := e.uid
	p.gui_input.connect(func(ev: InputEvent) -> void:
		if (ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed) or (ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed):
			_emit({"type": "target", "uid": uid}))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glyph := UiTheme.label(ElementChart.glyph(e.element), 18, ElementChart.color(e.element))
	head.add_child(glyph)
	var nm := UiTheme.label("%s  Lv%d" % [e.display_name, e.level], 16, Color.WHITE, UiTheme.bold_font())
	head.add_child(nm)
	v.add_child(head)
	var hp := UiTheme.bar(UiTheme.HEALTH, Vector2(200, 14))
	hp.name = "HP"
	hp.max_value = e.max_hp
	hp.value = e.hp
	v.add_child(hp)
	var info := UiTheme.label("", 13, UiTheme.TEXT_DIM)
	info.name = "Info"
	v.add_child(info)
	var st := HBoxContainer.new()
	st.name = "Status"
	st.add_theme_constant_override("separation", 4)
	v.add_child(st)
	for c in v.get_children():
		if c is Control:
			(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func refresh() -> void:
	if state == null:
		return
	for e: Combatant in state.enemies:
		var plate: PanelContainer = _plate_nodes.get(e.uid)
		if plate == null:
			continue
		var hp: ProgressBar = plate.find_child("HP", true, false)
		create_tween().tween_property(hp, "value", float(e.hp), 0.3)
		var info: Label = plate.find_child("Info", true, false)
		var extra := ""
		if e.shield() > 0:
			extra += "  ◆%d" % e.shield()
		if e.charging:
			extra += "  ⚠ CHARGING %s" % e.charging.display_name.to_upper()
		info.text = "%d / %d%s" % [e.hp, e.max_hp, extra]
		info.add_theme_color_override("font_color", Color(1.0, 0.6, 0.3) if e.charging else UiTheme.TEXT_DIM)
		_fill_status(plate.find_child("Status", true, false) as HBoxContainer, e)
		plate.modulate = Color(1, 1, 1, 1) if e.is_alive() else Color(0.5, 0.5, 0.5, 0.45)
	var p := state.player
	_player_hp.max_value = p.max_hp
	create_tween().tween_property(_player_hp, "value", float(p.hp), 0.3)
	_player_hp_label.text = " %d/%d" % [p.hp, p.max_hp]
	_player_shield.text = ("   ◆ %d" % p.shield()) if p.shield() > 0 else ""
	for c in _mana_row.get_children():
		c.queue_free()
	for i in state.max_mana:
		var pip := UiTheme.label("❖", 20, UiTheme.MANA if i < state.mana else Color(0.3, 0.3, 0.45))
		_mana_row.add_child(pip)
	_mana_label.text = "  %d/%d" % [state.mana, state.max_mana]
	_fill_status(_player_status, p)
	_deck_label.text = "Deck %d · Discard %d" % [state.deck.draw_pile.size(), state.deck.discard.size()]
	_refresh_hand()


func _fill_status(box: HBoxContainer, c: Combatant) -> void:
	for ch in box.get_children():
		ch.queue_free()
	for s: Dictionary in c.status_summary():
		var l := UiTheme.label("%s%d" % [String(s["glyph"]), int(s["remaining"])], 15, s["color"], UiTheme.bold_font())
		l.tooltip_text = "%s (%d turns): %s" % [s["name"], int(s["remaining"]), s["description"]]
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		box.add_child(l)


func _refresh_hand() -> void:
	var hand := state.deck.hand
	while _cards.size() < hand.size():
		var cv := SpellCardView.new(null, _cards.size())
		cv.pressed.connect(_on_card)
		_hand.add_child(cv)
		_cards.append(cv)
	for i in _cards.size():
		var cv := _cards[i]
		if i < hand.size():
			cv.visible = true
			var sp := state.spell(hand[i])
			cv.set_spell(sp, i)
			cv.affordable = sp != null and sp.mana_cost <= state.mana
			cv.interactive = _hand_enabled
			cv.selected = i == _selected_index
		else:
			cv.visible = false


# ------------------------------------------------------------------ interaction
func enable_player_input(on: bool) -> void:
	_hand_enabled = on
	_meditate_btn.disabled = not on
	_swap_btn.disabled = not on or state.replaced_this_turn
	_flee_btn.disabled = not on or (state.encounter and not state.encounter.can_flee)
	_flee_btn.visible = state.encounter == null or state.encounter.can_flee
	if not on:
		_replace_mode = false
		_swap_btn.text = "Swap a Card"
		_hint.text = ""
	else:
		_hint.text = "Choose a spell" if not Settings.uses_touch() else "Tap a spell"
	_refresh_hand()


func _toggle_replace() -> void:
	if state.replaced_this_turn:
		return
	_replace_mode = not _replace_mode
	_swap_btn.text = "Swap: pick a card" if _replace_mode else "Swap a Card"
	_hint.text = "Pick the card to discard" if _replace_mode else "Choose a spell"


func _on_card(index: int) -> void:
	if not _hand_enabled:
		return
	if _replace_mode:
		_replace_mode = false
		_swap_btn.text = "Swap a Card"
		_emit({"type": "replace", "index": index})
		return
	var reason := state.can_cast(index)
	if reason != "":
		show_hint(reason, true)
		AudioManager.play_ui("ui_error")
		return
	AudioManager.play_sfx("card_select", -2.0)
	_emit({"type": "card", "index": index})


func set_selected(index: int) -> void:
	_selected_index = index
	_refresh_hand()


## Target selection: every valid enemy glows, big named buttons replace the
## hand, and enemies can also be tapped directly in the arena or on their plate.
func begin_targeting(valid: Array) -> void:
	_targeting = true
	_valid_targets = valid.duplicate()
	_hint.text = "Choose a target — tap a glowing enemy or a button below"
	_cancel_btn.visible = true
	_meditate_btn.visible = false
	_swap_btn.visible = false
	_flee_btn.visible = false
	_hand.visible = false
	for c in _target_row.get_children():
		c.queue_free()
	for uid: int in valid:
		var e := state.get_combatant(uid)
		var b := UiTheme.button("◎  %s\n%d / %d" % [e.display_name, e.hp, e.max_hp], func() -> void: _emit({"type": "target", "uid": uid}), 250)
		b.custom_minimum_size.y = 96
		b.add_theme_font_size_override("font_size", 22)
		b.add_theme_stylebox_override("normal", UiTheme.button_style("selected"))
		_target_row.add_child(b)
	_target_row.visible = true
	for uid: int in _plate_nodes.keys():
		var plate: PanelContainer = _plate_nodes[uid]
		if uid in valid:
			plate.add_theme_stylebox_override("panel", UiTheme.panel_style(Color(0.25, 0.12, 0.05, 0.92), UiTheme.GOLD, 22, 16))
	arena.show_target_rings(true, valid)
	arena.highlight_targets(valid)


func end_targeting() -> void:
	_targeting = false
	_valid_targets.clear()
	_cancel_btn.visible = false
	_meditate_btn.visible = true
	_swap_btn.visible = true
	_flee_btn.visible = state.encounter == null or state.encounter.can_flee
	_target_row.visible = false
	_hand.visible = true
	for uid: int in _plate_nodes.keys():
		var e := state.get_combatant(uid)
		(_plate_nodes[uid] as PanelContainer).add_theme_stylebox_override("panel", UiTheme.panel_style(Color(0.08, 0.02, 0.14, 0.85), ElementChart.color(e.element)))
	arena.show_target_rings(false)
	arena.highlight_targets([])


func _process(delta: float) -> void:
	if _targeting:
		_pulse += delta
		_target_row.modulate = Color(1, 1, 1, 0.85 + 0.15 * sin(_pulse * 6.0))


## Direct taps on enemies in the 3D arena (works for mouse and touch).
func _try_tap_target(pos: Vector2) -> bool:
	if not _targeting or arena == null:
		return false
	var best := -1
	var best_d := 170.0
	for uid: int in _valid_targets:
		for h: float in [0.6, 1.4]:
			var d := arena.screen_pos(uid, h).distance_to(pos)
			if d < best_d:
				best_d = d
				best = uid
	if best >= 0:
		_emit({"type": "target", "uid": best})
		return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if _targeting:
		var tap := Vector2(-1, -1)
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			tap = (event as InputEventMouseButton).position
		elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
			tap = (event as InputEventScreenTouch).position
		if tap.x >= 0.0 and _try_tap_target(tap):
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).physical_keycode
		if _hand_enabled and k >= KEY_1 and k <= KEY_4:
			_on_card(int(k - KEY_1))
			get_viewport().set_input_as_handled()
		elif k == KEY_ESCAPE and _cancel_btn.visible:
			_emit({"type": "cancel"})
			get_viewport().set_input_as_handled()
		elif (k == KEY_ENTER or k == KEY_SPACE) and _result_panel and _result_panel.visible:
			_emit({"type": "continue"})
			get_viewport().set_input_as_handled()


func _emit(a: Dictionary) -> void:
	action.emit(a)


# ------------------------------------------------------------------ feedback
func set_banner(text: String, color: Color = UiTheme.GOLD) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner.pivot_offset = _banner.size * 0.5
	_banner.scale = Vector2(1.3, 1.3)
	create_tween().tween_property(_banner, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_round.text = "Round %d" % state.round_number if state else ""


func show_hint(text: String, error: bool = false) -> void:
	_hint.text = text
	_hint.add_theme_color_override("font_color", UiTheme.DANGER if error else UiTheme.GLOW)


func log_line(text: String, color: Color = UiTheme.TEXT) -> void:
	var l := UiTheme.label(text, 14, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 290
	_log.add_child(l)
	while _log.get_child_count() > 7:
		var old := _log.get_child(0)
		_log.remove_child(old)
		old.queue_free()


func show_intro(text: String) -> void:
	if text == "":
		return
	_intro_label.text = text
	_intro.visible = true
	_intro.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_intro, "modulate:a", 1.0, 0.3)
	tw.tween_interval(1.8)
	tw.tween_property(_intro, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func() -> void: _intro.visible = false)


## Victory / defeat panel. Resolves when the player presses Continue.
func show_result(victory: bool, summary: Dictionary, level_before: int) -> void:
	enable_player_input(false)
	_hand.visible = false
	_actions.visible = false
	_result_panel = UiTheme.panel(UiTheme.BG_DEEP, UiTheme.GOLD if victory else UiTheme.DANGER)
	_result_panel.set_anchors_preset(Control.PRESET_CENTER)
	_result_panel.offset_left = -300
	_result_panel.offset_right = 300
	_result_panel.offset_top = -170
	_result_panel.offset_bottom = -170
	_result_panel.grow_vertical = Control.GROW_DIRECTION_END
	add_child(_result_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_result_panel.add_child(v)
	var t := UiTheme.title("Victory!" if victory else "The Dream Fades...", 44, UiTheme.GOLD if victory else UiTheme.DANGER)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	if victory:
		v.add_child(_reward_line("✦  +%d experience" % int(summary.get("xp", 0)), UiTheme.XP))
		v.add_child(_reward_line("◈  +%d glimmer" % int(summary.get("glimmer", 0)), UiTheme.GOLD))
		var items: Dictionary = summary.get("items", {})
		for id: String in items.keys():
			var d := Database.item(id)
			v.add_child(_reward_line("%s  %s ×%d" % [d.icon_glyph if d else "•", d.display_name if d else id, int(items[id])], d.rarity_color() if d else UiTheme.TEXT))
		if Game.profile and Game.profile.stats.level > level_before:
			v.add_child(_reward_line("★  LEVEL UP! You are now level %d." % Game.profile.stats.level, UiTheme.ACCENT))
		var xpb := UiTheme.bar(UiTheme.XP, Vector2(520, 14))
		if Game.profile:
			xpb.max_value = Game.profile.stats.xp_to_next()
			xpb.value = 0
			v.add_child(xpb)
			create_tween().tween_property(xpb, "value", float(Game.profile.stats.xp), 1.0).set_trans(Tween.TRANS_QUAD)
	else:
		var l := UiTheme.label("You slip out of the battle and wake in the Awakening Hollow, unharmed but humbled.\nThe creature is still out there.", 18)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 540
		v.add_child(l)
	var b := UiTheme.button("Continue", func() -> void: _emit({"type": "continue"}), 260)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(b)
	b.call_deferred("grab_focus")
	_result_panel.scale = Vector2(0.8, 0.8)
	_result_panel.pivot_offset = Vector2(300, 200)
	create_tween().tween_property(_result_panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _reward_line(text: String, color: Color) -> Label:
	var l := UiTheme.label(text, 20, color, UiTheme.bold_font())
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l
