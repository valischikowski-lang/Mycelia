class_name ShopPanel
extends Control
## Simple buy/sell shop driven by resources/shops/<id>.json. Prices are
## validated against the player's glimmer by the model (Inventory).

signal closed()

var shop: Dictionary = {}
var _body: VBoxContainer
var _mode: String = "buy"


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.0, 0.07, 0.65)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := UiTheme.panel(UiTheme.BG_DEEP, UiTheme.GOLD)
	panel.custom_minimum_size = Vector2(720, 520)
	center.add_child(panel)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 10)
	panel.add_child(_body)
	EventBus.inventory_changed.connect(func() -> void:
		if visible:
			_rebuild())


func open(shop_id: String) -> void:
	shop = Database.shop(shop_id)
	if shop.is_empty():
		closed.emit()
		return
	_mode = "buy"
	visible = true
	AudioManager.play_ui("ui_open")
	_rebuild()


func close() -> void:
	if not visible:
		return
	visible = false
	AudioManager.play_ui("ui_close")
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()


func _rebuild() -> void:
	for c in _body.get_children():
		c.queue_free()
	var prof := Game.profile
	var head := HBoxContainer.new()
	head.add_child(UiTheme.title(String(shop.get("name", "Shop")), 30))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	head.add_child(UiTheme.label("◈ %d glimmer" % prof.inventory.glimmer, 20, UiTheme.GOLD, UiTheme.bold_font()))
	_body.add_child(head)
	var greet := UiTheme.label(String(shop.get("greeting", "")), 17, UiTheme.TEXT_DIM)
	greet.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(greet)
	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 8)
	for m: String in ["buy", "sell"]:
		var mm := m
		var b := UiTheme.button(m.capitalize(), func() -> void:
			_mode = mm
			_rebuild(), 150)
		b.add_theme_stylebox_override("normal", UiTheme.button_style("selected" if m == _mode else "normal"))
		modes.add_child(b)
	_body.add_child(modes)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(680, 320)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	_body.add_child(scroll)
	if _mode == "buy":
		for entry: Variant in shop.get("stock", []):
			var e: Dictionary = entry
			var id := String(e["item_id"])
			var price := int(e["price"])
			var d := Database.item(id)
			if d == null:
				continue
			list.add_child(_row(d, "%d ◈" % price, "Buy", prof.inventory.glimmer >= price, func() -> void:
				if prof.inventory.is_full() and not prof.inventory.has(id):
					EventBus.notify("Your satchel is full.", "warning")
					return
				if prof.inventory.spend_glimmer(price):
					prof.inventory.add(id, 1)
					EventBus.item_collected.emit(id, 1)
					AudioManager.play_sfx("pickup", -6.0)
					EventBus.notify("Bought %s" % d.display_name, "item")))
	else:
		var ratio := float(shop.get("sell_ratio", 0.5))
		for s: Dictionary in prof.inventory.slots.duplicate():
			var id2 := String(s["id"])
			var d2 := Database.item(id2)
			if d2 == null or d2.category == ItemData.Category.QUEST:
				continue
			var value := maxi(1, int(d2.value * ratio))
			list.add_child(_row(d2, "%d ◈  (×%d)" % [value, int(s["count"])], "Sell", true, func() -> void:
				if prof.inventory.remove(id2, 1) > 0:
					prof.inventory.add_glimmer(value)
					EventBus.item_removed.emit(id2, 1)
					AudioManager.play_ui("ui_click")))
	_body.add_child(UiTheme.button("Leave", close, 200))


func _row(d: ItemData, price_text: String, action: String, enabled: bool, cb: Callable) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.add_child(ItemIcon.new(d, 0, 52))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UiTheme.label(d.display_name, 18, d.rarity_color(), UiTheme.bold_font()))
	var desc := UiTheme.label(d.description, 14, UiTheme.TEXT_DIM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(desc)
	h.add_child(info)
	h.add_child(UiTheme.label(price_text, 18, UiTheme.GOLD))
	var b := UiTheme.button(action, cb, 110)
	b.disabled = not enabled
	h.add_child(b)
	return h
