class_name ItemIcon
extends Control
## Procedural item icon: a faceted gem in the item's colour, a glyph and a
## rarity rim. Used by inventory, shop and reward screens.

var item: ItemData:
	set(v):
		item = v
		queue_redraw()
var count: int = 0:
	set(v):
		count = v
		queue_redraw()
var highlight: bool = false:
	set(v):
		highlight = v
		queue_redraw()


func _init(it: ItemData = null, n: int = 0, sz: float = 64.0) -> void:
	item = it
	count = n
	custom_minimum_size = Vector2(sz, sz)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.04, 0.18, 0.9)
	bg.set_corner_radius_all(12)
	bg.border_color = UiTheme.GOLD if highlight else (item.rarity_color() if item else Color(0.4, 0.3, 0.6))
	bg.set_border_width_all(3 if highlight else 2)
	draw_style_box(bg, r)
	if item == null:
		return
	var c := size * 0.5
	var rad := minf(size.x, size.y) * 0.32
	var pts := PackedVector2Array()
	var sides := 6 if item.is_equipment() else (4 if item.category == ItemData.Category.QUEST else 8)
	for i in sides:
		var a := TAU * i / sides - PI * 0.5
		pts.append(c + Vector2(cos(a), sin(a)) * rad)
	draw_colored_polygon(pts, item.icon_color.darkened(0.25))
	var inner := PackedVector2Array()
	for p: Vector2 in pts:
		inner.append(c + (p - c) * 0.65 + Vector2(0, -rad * 0.08))
	draw_colored_polygon(inner, item.icon_color.lightened(0.15))
	var font := UiTheme.title_font()
	var fs := int(size.y * 0.34)
	var ts := font.get_string_size(item.icon_glyph, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
	draw_string(font, c + Vector2(-ts.x * 0.5, fs * 0.36), item.icon_glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.95))
	if count > 1:
		var cs := str(count)
		var bf := UiTheme.bold_font()
		draw_string(bf, Vector2(size.x - 6 - bf.get_string_size(cs, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x, size.y - 6), cs, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
