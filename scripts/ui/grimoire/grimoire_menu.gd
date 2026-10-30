class_name GrimoireMenu
extends Control
## The Grimoire: the player's living spellbook-journal. One menu with tabs
## for Character, Inventory, Spellbook, Skills, Journal, Map and Settings.

signal closed()

const TABS: Array = [
	["character", "Character"], ["inventory", "Inventory"], ["spellbook", "Spellbook"],
	["skills", "Skills"], ["journal", "Journal"], ["map", "Map"], ["settings", "Settings"],
]

var current_tab: String = "inventory"
var _tab_buttons: Dictionary = {}
var _content: MarginContainer
var _selected_slot: int = -1
var _selected_skill: String = ""
var _selected_quest: String = ""
var _journal_mode: String = "quests"
var _selected_entry: String = ""
var _dirty: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.0, 0.07, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := UiTheme.panel(UiTheme.BG_DEEP, UiTheme.EDGE)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 28
	panel.offset_right = -28
	panel.offset_top = 22
	panel.offset_bottom = -22
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	v.add_child(top)
	top.add_child(UiTheme.title("Grimoire", 32))
	var tabs_scroll := ScrollContainer.new()
	tabs_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	top.add_child(tabs_scroll)
	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 6)
	tabs_scroll.add_child(tab_row)
	for t: Array in TABS:
		var id := String(t[0])
		var b := UiTheme.button(String(t[1]), func() -> void: show_tab(id))
		b.add_theme_font_size_override("font_size", 17)
		b.custom_minimum_size.y = 46
		tab_row.add_child(b)
		_tab_buttons[id] = b
	top.add_child(UiTheme.button("✕", close, 56))
	_content = MarginContainer.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_content)
	for sig: Signal in [EventBus.inventory_changed, EventBus.stats_changed, EventBus.equipment_changed, EventBus.quest_tracker_changed, EventBus.spell_unlocked]:
		sig.connect(func(_a: Variant = null) -> void: _dirty = true)


func _process(_delta: float) -> void:
	if visible and _dirty:
		_dirty = false
		if current_tab in ["character", "inventory", "spellbook", "skills"]:
			show_tab(current_tab)


func open(tab: String = "inventory") -> void:
	visible = true
	AudioManager.play_ui("ui_open")
	show_tab(tab)


func close() -> void:
	if not visible:
		return
	visible = false
	AudioManager.play_ui("ui_close")
	closed.emit()


func show_tab(tab: String) -> void:
	current_tab = tab
	for id: String in _tab_buttons.keys():
		(_tab_buttons[id] as Button).add_theme_stylebox_override("normal", UiTheme.button_style("selected" if id == tab else "normal"))
	for c in _content.get_children():
		c.queue_free()
	var node: Control
	match tab:
		"character":
			node = _build_character()
		"inventory":
			node = _build_inventory()
		"spellbook":
			node = _build_spellbook()
		"skills":
			node = _build_skills()
		"journal":
			node = _build_journal()
		"map":
			node = _build_map()
		"settings":
			var sp := SettingsPanel.new()
			sp.close_requested.connect(close)
			node = sp
	if node:
		_content.add_child(node)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()


# ------------------------------------------------------------------ helpers
func _box(edge: Color = UiTheme.EDGE) -> PanelContainer:
	var p := UiTheme.panel(Color(0.09, 0.04, 0.16, 0.85), Color(edge, 0.6))
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return p


func _scroll(child: Control) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(child)
	return s


func _wrap_label(text: String, size: int = 18, color: Color = UiTheme.TEXT) -> Label:
	var l := UiTheme.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _stat_text(stat: String, value: float) -> String:
	if stat in ["shield_bonus", "heal_bonus"]:
		return "+%d%%" % int(round(value * 100.0))
	if stat == "crit_chance":
		return "%.1f%%" % value
	return "%d" % int(round(value))


