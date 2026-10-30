class_name TouchInput
extends RefCounted
## Shared virtual input state written by TouchControls and read by the
## player controller. Keeps the controller independent of the touch UI.

static var move: Vector2 = Vector2.ZERO
static var look_delta: Vector2 = Vector2.ZERO
static var sprint_held: bool = false
static var _jump_queued: bool = false
static var _interact_queued: bool = false
static var attack_held: bool = false
static var block_held: bool = false
static var bow_held: bool = false
static var _queued: Dictionary = {}


## One-shot combat presses: "dodge", "lock", "switch", "ability_1".."ability_5".
static func queue(action: String) -> void:
	_queued[action] = true


static func consume(action: String) -> bool:
	if _queued.has(action):
		_queued.erase(action)
		return true
	return false


static func queue_jump() -> void:
	_jump_queued = true


static func queue_interact() -> void:
	_interact_queued = true


static func consume_jump() -> bool:
	var j := _jump_queued
	_jump_queued = false
	return j


static func consume_interact() -> bool:
	var i := _interact_queued
	_interact_queued = false
	return i


static func consume_look() -> Vector2:
	var d := look_delta
	look_delta = Vector2.ZERO
	return d


static func reset() -> void:
	move = Vector2.ZERO
	look_delta = Vector2.ZERO
	sprint_held = false
	_jump_queued = false
	_interact_queued = false
	attack_held = false
	block_held = false
	bow_held = false
	_queued.clear()
