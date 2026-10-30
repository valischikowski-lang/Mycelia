class_name PlayerAvatar
extends Node3D
## The player's visible body: the class rig plus the equipped weapon, shield
## and bow. Shown by the combat camera (third person) and the class select.
## Animations are procedural tweens on the rig and its weapon hand.

var class_id: String = ""
var rig: CreatureRig
var hand: Node3D
var weapon: Node3D
var offhand: Node3D
var bow: Node3D
var _rest_hand: Transform3D
var _tw: Tween
var blocking: bool = false


static func create(cls: ClassData, equipment: Dictionary) -> PlayerAvatar:
	var a := PlayerAvatar.new()
	a.name = "Avatar"
	a.class_id = cls.id if cls else ""
	var opts: Dictionary = cls.rig_opts.duplicate() if cls else {}
	opts["no_staff"] = true
	a.rig = CreatureBuilder.build(cls.rig_kind if cls else "dreamer", Color.WHITE, opts)
	a.add_child(a.rig)
	a.hand = a.rig.find_child("Hand", true, false) as Node3D
	if a.hand == null:
		a.hand = Node3D.new()
		a.hand.position = Vector3(0.3, 0.9, 0.3)
		a.rig.get_node("Body").add_child(a.hand)
	a._rest_hand = a.hand.transform
	a.refresh_equipment(equipment)
	return a


func refresh_equipment(equipment: Dictionary) -> void:
	for n: Node3D in [weapon, offhand, bow]:
		if is_instance_valid(n):
			n.queue_free()
	weapon = _attach(String(equipment.get("staff", "")), hand, Transform3D(Basis(Vector3.RIGHT, 1.1), Vector3.ZERO))
	var off_parent := Node3D.new()
	off_parent.position = Vector3(-hand.position.x, hand.position.y + 0.1, hand.position.z)
	rig.get_node("Body").add_child(off_parent)
	offhand = _attach(String(equipment.get("offhand", "")), off_parent, Transform3D(Basis(Vector3.UP, -1.1), Vector3.ZERO))
	var back := Node3D.new()
	back.position = Vector3(0, hand.position.y + 0.35, -0.3)
	rig.get_node("Body").add_child(back)
	bow = _attach(String(equipment.get("ranged", "")), back, Transform3D(Basis(Vector3.FORWARD, 0.6), Vector3.ZERO))


func _attach(item_id: String, parent: Node3D, xf: Transform3D) -> Node3D:
	if item_id == "":
		return null
	var d := Database.item(item_id)
	if d == null:
		return null
	var m := WeaponModels.build(d)
	m.transform = xf
	parent.add_child(m)
	return m


func _anim() -> Tween:
	if _tw and _tw.is_valid():
		_tw.kill()
	hand.transform = _rest_hand
	_tw = create_tween()
	return _tw


## Light/heavy swing: wind up, strike, return. `speed` scales timings.
func swing(heavy: bool, speed: float = 1.0) -> void:
	var t := _anim()
	var wind := (0.18 if heavy else 0.07) / speed
	var strike := (0.14 if heavy else 0.08) / speed
	t.tween_property(hand, "rotation", _rest_hand.basis.get_euler() + Vector3(-1.6 if heavy else -0.9, 0.5, 0.0), wind).set_trans(Tween.TRANS_SINE)
	t.tween_property(hand, "rotation", _rest_hand.basis.get_euler() + Vector3(1.3, -0.7, 0.0), strike).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_property(hand, "transform", _rest_hand, 0.2 / speed)
	if rig:
		rig.play_attack(global_position - global_basis.z * 2.0)


func cast() -> void:
	var t := _anim()
	t.tween_property(hand, "position", _rest_hand.origin + Vector3(0, 0.35, 0.15), 0.12)
	t.tween_property(hand, "transform", _rest_hand, 0.3)
	if rig:
		rig.play_cast()


func set_block(on: bool) -> void:
	if on == blocking:
		return
	blocking = on
	var t := _anim()
	var target := _rest_hand
	if on:
		target = Transform3D(Basis(Vector3.FORWARD, 0.9) * Basis(Vector3.RIGHT, 0.2), _rest_hand.origin + Vector3(-0.15, 0.3, 0.1))
	t.tween_property(hand, "transform", target, 0.08)
	if is_instance_valid(offhand) and offhand.get_parent():
		var op := offhand.get_parent() as Node3D
		t.parallel().tween_property(op, "position:z", 0.45 if on else hand.position.z, 0.08)


func dodge_spin() -> void:
	var t := create_tween()
	t.tween_property(rig, "rotation:y", rig.rotation.y + TAU, 0.3)
	t.tween_callback(func() -> void: rig.rotation.y = 0.0)


func hurt() -> void:
	if rig:
		rig.play_hit()