# ------------------------------------------------------------------ character
func _build_character() -> Control:
	var prof := Game.profile
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var left := _box()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 8)
	left.add_child(_scroll(lv))
	lv.add_child(UiTheme.title("%s · Level %d" % [prof.display_name, prof.stats.level], 28))
	var xp := UiTheme.bar(UiTheme.XP, Vector2(300, 14))
	xp.max_value = prof.stats.xp_to_next()
	xp.value = prof.stats.xp
	lv.add_child(xp)
	lv.add_child(UiTheme.label("Experience %d / %d   ·   Skill points: %d   ·   ◈ %d glimmer" % [prof.stats.xp, prof.stats.xp_to_next(), prof.stats.skill_points, prof.inventory.glimmer], 16, UiTheme.TEXT_DIM))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 30)
	grid.add_theme_constant_override("v_separation", 6)
	lv.add_child(grid)
	for stat: String in PlayerStats.STAT_NAMES.keys():
		grid.add_child(UiTheme.label(PlayerStats.STAT_NAMES[stat], 19, UiTheme.TEXT_DIM))
		var val := prof.stats.get_stat(stat)
		var bonus := float(prof.stats.bonuses.get(stat, 0.0))
		var txt := _stat_text(stat, val)
		if stat == "max_health":
			txt = "%d / %d" % [int(prof.stats.health), prof.stats.max_health()]
		elif stat == "max_mana":
			txt = "%d / %d" % [int(prof.stats.mana), prof.stats.max_mana()]
		if bonus != 0.0:
			txt += "  (+%s)" % _stat_text(stat, bonus)
		grid.add_child(UiTheme.label(txt, 19, Color.WHITE, UiTheme.bold_font()))
	for stat: String in ["dot_bonus", "shield_bonus", "heal_bonus", "mana_regen"]:
		if prof.stats.bonuses.has(stat):
			var names := {"dot_bonus": "Rot Damage / turn", "shield_bonus": "Shield Strength", "heal_bonus": "Healing Power", "mana_regen": "Extra Mana / turn"}
			grid.add_child(UiTheme.label(names[stat], 17, UiTheme.TEXT_DIM))
			grid.add_child(UiTheme.label("+" + _stat_text(stat, float(prof.stats.bonuses[stat])).trim_prefix("+"), 17, UiTheme.SUCCESS, UiTheme.bold_font()))
	lv.add_child(UiTheme.label("Play time: %dh %02dm" % [int(prof.play_time / 3600.0), int(prof.play_time / 60.0) % 60], 15, UiTheme.TEXT_DIM))
	var right := _box(UiTheme.GOLD)
	right.custom_minimum_size.x = 420
	row.add_child(right)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 8)
	right.add_child(_scroll(rv))
	rv.add_child(UiTheme.title("Equipment", 24))
	for slot: String in ItemData.EQUIP_SLOTS:
		var id: String = prof.inventory.equipment.get(slot, "")
		var d := Database.item(id) if id != "" else null
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		h.add_child(ItemIcon.new(d, 0, 52))
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(UiTheme.label(String(ItemData.SLOT_NAMES.get(slot, slot.capitalize())), 14, UiTheme.TEXT_DIM))
		info.add_child(UiTheme.label(d.display_name if d else "— empty —", 18, d.rarity_color() if d else UiTheme.TEXT_DIM, UiTheme.bold_font()))
		h.add_child(info)
		if d:
			var s := slot
			h.add_child(UiTheme.button("Unequip", func() -> void:
				if not prof.inventory.unequip(s):
					EventBus.notify("Your satchel is full.", "warning")
				show_tab("character")))
		rv.add_child(h)
	return row


