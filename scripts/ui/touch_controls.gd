class_name TouchControls
extends Control
## Multi-touch mobile controls. Left zone: floating virtual joystick.
## Right zone: camera look drag. Buttons are hit-tested here (not via GUI
## nodes) so several fingers work at once and never fight each other.

const LOOK_DEG_PER_SCREEN := 220.0
const JOY_RADIUS := 90.0
const DEAD_ZONE := 0.12

var _joy_index: int = -1
var _joy_origin: Vector2
var _joy_pos: Vector2
var _look_index: int = -1
var _look_last: Vector2
var _buttons: Dictionary = {}
var _pressed: Dictionary = {}
var _sprint_toggle: bool = false
var interact_available: bool = false
## Touch indices currently owned by these controls (joystick, look, buttons).
var _owned: Dictionary = {}

signal reserved_changed(rects: Array[Rect2])


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	EventBus.interaction_target_changed.connect(func(_p: String, has: bool) -> void:
		interact_available = has
		queue_redraw())
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	var s := size
	var unit := clampf(minf(s.x, s.y) / 720.0, 0.7, 1.6)
	var br := func(x: float, y: float) -> Vector2: return Vector2(s.x - x * unit, s.y - y * unit)
	_buttons = {
		"attack": {"pos": br.call(120, 135), "r": 64 * unit, "label": "⚔", "hold": true},
		"jump": {"pos": br.call(245, 68), "r": 44 * unit, "label": "⤒"},
		"dodge": {"pos": br.call(258, 188), "r": 42 * unit, "label": "↯"},
		"block": {"pos": br.call(128, 272), "r": 42 * unit, "label": "⛨", "hold": true},
		"bow": {"pos": br.call(365, 128), "r": 38 * unit, "label": "➹", "hold": true},
		"sprint": {"pos": br.call(360, 238), "r": 34 * unit, "label": "»"},
		"lock": {"pos": br.call(252, 300), "r": 30 * unit, "label": "◎"},
		"switch": {"pos": br.call(45, 360), "r": 26 * unit, "label": "⇄"},
		"interact": {"pos": br.call(240, 410), "r": 46 * unit, "label": "✋"},
	}
	# Ability row along the bottom, between the stick zone and the cluster.
	var row_left := 300.0 * unit
	var row_right := s.x - 415.0 * unit
	var step := minf(78.0 * unit, (row_right - row_left) / 5.0)
	var r := minf(32.0 * unit, step * 0.46)
	for i in 5:
		_buttons["ability_%d" % (i + 1)] = {"pos": Vector2(row_left + step * (i + 0.5), s.y - 52 * unit), "r": r, "label": "", "ability": i}
	queue_redraw()
	reserved_changed.emit(reserved_rects())


## Screen areas other UI must keep clear: every button (with a margin) and
## the joystick's home zone.
func reserved_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for k: String in _buttons.keys():
		var b: Dictionary = _buttons[k]
		var r := float(b["r"]) * 1.25
		out.append(Rect2((b["pos"] as Vector2) - Vector2(r, r), Vector2(r, r) * 2.0))
	var u := clampf(minf(size.x, size.y) / 720.0, 0.7, 1.6)
	out.append(Rect2(Vector2(0, size.y - 300 * u), Vector2(300 * u, 300 * u)))
	return out


func _button_at(p: Vector2) -> String:
	for k: String in _buttons.keys():
		var b: Dictionary = _buttons[k]
		if k == "interact" and not interact_available:
			continue
		if b.has("ability") and _ability(int(b["ability"])) == null:
			continue
		if p.distance_to(b["pos"]) <= float(b["r"]) * 1.15:
			return k
	return ""


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	# Godot emulates a mouse from the first finger. When that finger belongs
	# to the stick, a button or the look drag, the emulated click must never
	# reach GUI controls underneath (it used to open the journal through the
	# quest tracker and freeze jump/sprint).
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		if _owned.has(0):
			get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			var b := _button_at(t.position)
			if b != "":
				_press(b, t.index)
				_owned[t.index] = true
				get_viewport().set_input_as_handled()
			elif t.position.x < size.x * 0.42 and _joy_index == -1 and t.position.y > 140:
				_joy_index = t.index
				_joy_origin = t.position
				_joy_pos = t.position
				_owned[t.index] = true
				get_viewport().set_input_as_handled()
			elif t.position.x >= size.x * 0.42 and _look_index == -1 and t.position.y > 90 and not _over_gui_button(t.position):
				_look_index = t.index
				_look_last = t.position
				_owned[t.index] = true
				get_viewport().set_input_as_handled()
		else:
			_owned.erase(t.index)
			if t.index == _joy_index:
				_joy_index = -1
				TouchInput.move = Vector2.ZERO
			if t.index == _look_index:
				_look_index = -1
			for k: String in _pressed.keys():
				if _pressed[k] == t.index:
					_pressed.erase(k)
					_release(k)
		queue_redraw()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _joy_index:
			_joy_pos = d.position
			var v := (_joy_pos - _joy_origin) / JOY_RADIUS
			if v.length() > 1.0:
				_joy_origin = _joy_pos - v.normalized() * JOY_RADIUS
				v = v.normalized()
			TouchInput.move = v if v.length() > DEAD_ZONE else Vector2.ZERO
			queue_redraw()
			get_viewport().set_input_as_handled()
		elif d.index == _look_index:
			var delta := d.position - _look_last
			_look_last = d.position
			# Degrees relative to screen height keeps feel consistent across devices.
			var scale := LOOK_DEG_PER_SCREEN / maxf(size.y, 1.0) * Settings.touch_sensitivity
			TouchInput.look_delta += delta * scale
			get_viewport().set_input_as_handled()


