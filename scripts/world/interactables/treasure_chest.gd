class_name TreasureChest
extends Interactable
## A chest that opens once per save. Optionally guarded by a ClassSeal: it
## can't be opened until the seal is broken. Loot: {"items": {id: n},
## "glimmer": n, "xp": n, "mana_essence": n} (Mana Essence buys Learning Paths).

@export var chest_id: String = ""
@export var loot: Dictionary = {}
## "common", "rare" or "legendary" — only changes the look.
@export var grade: String = "common"

var seal: ClassSeal
var _lid: Node3D
var _opened: bool = false


func _after_ready() -> void:
	prompt = "Open"
	display_name = "Treasure Chest" if grade == "common" else ("Ornate Chest" if grade == "rare" else "Legendary Chest")
	marker_color = Color(1.0, 0.8, 0.35)
	_build_visual()
	if Game.profile and Game.profile.world.is_consumed(chest_id):
		_set_open(true)


func _build_visual() -> void:
	var wood := Color("#2a1a12") if grade != "legendary" else Color("#1a1030")
	var band := Color("#c9a04a") if grade != "legendary" else Color("#ffe36a")
	var kit := MeshKit.new()
	kit.ellipsoid(Vector3(0, 0.32, 0), Vector3(0.55, 0.32, 0.38), Color(wood.r, wood.g, wood.b, 0.02), 4, 8)
	for x: float in [-0.35, 0.0, 0.35]:
		kit.ellipsoid(Vector3(x, 0.32, 0), Vector3(0.05, 0.34, 0.4), Color(band.r, band.g, band.b, 0.15), 3, 8)
	var body := MeshInstance3D.new()
	body.mesh = kit.commit(MaterialLib.organic("chest", {"emission": 1.0, "pulse": 0.0, "rim": Color(1.0, 0.8, 0.4), "rim_strength": 0.4}))
	add_child(body)
	_lid = Node3D.new()
	_lid.position = Vector3(0, 0.55, -0.36)
	add_child(_lid)
	var lk := MeshKit.new()
	lk.ellipsoid(Vector3(0, 0.05, 0.36), Vector3(0.56, 0.18, 0.39), Color(wood.r * 1.3, wood.g * 1.3, wood.b * 1.3, 0.03), 4, 8)
	lk.ellipsoid(Vector3(0, 0.0, 0.76), Vector3(0.08, 0.1, 0.04), Color(band.r, band.g, band.b, 0.9), 3, 6)
	var lid := MeshInstance3D.new()
	lid.mesh = lk.commit(MaterialLib.organic("chest", {}))
	_lid.add_child(lid)
	var glow := OmniLight3D.new()
	glow.light_color = band
	glow.light_energy = 0.8 if grade == "common" else 1.6
	glow.omni_range = 3.5
	glow.position.y = 0.8
	add_child(glow)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.2, 0.9, 0.9)
	cs.shape = box
	cs.position.y = 0.45
	var sb := StaticBody3D.new()
	sb.add_child(cs)
	add_child(sb)


func can_interact(by: Node) -> bool:
	return super.can_interact(by) and not _opened and (seal == null or seal.is_open())


func get_prompt() -> String:
	return super.get_prompt()


func _on_interact(_by: Node) -> void:
	_set_open(false)
	var prof := Game.profile
	if prof == null:
		return
	prof.world.consume(chest_id)
	var summary := prof.grant_rewards(loot)
	var mana := int(loot.get("mana_essence", 0))
	var parts := PackedStringArray()
	for id: String in (summary.get("items", {}) as Dictionary).keys():
		var d := Database.item(id)
		parts.append("%s ×%d" % [d.display_name if d else id, int(summary["items"][id])])
		EventBus.item_collected.emit(id, int(summary["items"][id]))
	if int(summary.get("glimmer", 0)) > 0:
		parts.append("%d glimmer" % int(summary["glimmer"]))
	if mana > 0:
		parts.append("%d Mana Essence" % mana)
	EventBus.notify("Chest: " + (", ".join(parts) if not parts.is_empty() else "empty... except for a moth."), "item")
	EventBus.object_activated.emit(chest_id)
	AudioManager.play_sfx("pickup")
	RtFx.burst(get_parent(), global_position + Vector3.UP, Color(1.0, 0.85, 0.4), 30, 0.15, 4.0)


func _set_open(instant: bool) -> void:
	_opened = true
	set_enabled(false)
	if instant:
		_lid.rotation.x = -1.9
	else:
		create_tween().tween_property(_lid, "rotation:x", -1.9, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