# ------------------------------------------------------------------ inventory
func _build_inventory() -> Control:
	var prof := Game.profile
	var inv := prof.inventory
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var left := _box()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	var lv := VBoxContainer.new()
	left.add_child(lv)
	lv.add_child(UiTheme.label("Satchel  %d / %d       ◈ %d glimmer" % [inv.slots.size(), inv.capacity, inv.glimmer], 18, UiTheme.GOLD, UiTheme.bold_font()))
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	lv.add_child(_scroll(grid))
	if _selected_slot >= inv.slots.size():
		_selected_slot = -1
	for i in inv.slots.size():
		var s: Dictionary = inv.slots[i]
		var d := Database.item(String(s["id"]))
		var b := Button.new()
		b.custom_minimum_size = Vector2(84, 84)
		b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		b.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		b.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var icon := ItemIcon.new(d, int(s["count"]), 80)
		icon.highlight = i == _selected_slot
		icon.position = Vector2(2, 2)
		b.add_child(icon)
		var idx := i
		b.pressed.connect(func() -> void:
			_selected_slot = idx
			AudioManager.play_ui("ui_click")
			show_tab("inventory"))
		b.tooltip_text = d.display_name if d else String(s["id"])
		grid.add_child(b)
	for i in range(inv.slots.size(), inv.capacity):
		var empty := ItemIcon.new(null, 0, 80)
		empty.modulate = Color(1, 1, 1, 0.35)
		grid.add_child(empty)
	var right := _box(UiTheme.GOLD)
	right.custom_minimum_size.x = 400
	row.add_child(right)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 10)
	right.add_child(rv)
	if _selected_slot < 0:
		rv.add_child(UiTheme.title("Inventory", 26))
		rv.add_child(_wrap_label("Select an item to inspect it. Consumables can be used here; equipment can be worn.", 17, UiTheme.TEXT_DIM))
		return row
	var slot: Dictionary = inv.slots[_selected_slot]
	var item := Database.item(String(slot["id"]))
	if item == null:
		return row
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	head.add_child(ItemIcon.new(item, 0, 72))
	var hv := VBoxContainer.new()
	hv.add_child(UiTheme.label(item.display_name, 22, item.rarity_color(), UiTheme.title_font()))
	hv.add_child(UiTheme.label("%s · %s%s" % [String(ItemData.Rarity.keys()[item.rarity]).capitalize(), item.category_name(), (" · " + item.slot_name()) if item.equip_slot != "" else ""], 15, UiTheme.TEXT_DIM))
	head.add_child(hv)
	rv.add_child(head)
	rv.add_child(_wrap_label(item.description, 18))
	for stat: String in item.stat_bonuses.keys():
		rv.add_child(UiTheme.label("+%s %s" % [_stat_text(stat, float(item.stat_bonuses[stat])), PlayerStats.STAT_NAMES.get(stat, stat.capitalize())], 17, UiTheme.SUCCESS, UiTheme.bold_font()))
	if item.weapon_kind != "":
		var w := PackedStringArray()
		w.append(item.weapon_kind.capitalize())
		if item.damage > 0:
			w.append("%d damage" % int(item.damage))
		if item.is_weapon():
			w.append("%.1f attacks/s" % item.attack_speed)
			w.append("%.1f m reach" % item.reach)
		if item.block_power > 0:
			w.append("blocks %d%%" % int(item.block_power * 100))
			w.append("parry %.2fs" % item.parry_window)
		rv.add_child(UiTheme.label(" · ".join(w), 17, UiTheme.GLOW, UiTheme.bold_font()))
	if item.class_id != "":
		var c := Database.player_class(item.class_id)
		var mine := Game.profile != null and Game.profile.class_id == item.class_id
		rv.add_child(UiTheme.label("%s item%s" % [c.display_name if c else item.class_id, "" if mine else " — other callings can carry it, but its special power sleeps"], 15, c.color if c else UiTheme.TEXT_DIM))
	if item.source != "":
		rv.add_child(UiTheme.label("Found: " + item.source, 14, UiTheme.TEXT_DIM))
	rv.add_child(UiTheme.label("Count: %d · Value: %d glimmer" % [int(slot["count"]), item.value], 15, UiTheme.TEXT_DIM))
	if item.is_usable():
		rv.add_child(UiTheme.button("Use", func() -> void:
			var msg := prof.use_item(item.id)
			if msg != "":
				EventBus.notify(msg, "success")
				AudioManager.play_sfx("heal", -6.0)
			show_tab("inventory")))
	if item.is_equipment():
		rv.add_child(UiTheme.button("Equip", func() -> void:
			if prof.inventory.equip(item.id):
				EventBus.notify("Equipped %s" % item.display_name, "success")
				_selected_slot = -1
			show_tab("inventory")))
	return row


