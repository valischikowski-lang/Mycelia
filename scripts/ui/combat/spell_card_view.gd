class_name SpellCardView
extends Control
## A spell card drawn procedurally: element-coloured body, discipline art,
## mana-cost orb, rarity gem, name and effect text. Readable on phones.

signal pressed(index: int)

const CARD_SIZE := Vector2(172, 240)
const RARITY_COLORS: Array[Color] = [Color(0.8, 0.8, 0.9), Color(0.4, 1.0, 0.55), Color(0.3, 0.8, 1.0), Color(0.85, 0.45, 1.0), Color(1.0, 0.75, 0.25)]

var spell: SpellData
var index: int = 0
var affordable: bool = true
var interactive: bool = true
var selected: bool = false:
	set(v):
		selected = v
		queue_redraw()
var _hover: bool = false
var _t: float = 0.0
var _name: Label
var _summary: Label
var _desc: Label


func _init(sp: SpellData = null, idx: int = 0) -> void:
	spell = sp
	index = idx
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	pivot_offset = CARD_SIZE * 0.5


func _ready() -> void:
	_name = UiTheme.label("", 18, Color.WHITE, UiTheme.bold_font())
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name.position = Vector2(8, 118)
	_name.size = Vector2(CARD_SIZE.x - 16, 26)
	_name.add_theme_constant_override("outline_size", 6)
	_name.add_theme_color_override("font_outline_color", Color(0.1, 0.0, 0.2))
	add_child(_name)
	_summary = UiTheme.label("", 14, Color(1.0, 0.92, 0.6), UiTheme.bold_font())
	_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary.position = Vector2(6, 146)
	_summary.size = Vector2(CARD_SIZE.x - 12, 20)
	add_child(_summary)
	_desc = UiTheme.label("", 12, Color(0.92, 0.88, 1.0))
	_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.position = Vector2(10, 168)
	_desc.size = Vector2(CARD_SIZE.x - 20, 66)
	_desc.clip_text = true
	add_child(_desc)
	for l: Label in [_name, _summary, _desc]:
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_entered.connect(func() -> void:
		_hover = true
		if interactive and affordable:
			AudioManager.play_ui("ui_hover")
		queue_redraw())
	mouse_exited.connect(func() -> void:
		_hover = false
		queue_redraw())
	set_spell(spell, index)


func set_spell(sp: SpellData, idx: int) -> void:
	spell = sp
	index = idx
	if _name == null or sp == null:
		return
	_name.text = sp.display_name
	_summary.text = sp.summary_line()
	_desc.text = sp.description
	tooltip_text = "%s (%s)\n%s" % [sp.display_name, ElementChart.display_name(sp.element), sp.description]
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	var lift := -18.0 if (_hover or selected) and interactive else 0.0
	position.y = lerpf(position.y, lift, minf(1.0, delta * 14.0))
	modulate = Color(1, 1, 1, 1) if affordable or not interactive else Color(0.55, 0.5, 0.6, 0.85)
	if selected:
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return
	var press := false
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		press = mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		press = (event as InputEventScreenTouch).pressed
	if press:
		accept_event()
		pressed.emit(index)


