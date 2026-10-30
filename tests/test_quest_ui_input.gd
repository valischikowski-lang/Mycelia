extends TestCase
## Regression tests for the "quest tracker blocks jump/sprint" bug.
## Root cause: Godot emulates a mouse click from the first finger; the old
## tracker was clickable (it opened the journal) and grew tall with long
## quest text, so taps on jump/sprint were also clicks on the tracker.

const LONG := "Follow the whispering path past the leaning houses of Crookhollow, under the lantern posts that hum when nobody is watching, across the cobbles that rearrange themselves at night, and find the place where the moon once fell asleep in the grass and never fully woke up again, then listen very carefully for a very long time."
const SIZES := [Vector2(1280, 720), Vector2(1280, 960), Vector2(1280, 889), Vector2(1280, 592), Vector2(1600, 720), Vector2(1280, 1024)]

var holder: Control
var hud: HUD
var touch: TouchControls
var journal_opened: int = 0


func before_each() -> void:
	Game._bind(PlayerProfile.new(Database))
	Game.profile.new_game()
	_register_quest("qa_long", "The Exceedingly Long and Winding Quest of the Sleeping Moon Beneath Crookhollow", 3)
	_register_quest("qa_second", "Another Quest With a Title That Simply Refuses to End Politely", 1)
	_register_quest("qa_third", "A Third Quest", 2)
	for id: String in ["qa_long", "qa_second", "qa_third"]:
		Game.profile.quests.start(id)
	Game.profile.quests.tracked = "qa_long"
	TouchInput.reset()
	journal_opened = 0


func after_each() -> void:
	if is_instance_valid(holder):
		holder.queue_free()
	TouchInput.reset()
	Database.reload()
	Game.profile = null


func _register_quest(id: String, title: String, n: int) -> void:
	var q := QuestData.new()
	q.id = id
	q.title = title
	q.description = LONG + " " + LONG
	var objs: Array[QuestObjectiveData] = []
	for i in n:
		var o := QuestObjectiveData.new()
		o.id = "o%d" % i
		o.description = LONG
		o.type = QuestObjectiveData.Type.VISIT
		o.target_id = "nowhere_%d" % i
		o.required_amount = 1 if i != 1 else 5
		objs.append(o)
	q.objectives = objs
	Database.register("quests", q)


func _build(sz: Vector2) -> void:
	if is_instance_valid(holder):
		holder.free()
	holder = Control.new()
	holder.size = sz
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(holder)
	hud = HUD.new()
	holder.add_child(hud)
	touch = TouchControls.new()
	touch.reserved_changed.connect(hud.set_reserved_rects)
	holder.add_child(touch)
	hud.set_reserved_rects(touch.reserved_rects())
	hud.menu_button.connect(func(_t: String) -> void: journal_opened += 1)
	touch.interact_available = true
	hud.refresh_tracker()
	for i in 3:
		await tree.process_frame


func _check_layout(label: String) -> void:
	var tr := hud.tracker_rect()
	check(tr.size.y <= HUD.TRACKER_MAX_HEIGHT + 1.0, "%s: tracker height capped (%.0f)" % [label, tr.size.y])
	check(tr.size.y > 20.0, "%s: tracker still shows something" % label)
	for r: Rect2 in touch.reserved_rects():
		check(not tr.intersects(r), "%s: tracker %s clear of control %s" % [label, tr, r])
	# Nothing but real buttons may take pointer input inside the HUD.
	var blockers := _input_takers(hud)
	for c: Control in blockers:
		check(c is BaseButton, "%s: non-button %s takes input" % [label, c.get_class()])
		for k: String in touch._buttons.keys():
			var b: Dictionary = touch._buttons[k]
			check(not c.get_global_rect().has_point(b["pos"]), "%s: %s covers the %s button" % [label, c.name, k])


func _input_takers(c: Node) -> Array[Control]:
	var out: Array[Control] = []
	for ch in c.get_children():
		if ch is Control and (ch as Control).is_visible_in_tree():
			var cc := ch as Control
			if cc.mouse_filter != Control.MOUSE_FILTER_IGNORE and cc.name != "LorePanel" and not cc.is_ancestor_of(hud._lore_panel) and not hud._lore_panel.is_ancestor_of(cc) and cc != hud._lore_panel:
				out.append(cc)
			out.append_array(_input_takers(ch))
	return out


func test_tracker_layout_all_screen_sizes() -> void:
	for sz: Vector2 in SIZES:
		await _build(sz)
		_check_layout("%dx%d" % [sz.x, sz.y])
		# Text is truncated, never allowed to grow without bound.
		check(hud._tracker_objective.max_lines_visible == 2, "objective capped at two lines")
		check(hud._tracker_title.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS, "title ellipsized")


