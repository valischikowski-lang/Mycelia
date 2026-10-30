class_name CombatInput
extends RefCounted
## One frame of combat intent, gathered from the InputMap (keyboard, mouse,
## gamepad) and TouchInput. Held actions are levels, the rest are edges.

var attack: bool = false
var block: bool = false
var bow: bool = false
var dodge: bool = false
var lock: bool = false
var switch_weapon: bool = false
var abilities: Array[bool] = [false, false, false, false, false]
## World-space direction of the movement stick (for dodges).
var move_dir: Vector3 = Vector3.ZERO


static func gather(basis: Basis, move: Vector2) -> CombatInput:
	var c := CombatInput.new()
	# On touch screens Godot emulates a mouse from the first finger; the
	# mouse-bound actions must not fire from joystick or look drags.
	var mouse_ok := not Settings.uses_touch()
	c.attack = (mouse_ok and Input.is_action_pressed("attack")) or TouchInput.attack_held
	c.block = (mouse_ok and Input.is_action_pressed("block")) or TouchInput.block_held
	c.bow = Input.is_action_pressed("aim_bow") or TouchInput.bow_held
	c.dodge = Input.is_action_just_pressed("dodge") or TouchInput.consume("dodge")
	c.lock = (mouse_ok and Input.is_action_just_pressed("lock_on")) or TouchInput.consume("lock")
	c.switch_weapon = Input.is_action_just_pressed("switch_weapon") or TouchInput.consume("switch")
	for i in 5:
		c.abilities[i] = Input.is_action_just_pressed("ability_%d" % (i + 1)) or TouchInput.consume("ability_%d" % (i + 1))
	var d := basis * Vector3(move.x, 0, move.y)
	d.y = 0.0
	c.move_dir = d.normalized() if d.length() > 0.1 else Vector3.ZERO
	return c