func _draw() -> void:
	if spell == null:
		return
	var col := ElementChart.color(spell.element)
	var rect := Rect2(Vector2.ZERO, CARD_SIZE)
	# Glow when selected.
	if selected:
		var g := 6.0 + sin(_t * 6.0) * 3.0
		var gs := StyleBoxFlat.new()
		gs.bg_color = Color(1.0, 0.85, 0.35, 0.0)
		gs.shadow_color = Color(1.0, 0.85, 0.35, 0.8)
		gs.shadow_size = int(g + 8)
		gs.set_corner_radius_all(18)
		draw_style_box(gs, rect)
	var body := StyleBoxFlat.new()
	body.bg_color = col.darkened(0.72)
	body.border_color = Color(1.0, 0.85, 0.35) if selected else col.lightened(0.15)
	body.set_border_width_all(3)
	body.set_corner_radius_all(18)
	body.corner_detail = 8
	body.anti_aliasing = true
	draw_style_box(body, rect)
	# Inner gradient window for the art.
	var art := Rect2(10, 30, CARD_SIZE.x - 20, 84)
	var art_box := StyleBoxFlat.new()
	art_box.bg_color = col.darkened(0.45)
	art_box.set_corner_radius_all(12)
	art_box.border_color = col.darkened(0.1)
	art_box.set_border_width_all(1)
	draw_style_box(art_box, art)
	_draw_art(art, col)
	# Element banner.
	var font := UiTheme.bold_font()
	draw_string(font, Vector2(46, 22), ElementChart.display_name(spell.element).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col.lightened(0.4))
	# Rarity gem.
	var rc := RARITY_COLORS[clampi(spell.rarity, 0, 4)]
	draw_colored_polygon(PackedVector2Array([Vector2(CARD_SIZE.x - 22, 8), Vector2(CARD_SIZE.x - 12, 17), Vector2(CARD_SIZE.x - 22, 26), Vector2(CARD_SIZE.x - 32, 17)]), rc)
	# Mana cost orb.
	var orb_c := Vector2(22, 20)
	draw_circle(orb_c, 17, Color(0.05, 0.1, 0.25))
	draw_circle(orb_c, 15, UiTheme.MANA.darkened(0.2) if affordable else Color(0.4, 0.3, 0.45))
	draw_arc(orb_c, 15, 0, TAU, 24, Color(0.8, 1.0, 1.0, 0.9), 2.0, true)
	var cost := str(spell.mana_cost)
	var ts := UiTheme.title_font().get_string_size(cost, HORIZONTAL_ALIGNMENT_CENTER, -1, 22)
	draw_string(UiTheme.title_font(), orb_c + Vector2(-ts.x * 0.5, 8), cost, HORIZONTAL_ALIGNMENT_CENTER, -1, 22, Color.WHITE)


func _draw_art(r: Rect2, col: Color) -> void:
	var c := r.get_center()
	var t := _t
	match spell.element:
		"fungal":
			draw_circle(c + Vector2(0, 14), 26, col.darkened(0.2))
			draw_circle(c + Vector2(0, 10), 24, col)
			draw_rect(Rect2(c.x - 6, c.y + 14, 12, 22), Color(0.9, 0.85, 1.0))
			for i in 7:
				var a := TAU * i / 7.0 + t * 0.3
				draw_circle(c + Vector2(cos(a) * 36, sin(a) * 22 - 8), 3.0 + sin(t * 2.0 + i), Color(1.0, 0.95, 0.5, 0.9))
			for i in 4:
				draw_circle(c + Vector2(-10 + i * 7, 2 + (i % 2) * 6), 3, Color(1.0, 0.9, 0.4))
		"crystal":
			for i in 3:
				var h := 30.0 + i * 8.0
				var x := c.x - 22 + i * 22
				draw_colored_polygon(PackedVector2Array([Vector2(x, c.y - h * 0.6), Vector2(x + 9, c.y + 4), Vector2(x, c.y + h * 0.5), Vector2(x - 9, c.y + 4)]), col.lerp(Color.WHITE, 0.2 * i))
			draw_arc(c, 34 + sin(t * 2.0) * 2.0, 0, TAU, 6, Color(col, 0.6), 2.0, true)
		"nature":
			for i in 6:
				var a := TAU * i / 6.0 + t * 0.2
				var p := c + Vector2(cos(a), sin(a)) * 18
				draw_circle(p, 14, Color(col.r, col.g, col.b, 0.85) if i % 2 == 0 else Color(1.0, 0.5, 0.75, 0.85))
			draw_circle(c, 9, Color(1.0, 0.9, 0.4))
		"cosmic":
			var pts := PackedVector2Array()
			for i in 10:
				var a := TAU * i / 10.0 - PI * 0.5 + t * 0.2
				var rr := 32.0 if i % 2 == 0 else 13.0
				pts.append(c + Vector2(cos(a), sin(a)) * rr)
			draw_colored_polygon(pts, col)
			draw_arc(c, 38, t, t + PI * 1.3, 32, Color(0.7, 0.6, 1.0, 0.8), 2.0, true)
			for i in 5:
				draw_circle(c + Vector2(sin(i * 7.1) * 60, cos(i * 3.3) * 34), 1.5, Color.WHITE)
		"chaos":
			for i in 24:
				var a := i * 0.5 + t
				var rr := 3.0 + i * 1.5
				draw_circle(c + Vector2(cos(a), sin(a)) * rr, 3.0, Color.from_hsv(fmod(i * 0.07 + t * 0.2, 1.0), 0.8, 1.0))
	var glyph := spell.icon_glyph
	var gs := UiTheme.title_font().get_string_size(glyph, HORIZONTAL_ALIGNMENT_CENTER, -1, 20)
	draw_string(UiTheme.title_font(), Vector2(r.end.x - gs.x - 6, r.end.y - 6), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.85))
