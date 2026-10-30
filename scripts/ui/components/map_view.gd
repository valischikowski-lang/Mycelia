class_name MapView
extends Control
## Painted map of the current region, rendered once from the terrain's own
## height/colour functions. Shows discovered places, NPCs, the tracked
## objective and the player's position/heading.

const RES := 128

static var _cache: Dictionary = {}

var region: Region
var _tex: ImageTexture
var _t: float = 0.0


func setup(r: Region) -> void:
	region = r
	if region == null or region.terrain == null:
		return
	var key := region.region_id
	if _cache.has(key):
		_tex = _cache[key]
	else:
		_tex = _render_terrain()
		_cache[key] = _tex
	queue_redraw()


func _render_terrain() -> ImageTexture:
	var t := region.terrain
	var img := Image.create(RES, RES, false, Image.FORMAT_RGB8)
	var half := 135.0
	for y in RES:
		for x in RES:
			var wx := -half + (x + 0.5) / RES * half * 2.0
			var wz := -half + (y + 0.5) / RES * half * 2.0
			var h := t.height_at(wx, wz)
			var n := t.normal_at(wx, wz)
			var c := t._color_at(wx, wz, h, n)
			if h < t.water_level:
				c = Color(0.1, 0.75, 0.8).lerp(Color(0.05, 0.3, 0.5), clampf((t.water_level - h) / 3.0, 0.0, 1.0))
			var shade := clampf(0.7 + n.x * 0.5 - n.z * 0.3, 0.4, 1.3)
			img.set_pixel(x, y, Color(c.r * shade, c.g * shade, c.b * shade))
	return ImageTexture.create_from_image(img)


func _process(delta: float) -> void:
	_t += delta
	if is_visible_in_tree():
		queue_redraw()


func world_to_map(p: Vector3, rect: Rect2) -> Vector2:
	var half := 135.0
	return rect.position + Vector2((p.x + half) / (half * 2.0), (p.z + half) / (half * 2.0)) * rect.size


func _map_rect() -> Rect2:
	var s := minf(size.x, size.y)
	return Rect2((size - Vector2(s, s)) * 0.5, Vector2(s, s))


func _draw() -> void:
	var rect := _map_rect()
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0.05, 0.02, 0.1)
	frame.border_color = UiTheme.GOLD
	frame.set_border_width_all(3)
	frame.set_corner_radius_all(16)
	frame.shadow_color = Color(UiTheme.EDGE, 0.4)
	frame.shadow_size = 10
	draw_style_box(frame, rect.grow(6))
	if _tex:
		draw_texture_rect(_tex, rect, false)
	if region == null:
		return
	var font := UiTheme.bold_font()
	var prof := Game.profile
	# Discovered places.
	for z in region.get_tree().get_nodes_in_group("discovery_zone"):
		var dz := z as DiscoveryZone
		if dz == null or not dz.is_discovery or dz.display_name == "":
			continue
		if prof and not prof.world.is_discovered(dz.area_id):
			continue
		var mp := world_to_map(dz.global_position, rect)
		draw_circle(mp, 6, Color(0.1, 0.0, 0.2, 0.8))
		draw_circle(mp, 4, UiTheme.GLOW)
		draw_string(font, mp + Vector2(8, 5), dz.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.9))
	# NPCs.
	for n in region.get_tree().get_nodes_in_group("npc"):
		var npc := n as NPC
		if npc == null:
			continue
		var mp := world_to_map(npc.global_position, rect)
		draw_circle(mp, 6, UiTheme.GOLD)
		draw_string(font, mp + Vector2(8, -6), npc.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UiTheme.GOLD)
	# Tracked objective hint.
	if prof and prof.quests.tracked != "":
		var o := prof.quests.current_objective(prof.quests.tracked)
		if o and o.map_hint != Vector3.ZERO:
			var mp := world_to_map(o.map_hint, rect)
			var r := 12.0 + sin(_t * 4.0) * 3.0
			draw_arc(mp, r, 0, TAU, 32, UiTheme.ACCENT, 3.0, true)
			draw_string(font, mp + Vector2(-6, 6), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UiTheme.ACCENT)
	# Player arrow.
	var player := region.get_tree().get_first_node_in_group("player") as Node3D
	if player:
		var mp := world_to_map(player.global_position, rect)
		var yaw := player.rotation.y
		var fwd := Vector2(-sin(yaw), -cos(yaw))
		var side := Vector2(-fwd.y, fwd.x)
		var pts := PackedVector2Array([mp + fwd * 14, mp - fwd * 8 + side * 8, mp - fwd * 4, mp - fwd * 8 - side * 8])
		draw_colored_polygon(pts, Color.WHITE)
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), UiTheme.ACCENT, 2.0, true)