func _press(b: String, index: int) -> void:
	_pressed[b] = index
	match b:
		"jump":
			TouchInput.queue_jump()
		"interact":
			TouchInput.queue_interact()
		"sprint":
			_sprint_toggle = not _sprint_toggle
			TouchInput.sprint_held = _sprint_toggle
		"attack":
			TouchInput.attack_held = true
		"block":
			TouchInput.block_held = true
		"bow":
			TouchInput.bow_held = true
		"dodge", "lock", "switch":
			TouchInput.queue(b)
		_:
			if b.begins_with("ability_"):
				TouchInput.queue(b)


func _release(b: String) -> void:
	match b:
		"attack":
			TouchInput.attack_held = false
		"block":
			TouchInput.block_held = false
		"bow":
			TouchInput.bow_held = false


## True when a real GUI button (e.g. the HUD's top bar) sits under `p`, so the
## touch should go to it instead of starting a camera drag.
func _over_gui_button(p: Vector2) -> bool:
	for b in get_tree().get_nodes_in_group("hud_button"):
		var c := b as Control
		if c and c.is_visible_in_tree() and c.get_global_rect().has_point(p):
			return true
	return false


func _combat() -> PlayerCombat:
	var p := get_tree().get_first_node_in_group("player")
	return p.get("combat") if p else null


func _ability(i: int) -> AbilityData:
	if Game.profile == null:
		return null
	var list := Game.profile.usable_abilities()
	return list[i] if i < list.size() else null


func _process(_delta: float) -> void:
	# Cooldown sweeps and bow draw need continuous redraws.
	if is_visible_in_tree():
		queue_redraw()


func release_all() -> void:
	_owned.clear()
	_joy_index = -1
	_look_index = -1
	_pressed.clear()
	TouchInput.reset()
	_sprint_toggle = false
	queue_redraw()


func _draw() -> void:
	# Joystick hint / active stick.
	var base := _joy_origin if _joy_index != -1 else Vector2(170, size.y - 170)
	var alpha := 0.9 if _joy_index != -1 else 0.35
	draw_circle(base, JOY_RADIUS, Color(0.15, 0.05, 0.3, 0.35 * alpha))
	draw_arc(base, JOY_RADIUS, 0, TAU, 48, Color(0.5, 0.9, 1.0, 0.6 * alpha), 3.0, true)
	var knob := _joy_pos if _joy_index != -1 else base
	draw_circle(knob, 34, Color(0.4, 1.0, 0.95, 0.55 * alpha))
	var font := UiTheme.bold_font()
	var pc := _combat()
	for k: String in _buttons.keys():
		var b: Dictionary = _buttons[k]
		if k == "interact" and not interact_available:
			continue
		var ab: AbilityData = null
		if b.has("ability"):
			ab = _ability(int(b["ability"]))
			if ab == null:
				continue
		var pressed := _pressed.has(k) or (k == "sprint" and _sprint_toggle) or (k == "lock" and pc and is_instance_valid(pc.lock_target))
		var r := float(b["r"])
		var col := Color(0.45, 0.2, 0.8, 0.55) if not pressed else Color(0.3, 1.0, 0.9, 0.7)
		if k == "interact":
			col = Color(1.0, 0.75, 0.3, 0.75)
		elif k == "attack":
			col = Color(0.75, 0.2, 0.35, 0.6) if not pressed else Color(1.0, 0.5, 0.4, 0.8)
		elif ab:
			col = Color(ab.color.r * 0.5, ab.color.g * 0.5, ab.color.b * 0.5, 0.65)
		draw_circle(b["pos"], r, col)
		draw_arc(b["pos"], r, 0, TAU, 40, Color(1, 1, 1, 0.6), 2.5, true)
		if ab and pc:
			var cd := pc.cooldown_ratio(ab)
			if cd > 0.0:
				draw_arc(b["pos"], r * 0.5, -PI * 0.5, -PI * 0.5 + TAU * cd, 32, Color(0.0, 0.0, 0.0, 0.6), r, true)
			if Game.profile and Game.profile.stats.mana < ab.mana_cost:
				draw_circle(b["pos"], r, Color(0.1, 0.1, 0.3, 0.5))
		if k == "bow" and pc and pc.draw >= 0.0:
			draw_arc(b["pos"], r + 6, -PI * 0.5, -PI * 0.5 + TAU * pc.draw, 32, UiTheme.GOLD, 5.0, true)
		var label := String(b["label"]) if ab == null else ab.glyph
		var fs := int(r * 0.8)
		var ts := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		draw_string(font, (b["pos"] as Vector2) - Vector2(ts.x * 0.5, -fs * 0.35), label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs, Color.WHITE)