func test_tracker_states_stay_bounded() -> void:
	await _build(Vector2(1280, 889))
	var q := Game.profile.quests
	# Switch tracked quest, advance, complete, restart.
	for step in ["switch", "advance", "complete", "restart"]:
		match step:
			"switch":
				q.tracked = "qa_third"
			"advance":
				q.tracked = "qa_long"
				q.complete_objective("qa_long", "o0")
			"complete":
				q.complete_objective("qa_long", "o1")
				q.complete_objective("qa_long", "o2")
			"restart":
				q.fail("qa_second")
				q.progress.erase("qa_second")
				q._set_state("qa_second", 0)
				q.start("qa_second")
		EventBus.quest_tracker_changed.emit()
		await tree.process_frame
		_check_layout("state " + step)
	check(q.is_completed("qa_long"), "long quest completed")
	check(hud._tracker_panel.visible, "tracker visible with remaining quests")


## Input.parse_input_event takes window coordinates (it also performs the
## touch-to-mouse emulation we need to exercise); convert from viewport space.
func _to_window(p: Vector2) -> Vector2:
	return (host.get_viewport() as Window).get_final_transform() * p


func _touch(index: int, pos: Vector2, pressed: bool) -> void:
	var t := InputEventScreenTouch.new()
	t.index = index
	t.position = _to_window(pos)
	t.pressed = pressed
	Input.parse_input_event(t)
	await tree.process_frame
	await tree.process_frame


func _drag(index: int, pos: Vector2, rel: Vector2) -> void:
	var d := InputEventScreenDrag.new()
	d.index = index
	d.position = _to_window(pos)
	d.relative = rel
	Input.parse_input_event(d)
	await tree.process_frame
	await tree.process_frame


func test_every_touch_input_works_with_long_quest() -> void:
	var vp := host.get_viewport().get_visible_rect().size
	await _build(vp)
	var b := touch._buttons
	# Jump, pressed as the first finger (the one Godot turns into a mouse).
	await _touch(0, b["jump"]["pos"], true)
	check(TouchInput.consume_jump(), "jump registered")
	await _touch(0, b["jump"]["pos"], false)
	# Sprint toggles on, then off.
	await _touch(0, b["sprint"]["pos"], true)
	check(TouchInput.sprint_held, "sprint toggled on")
	await _touch(0, b["sprint"]["pos"], false)
	await _touch(0, b["sprint"]["pos"], true)
	check(not TouchInput.sprint_held, "sprint toggled off")
	await _touch(0, b["sprint"]["pos"], false)
	# Interact.
	await _touch(0, b["interact"]["pos"], true)
	check(TouchInput.consume_interact(), "interact registered")
	await _touch(0, b["interact"]["pos"], false)
	# Movement with the stick while another finger looks around ON the tracker.
	var stick := Vector2(200, vp.y - 200)
	await _touch(0, stick, true)
	await _drag(0, stick + Vector2(60, -40), Vector2(60, -40))
	check(TouchInput.move.length() > 0.3, "joystick moves (%s)" % TouchInput.move)
	var on_tracker := hud.tracker_rect().get_center()
	await _touch(1, on_tracker, true)
	await _drag(1, on_tracker + Vector2(-40, 10), Vector2(-40, 10))
	check(TouchInput.consume_look().length() > 0.0, "camera look works when dragging over the quest tracker")
	await _touch(1, on_tracker, false)
	await _touch(0, stick, false)
	check(TouchInput.move == Vector2.ZERO, "joystick released")
	# First finger directly on the tracker: camera look, never the journal.
	await _touch(0, on_tracker, true)
	await _drag(0, on_tracker + Vector2(30, 0), Vector2(30, 0))
	check(TouchInput.consume_look().length() > 0.0, "look drag starting on the tracker")
	await _touch(0, on_tracker, false)
	eq(journal_opened, 0, "no gameplay touch opened the journal")
	# The real journal button still works (explicit tap on it).
	var journal_btn: Control = null
	for n in tree.get_nodes_in_group("hud_button"):
		if hud.is_ancestor_of(n) and (n as Button).text.contains("Journal"):
			journal_btn = n
	check(journal_btn != null, "journal button exists")
	if journal_btn:
		var c := journal_btn.get_global_rect().get_center()
		await _touch(0, c, true)
		await _touch(0, c, false)
		eq(journal_opened, 1, "journal button opens the quest log")