# ------------------------------------------------------------------ spellbook
func _build_spellbook() -> Control:
	var prof := Game.profile
	var book := prof.spellbook
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	var info := HBoxContainer.new()
	info.add_theme_constant_override("separation", 20)
	info.add_child(UiTheme.label("Deck: %d cards  (min %d, max %d, up to %d copies each)" % [book.deck_size(), Spellbook.DECK_MIN, Spellbook.DECK_MAX, Spellbook.MAX_COPIES], 18, UiTheme.GLOW, UiTheme.bold_font()))
	var total := Database.ids("spells").size()
	info.add_child(UiTheme.label("Known spells: %d / %d" % [book.known.size(), total], 18, UiTheme.TEXT_DIM))
	v.add_child(info)
	v.add_child(_wrap_label("You draw 4 cards each turn and cast one. Add copies of spells you rely on; remove ones you don't. Undiscovered spells are learned from Umbel, by levelling up, from scrolls and from the skill tree.", 15, UiTheme.TEXT_DIM))
	var grid := HFlowContainer.new()
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	v.add_child(_scroll(grid))
	for id: String in book.known:
		var sp := Database.spell(id)
		if sp == null:
			continue
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 4)
		var card := SpellCardView.new(sp, 0)
		card.interactive = false
		cell.add_child(card)
		var ctl := HBoxContainer.new()
		ctl.alignment = BoxContainer.ALIGNMENT_CENTER
		var minus := UiTheme.button("−", func() -> void:
			if not book.set_copies(id, book.copies(id) - 1):
				EventBus.notify("Your deck needs at least %d cards." % Spellbook.DECK_MIN, "warning")
			show_tab("spellbook"), 52)
		var count := UiTheme.label(" ×%d " % book.copies(id), 22, UiTheme.GOLD, UiTheme.title_font())
		var plus := UiTheme.button("+", func() -> void:
			if not book.set_copies(id, book.copies(id) + 1):
				EventBus.notify("Deck is full or at max copies.", "warning")
			show_tab("spellbook"), 52)
		ctl.add_child(minus)
		ctl.add_child(count)
		ctl.add_child(plus)
		cell.add_child(ctl)
		grid.add_child(cell)
	for i in maxi(0, total - book.known.size()):
		var unknown := PanelContainer.new()
		unknown.custom_minimum_size = SpellCardView.CARD_SIZE
		var st := UiTheme.panel_style(Color(0.08, 0.04, 0.14, 0.6), Color(0.4, 0.3, 0.6, 0.4), 18, 0)
		unknown.add_theme_stylebox_override("panel", st)
		var q := UiTheme.title("?", 64, Color(0.5, 0.4, 0.7, 0.6))
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		unknown.add_child(q)
		grid.add_child(unknown)
	return v


