class_name UiTheme
extends RefCounted
## MYCELIA's visual language for UI: translucent "living glass" panels with
## glowing organic edges, elemental color coding and custom typography.
## Built in code so it stays consistent and themable per region later.

const BG := Color(0.07, 0.03, 0.14, 0.82)
const BG_DEEP := Color(0.04, 0.015, 0.09, 0.94)
const EDGE := Color(0.55, 0.35, 1.0, 0.85)
const GLOW := Color(0.35, 1.0, 0.95)
const TEXT := Color(0.96, 0.93, 1.0)
const TEXT_DIM := Color(0.75, 0.68, 0.9)
const ACCENT := Color(1.0, 0.45, 0.85)
const GOLD := Color(1.0, 0.82, 0.35)
const DANGER := Color(1.0, 0.35, 0.45)
const SUCCESS := Color(0.45, 1.0, 0.6)
const HEALTH := Color(1.0, 0.35, 0.55)
const MANA := Color(0.3, 0.85, 1.0)
const XP := Color(0.85, 0.55, 1.0)

static var _theme: Theme
static var _title_font: Font
static var _body_font: Font
static var _bold_font: Font


static func body_font() -> Font:
	if _body_font == null:
		_body_font = _load_font("res://assets/fonts/Inter-SemiBold.otf")
	return _body_font


static func bold_font() -> Font:
	if _bold_font == null:
		_bold_font = _load_font("res://assets/fonts/Inter-Bold.otf")
	return _bold_font


static func title_font() -> Font:
	if _title_font == null:
		_title_font = _load_font("res://assets/fonts/Caladea-Bold.ttf")
	return _title_font


static func _load_font(path: String) -> Font:
	if ResourceLoader.exists(path):
		var f: Font = load(path)
		if f:
			return f
	return ThemeDB.fallback_font


