class_name DialogueBox
extends Control
## Conversation UI: speaker plate, typewriter text and choice buttons.
## Drives a DialogueRunner; number keys 1-4 pick choices on PC.

signal opened()
signal closed()

const CHARS_PER_SEC := 55.0

var runner := DialogueRunner.new()
var _panel: PanelContainer
var _speaker: Label
var _text: RichTextLabel
var _options: VBoxContainer
var _typing: bool = false
var _visible_chars: float = 0.0
var _total_chars: int = 0
var _pending_options: Array = []
var _npc: Node


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiTheme.get_theme()
	visible = false
	_panel = UiTheme.panel(Color(0.05, 0.02, 0.1, 0.9), UiTheme.EDGE)
	_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_panel.offset_left = -560
	_panel.offset_right = 560
	_panel.offset_bottom = -24
	_panel.offset_top = -330
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_panel.add_child(v)
	_speaker = UiTheme.title("", 28)
	v.add_child(_speaker)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.custom_minimum_size = Vector2(1000, 110)
	_text.fit_content = true
	_text.scroll_active = false
	_text.add_theme_font_size_override("normal_font_size", 21)
	_text.mouse_filter = Control.MOUSE_FILTER_STOP
	_text.gui_input.connect(_on_text_input)
	v.add_child(_text)
	_options = VBoxContainer.new()
	_options.add_theme_constant_override("separation", 6)
	v.add_child(_options)
	runner.line.connect(_on_line)
	runner.finished.connect(_on_finished)


func open(npc: Node, dialogue_id: String) -> bool:
	_npc = npc
	visible = true
	opened.emit()
	if not runner.start(dialogue_id, Game.profile):
		visible = false
		closed.emit()
		return false
	return true


func is_open() -> bool:
	return visible


func close() -> void:
	if runner.active:
		runner.close()


func _on_line(speaker: String, text: String, options: Array) -> void:
	_speaker.text = speaker
	_text.text = text
	_total_chars = _text.get_total_character_count()
	_visible_chars = 0.0
	_text.visible_characters = 0
	_typing = true
	_pending_options = options
	for c in _options.get_children():
		c.queue_free()
	if _npc and _npc is NPC and (_npc as NPC).rig:
		(_npc as NPC).rig.play_cast()


func _show_options() -> void:
	for c in _options.get_children():
		c.queue_free()
	var i := 0
	for o: Variant in _pending_options:
		var od: Dictionary = o
		var idx := i
		var label := "%d.  %s" % [i + 1, String(od.get("text", "…"))]
		var b := UiTheme.button(label, func() -> void: runner.choose(idx))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size.y = 46
		b.add_theme_font_size_override("font_size", 18)
		if bool(od.get("seen", false)):
			b.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
		_options.add_child(b)
		if i == 0:
			b.call_deferred("grab_focus")
		i += 1


func _process(delta: float) -> void:
	if not visible or not _typing:
		return
	_visible_chars += delta * CHARS_PER_SEC
	_text.visible_characters = int(_visible_chars)
	if int(_visible_chars) >= _total_chars:
		_finish_typing()


func _finish_typing() -> void:
	_typing = false
	_text.visible_characters = -1
	_show_options()


func _on_text_input(ev: InputEvent) -> void:
	if (ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed) or (ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed):
		if _typing:
			_finish_typing()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).physical_keycode
		if _typing and (k == KEY_SPACE or k == KEY_ENTER or k == KEY_E):
			_finish_typing()
			get_viewport().set_input_as_handled()
			return
		if k >= KEY_1 and k <= KEY_9 and not _typing:
			var idx := int(k - KEY_1)
			if idx < _pending_options.size():
				runner.choose(idx)
				get_viewport().set_input_as_handled()


func _on_finished(dialogue_id: String) -> void:
	visible = false
	_npc = null
	EventBus.dialogue_finished.emit(dialogue_id)
	closed.emit()