# ------------------------------------------------------------------ skills
func _build_skills() -> Control:
	var prof := Game.profile
	var tree: Dictionary = Database.skill_tree("fungal")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var left := _box(Color(tree.get("color", "#c44dff")))
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 10)
	left.add_child(_scroll(lv))
	lv.add_child(UiTheme.title(String(tree.get("name", "Skills")), 26))
	lv.add_child(UiTheme.label("Skill points available: %d" % prof.stats.skill_points, 19, UiTheme.GOLD, UiTheme.bold_font()))
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 12)
	lv.add_child(cols)
	for br: Variant in tree.get("branches", []):
		var branch: Dictionary = br
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 6)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UiTheme.label(String(branch["name"]), 17, UiTheme.GLOW, UiTheme.bold_font()))
		var nodes: Array = (tree.get("nodes", []) as Array).filter(func(n: Dictionary) -> bool: return n.get("branch") == branch["id"])
		nodes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("tier", 1)) < int(b.get("tier", 1)))
		for i in nodes.size():
			var node: Dictionary = nodes[i]
			var nid := String(node["id"])
			if i > 0:
				var link := UiTheme.label("│", 20, UiTheme.SUCCESS if prof.skills.is_unlocked(nid) else Color(0.4, 0.35, 0.55))
				link.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				col.add_child(link)
			var learned := prof.skills.is_unlocked(nid)
			var reason := prof.skills.check(tree, nid, prof.stats.skill_points, prof.stats.level)
			var b := UiTheme.button(("✓ " if learned else "") + String(node["name"]), func() -> void:
				_selected_skill = nid
				show_tab("skills"))
			b.custom_minimum_size = Vector2(0, 58)
			b.add_theme_font_size_override("font_size", 16)
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			var style := "selected" if learned else ("normal" if reason == "" else "disabled")
			b.add_theme_stylebox_override("normal", UiTheme.button_style(style))
			if nid == _selected_skill:
				b.add_theme_stylebox_override("normal", UiTheme.button_style("hover"))
			col.add_child(b)
		cols.add_child(col)
	var right := _box(UiTheme.GOLD)
	right.custom_minimum_size.x = 380
	row.add_child(right)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 10)
	right.add_child(rv)
	if _selected_skill == "":
		rv.add_child(_wrap_label(String(tree.get("description", "")), 18, UiTheme.TEXT_DIM))
		rv.add_child(_wrap_label("Earn a skill point each level. Choose a branch: spore damage, defense, healing or creature summoning.", 16, UiTheme.TEXT_DIM))
		return row
	var sel := SkillTreeState.find_node(tree, _selected_skill)
	rv.add_child(UiTheme.title(String(sel.get("name", "")), 24))
	rv.add_child(_wrap_label(String(sel.get("description", "")), 18))
	rv.add_child(UiTheme.label("Cost: %d point(s) · Requires level %d" % [int(sel.get("cost", 1)), int(sel.get("min_level", 1))], 15, UiTheme.TEXT_DIM))
	if prof.skills.is_unlocked(_selected_skill):
		rv.add_child(UiTheme.label("✓ Learned", 20, UiTheme.SUCCESS, UiTheme.bold_font()))
	else:
		var reason2 := prof.skills.check(tree, _selected_skill, prof.stats.skill_points, prof.stats.level)
		var learn := UiTheme.button("Learn", func() -> void:
			var err := prof.unlock_skill("fungal", _selected_skill)
			if err == "":
				EventBus.notify("Learned %s" % String(sel.get("name", "")), "spell")
				AudioManager.play_sfx("level_up", -6.0)
				EventBus.skill_unlocked.emit(_selected_skill)
			else:
				EventBus.notify(err, "warning")
			show_tab("skills"), 220)
		learn.disabled = reason2 != ""
		rv.add_child(learn)
		if reason2 != "":
			rv.add_child(UiTheme.label(reason2, 16, UiTheme.DANGER))
	return row


