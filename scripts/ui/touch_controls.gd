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
	_buttons = {
		"jump": {"pos": Vector2(s.x - 120 * unit, s.y - 130 * unit), "r": 62 * unit, "label": "⤒"},
		"sprint": {"pos": Vector2(s.x - 255 * unit, s.y - 95 * unit), "r": 46 * unit, "label": "»"},
		"interact": {"pos": Vector2(s.x - 140 * unit, s.y - 290 * unit), "r": 54 * unit, "label": "✋"},
	}
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
	out.append(Rect2(Vector2(0, size.y - 340), Vector2(340, 340)))
	return out


func _button_at(p: Vector2) -> String:
	for k: String in _buttons.keys():
		var b: Dictionary = _buttons[k]
		if k == "interact" and not interact_available:
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


## True when a real GUI button (e.g. the HUD's top bar) sits under `p`, so the
## touch should go to it instead of starting a camera drag.
func _over_gui_button(p: Vector2) -> bool:
	for b in get_tree().get_nodes_in_group("hud_button"):
		var c := b as Control
		if c and c.is_visible_in_tree() and c.get_global_rect().has_point(p):
			return true
	return false


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
	for k: String in _buttons.keys():
		var b: Dictionary = _buttons[k]
		if k == "interact" and not interact_available:
			continue
		var pressed := _pressed.has(k) or (k == "sprint" and _sprint_toggle)
		var r := float(b["r"])
		var col := Color(0.45, 0.2, 0.8, 0.55) if not pressed else Color(0.3, 1.0, 0.9, 0.7)
		if k == "interact":
			col = Color(1.0, 0.75, 0.3, 0.75)
		draw_circle(b["pos"], r, col)
		draw_arc(b["pos"], r, 0, TAU, 40, Color(1, 1, 1, 0.6), 2.5, true)
		var label := String(b["label"])
		var fs := int(r * 0.8)
		var ts := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		draw_string(font, (b["pos"] as Vector2) - Vector2(ts.x * 0.5, -fs * 0.35), label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs, Color.WHITE)