static func panel_style(bg: Color = BG, edge: Color = EDGE, radius: int = 22, glow: float = 10.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.set_border_width_all(2)
	s.corner_radius_top_left = radius
	s.corner_radius_bottom_right = radius
	s.corner_radius_top_right = int(radius * 0.45)
	s.corner_radius_bottom_left = int(radius * 0.45)
	s.corner_detail = 10
	s.shadow_color = Color(edge.r, edge.g, edge.b, 0.35)
	s.shadow_size = int(glow)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 14
	s.content_margin_bottom = 14
	s.anti_aliasing = true
	return s


static func button_style(state: String, accent: Color = EDGE) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.corner_radius_top_left = 18
	s.corner_radius_bottom_right = 18
	s.corner_radius_top_right = 8
	s.corner_radius_bottom_left = 8
	s.corner_detail = 8
	s.set_border_width_all(2)
	s.content_margin_left = 20
	s.content_margin_right = 20
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	s.anti_aliasing = true
	match state:
		"normal":
			s.bg_color = Color(0.12, 0.05, 0.24, 0.85)
			s.border_color = Color(accent, 0.6)
			s.shadow_color = Color(accent, 0.15)
			s.shadow_size = 4
		"hover":
			s.bg_color = Color(0.2, 0.08, 0.38, 0.92)
			s.border_color = GLOW
			s.shadow_color = Color(GLOW, 0.45)
			s.shadow_size = 12
		"pressed":
			s.bg_color = Color(0.32, 0.12, 0.5, 0.95)
			s.border_color = ACCENT
			s.shadow_color = Color(ACCENT, 0.5)
			s.shadow_size = 14
		"disabled":
			s.bg_color = Color(0.08, 0.05, 0.12, 0.6)
			s.border_color = Color(0.4, 0.35, 0.5, 0.35)
			s.shadow_size = 0
		"focus":
			s.bg_color = Color(0, 0, 0, 0)
			s.border_color = Color(GLOW, 0.8)
			s.shadow_size = 0
		"selected":
			s.bg_color = Color(0.25, 0.1, 0.45, 0.95)
			s.border_color = GOLD
			s.shadow_color = Color(GOLD, 0.4)
			s.shadow_size = 10
	return s


static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = body_font()
	t.default_font_size = 20
	t.set_stylebox("panel", "PanelContainer", panel_style())
	t.set_stylebox("panel", "Panel", panel_style())
	for cls: String in ["Button", "OptionButton"]:
		t.set_stylebox("normal", cls, button_style("normal"))
		t.set_stylebox("hover", cls, button_style("hover"))
		t.set_stylebox("pressed", cls, button_style("pressed"))
		t.set_stylebox("disabled", cls, button_style("disabled"))
		t.set_stylebox("focus", cls, button_style("focus"))
		t.set_color("font_color", cls, TEXT)
		t.set_color("font_hover_color", cls, Color.WHITE)
		t.set_color("font_pressed_color", cls, GOLD)
		t.set_color("font_disabled_color", cls, Color(0.55, 0.5, 0.65))
		t.set_color("font_focus_color", cls, Color.WHITE)
		t.set_font("font", cls, bold_font())
		t.set_font_size("font_size", cls, 20)
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_shadow_color", "Label", Color(0.1, 0.0, 0.2, 0.7))
	t.set_constant("shadow_offset_x", "Label", 1)
	t.set_constant("shadow_offset_y", "Label", 2)
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_font("normal_font", "RichTextLabel", body_font())
	t.set_font("bold_font", "RichTextLabel", bold_font())
	t.set_font_size("normal_font_size", "RichTextLabel", 20)
	t.set_font_size("bold_font_size", "RichTextLabel", 20)
	# Progress bars.
	var pb_bg := StyleBoxFlat.new()
	pb_bg.bg_color = Color(0.05, 0.02, 0.1, 0.8)
	pb_bg.set_corner_radius_all(8)
	pb_bg.set_border_width_all(1)
	pb_bg.border_color = Color(0.6, 0.45, 1.0, 0.5)
	t.set_stylebox("background", "ProgressBar", pb_bg)
	var pb_fill := StyleBoxFlat.new()
	pb_fill.bg_color = GLOW
	pb_fill.set_corner_radius_all(8)
	t.set_stylebox("fill", "ProgressBar", pb_fill)
	t.set_color("font_color", "ProgressBar", TEXT)
	# Sliders.
	var sl := StyleBoxFlat.new()
	sl.bg_color = Color(0.2, 0.1, 0.35, 0.9)
	sl.set_corner_radius_all(6)
	sl.content_margin_top = 4
	sl.content_margin_bottom = 4
	t.set_stylebox("slider", "HSlider", sl)
	var sl_fill := sl.duplicate() as StyleBoxFlat
	sl_fill.bg_color = Color(GLOW, 0.8)
	t.set_stylebox("grabber_area", "HSlider", sl_fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", sl_fill)
	t.set_icon("grabber", "HSlider", _circle_icon(22, GOLD))
	t.set_icon("grabber_highlight", "HSlider", _circle_icon(26, Color.WHITE))
	# Tabs.
	t.set_stylebox("tab_selected", "TabBar", button_style("selected"))
	t.set_stylebox("tab_unselected", "TabBar", button_style("normal"))
	t.set_stylebox("tab_hovered", "TabBar", button_style("hover"))
	t.set_color("font_selected_color", "TabBar", GOLD)
	t.set_color("font_unselected_color", "TabBar", TEXT_DIM)
	t.set_color("font_hovered_color", "TabBar", Color.WHITE)
	t.set_font("font", "TabBar", bold_font())
	t.set_font_size("font_size", "TabBar", 19)
	# Scroll bars thin and glowy.
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.05, 0.2, 0.4)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	t.set_stylebox("scroll", "VScrollBar", sb)
	var gr := StyleBoxFlat.new()
	gr.bg_color = Color(0.6, 0.4, 1.0, 0.7)
	gr.set_corner_radius_all(4)
	t.set_stylebox("grabber", "VScrollBar", gr)
	t.set_stylebox("grabber_highlight", "VScrollBar", gr)
	t.set_stylebox("grabber_pressed", "VScrollBar", gr)
	# CheckBox.
	t.set_color("font_color", "CheckBox", TEXT)
	t.set_font("font", "CheckBox", body_font())
	t.set_icon("checked", "CheckBox", _circle_icon(24, GLOW))
	t.set_icon("unchecked", "CheckBox", _ring_icon(24, Color(0.6, 0.5, 0.9)))
	t.set_stylebox("normal", "CheckBox", StyleBoxEmpty.new())
	t.set_stylebox("hover", "CheckBox", StyleBoxEmpty.new())
	t.set_stylebox("pressed", "CheckBox", StyleBoxEmpty.new())
	t.set_stylebox("focus", "CheckBox", StyleBoxEmpty.new())
	t.set_stylebox("hover_pressed", "CheckBox", StyleBoxEmpty.new())
	# Tooltip.
	t.set_stylebox("panel", "TooltipPanel", panel_style(BG_DEEP, GLOW, 10, 4))
	t.set_color("font_color", "TooltipLabel", TEXT)
	_theme = t
	return t


static func _circle_icon(size: int, color: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var d := Vector2(x - size * 0.5 + 0.5, y - size * 0.5 + 0.5).length()
			var a := clampf(size * 0.5 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(color, a))
	return ImageTexture.create_from_image(img)


static func _ring_icon(size: int, color: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var d := Vector2(x - size * 0.5 + 0.5, y - size * 0.5 + 0.5).length()
			var a := clampf(1.5 - absf(d - size * 0.38), 0.0, 1.0)
			img.set_pixel(x, y, Color(color, a))
	return ImageTexture.create_from_image(img)


## Convenience builders -------------------------------------------------------

static func label(text: String, size: int = 20, color: Color = TEXT, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if font:
		l.add_theme_font_override("font", font)
	return l


static func title(text: String, size: int = 34, color: Color = GOLD) -> Label:
	var l := label(text, size, color, title_font())
	l.add_theme_color_override("font_outline_color", Color(0.25, 0.05, 0.4, 0.9))
	l.add_theme_constant_override("outline_size", 8)
	return l


static func button(text: String, callback: Callable = Callable(), min_width: float = 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	if min_width > 0.0:
		b.custom_minimum_size.x = min_width
	b.custom_minimum_size.y = maxf(b.custom_minimum_size.y, 52.0)
	if callback.is_valid():
		b.pressed.connect(callback)
	b.pressed.connect(func() -> void: AudioManager.play_ui("ui_click"))
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			AudioManager.play_ui("ui_hover"))
	return b


static func bar(color: Color, min_size: Vector2 = Vector2(220, 18)) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.custom_minimum_size = min_size
	pb.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(8)
	fill.shadow_color = Color(color, 0.5)
	fill.shadow_size = 5
	pb.add_theme_stylebox_override("fill", fill)
	return pb


static func panel(bg: Color = BG, edge: Color = EDGE) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_style(bg, edge))
	return p