# ------------------------------------------------------------------ journal
func _build_journal() -> Control:
	var prof := Game.profile
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 8)
	for m: Array in [["quests", "Quests"], ["lore", "Lore"], ["bestiary", "Bestiary"]]:
		var id := String(m[0])
		var b := UiTheme.button(String(m[1]), func() -> void:
			_journal_mode = id
			_selected_entry = ""
			show_tab("journal"), 160)
		b.add_theme_stylebox_override("normal", UiTheme.button_style("selected" if id == _journal_mode else "normal"))
		modes.add_child(b)
	v.add_child(modes)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(row)
	var left := _box()
	left.custom_minimum_size.x = 380
	row.add_child(left)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	left.add_child(_scroll(list))
	var right := _box(UiTheme.GOLD)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	var detail := VBoxContainer.new()
	detail.add_theme_constant_override("separation", 10)
	right.add_child(_scroll(detail))
	match _journal_mode:
		"quests":
			_journal_quests(prof, list, detail)
		"lore":
			_journal_lore(prof, list, detail)
		"bestiary":
			_journal_bestiary(prof, list, detail)
	return v


func _entry_button(text: String, id: String, color: Color) -> Button:
	var b := UiTheme.button(text, func() -> void:
		_selected_entry = id
		show_tab("journal"))
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", color)
	if id == _selected_entry:
		b.add_theme_stylebox_override("normal", UiTheme.button_style("selected"))
	return b


func _journal_quests(prof: PlayerProfile, list: VBoxContainer, detail: VBoxContainer) -> void:
	var q := prof.quests
	var groups := [["Active", QuestData.State.ACTIVE, UiTheme.GLOW], ["Available", QuestData.State.AVAILABLE, UiTheme.GOLD], ["Completed", QuestData.State.COMPLETED, UiTheme.TEXT_DIM]]
	for g: Array in groups:
		var ids: Array = []
		for id: String in q.states.keys():
			if int(q.states[id]) == int(g[1]):
				ids.append(id)
		if ids.is_empty():
			continue
		list.add_child(UiTheme.label(String(g[0]), 17, g[2], UiTheme.bold_font()))
		for id: String in ids:
			var data := Database.quest(id)
			if data == null:
				continue
			var mark := "★ " if id == q.tracked else ""
			list.add_child(_entry_button("%s%s  [%s]" % [mark, data.title, data.category_name()], id, Color.WHITE if int(g[1]) != QuestData.State.COMPLETED else UiTheme.TEXT_DIM))
	if _selected_entry == "" or Database.quest(_selected_entry) == null:
		if q.tracked != "":
			_selected_entry = q.tracked
		else:
			detail.add_child(_wrap_label("Select a quest to read about it.", 17, UiTheme.TEXT_DIM))
			return
	var qd := Database.quest(_selected_entry)
	detail.add_child(UiTheme.title(qd.title, 28))
	detail.add_child(UiTheme.label("%s quest · %s" % [qd.category_name(), String(QuestData.State.keys()[q.get_state(qd.id)]).capitalize()], 15, UiTheme.TEXT_DIM))
	detail.add_child(_wrap_label(qd.description, 18))
	var cur := q.current_objective(qd.id)
	for o: QuestObjectiveData in qd.objectives:
		var done := q.is_objective_done(qd.id, o.id)
		if qd.sequential and not done and o != cur:
			continue
		var prog := " (%d/%d)" % [q.get_progress(qd.id, o.id), o.required_amount] if o.required_amount > 1 else ""
		detail.add_child(_wrap_label(("✓ " if done else "◆ ") + o.description + prog, 17, UiTheme.SUCCESS if done else UiTheme.GLOW))
	var rewards: PackedStringArray = []
	if qd.reward_xp > 0:
		rewards.append("%d XP" % qd.reward_xp)
	if qd.reward_glimmer > 0:
		rewards.append("%d glimmer" % qd.reward_glimmer)
	for id: String in qd.reward_items.keys():
		var d := Database.item(id)
		rewards.append(d.display_name if d else id)
	for sid: String in qd.reward_spells:
		var sp := Database.spell(sid)
		rewards.append("Spell: %s" % (sp.display_name if sp else sid))
	if qd.reward_skill_points > 0:
		rewards.append("%d skill point(s)" % qd.reward_skill_points)
	if not rewards.is_empty():
		detail.add_child(UiTheme.label("Rewards: " + ", ".join(rewards), 16, UiTheme.GOLD))
	if q.is_completed(qd.id) and qd.completion_text != "":
		detail.add_child(_wrap_label("“%s”" % qd.completion_text, 17, Color(0.85, 0.8, 1.0)))
	if q.is_active(qd.id) and q.tracked != qd.id:
		var qid := qd.id
		detail.add_child(UiTheme.button("Track this quest", func() -> void:
			q.tracked = qid
			EventBus.quest_tracker_changed.emit()
			show_tab("journal"), 260))


func _journal_lore(prof: PlayerProfile, list: VBoxContainer, detail: VBoxContainer) -> void:
	if prof.world.lore.is_empty():
		list.add_child(_wrap_label("No lore yet. Inspect strange stones, shrines and carvings.", 16, UiTheme.TEXT_DIM))
	for id: String in prof.world.lore:
		var e: Dictionary = prof.world.lore_entries.get(id, {"title": id.capitalize(), "text": ""})
		list.add_child(_entry_button(String(e["title"]), id, Color(0.8, 0.85, 1.0)))
	if _selected_entry != "" and prof.world.lore_entries.has(_selected_entry):
		var e2: Dictionary = prof.world.lore_entries[_selected_entry]
		detail.add_child(UiTheme.title(String(e2["title"]), 26))
		detail.add_child(_wrap_label(String(e2["text"]), 18))
	else:
		detail.add_child(_wrap_label("Discovered places: %d" % prof.world.discovered_areas.size(), 17, UiTheme.TEXT_DIM))


func _journal_bestiary(prof: PlayerProfile, list: VBoxContainer, detail: VBoxContainer) -> void:
	if prof.world.creatures_seen.is_empty():
		list.add_child(_wrap_label("Creatures you face in battle are recorded here.", 16, UiTheme.TEXT_DIM))
	for id: String in prof.world.creatures_seen:
		var cd := Database.creature(id)
		if cd:
			list.add_child(_entry_button("%s  %s" % [ElementChart.glyph(cd.element), cd.display_name], id, ElementChart.color(cd.element).lightened(0.3)))
	var sel := Database.creature(_selected_entry) if _selected_entry != "" else null
	if sel:
		detail.add_child(UiTheme.title(sel.display_name, 26))
		detail.add_child(UiTheme.label("%s · Level %d · %d health · %d defense" % [ElementChart.display_name(sel.element), sel.level, sel.max_health, sel.defense], 16, UiTheme.TEXT_DIM))
		detail.add_child(_wrap_label(sel.description, 18))
		detail.add_child(_wrap_label(sel.lore, 17, Color(0.85, 0.8, 1.0)))
		var weak := ""
		for el: String in ElementChart.ELEMENTS:
			if ElementChart.multiplier(el, sel.element) > 1.2:
				weak = ElementChart.display_name(el)
		if weak != "":
			detail.add_child(UiTheme.label("Weak to: %s magic" % weak, 17, UiTheme.SUCCESS, UiTheme.bold_font()))
		var abil: PackedStringArray = []
		for a: SpellData in sel.abilities:
			abil.append(a.display_name)
		detail.add_child(_wrap_label("Abilities: " + ", ".join(abil), 16, UiTheme.TEXT_DIM))


# ------------------------------------------------------------------ map
func _build_map() -> Control:
	var v := VBoxContainer.new()
	var mv := MapView.new()
	mv.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mv.custom_minimum_size = Vector2(400, 400)
	v.add_child(mv)
	var root := get_tree().get_first_node_in_group("game_root")
	var region: Region = root.get("region") if root else null
	mv.setup(region)
	v.add_child(UiTheme.label("◆ discovered places   ● people   ◎ tracked objective   ▲ you", 15, UiTheme.TEXT_DIM))
	return v
