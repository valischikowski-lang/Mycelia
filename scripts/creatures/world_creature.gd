class_name WorldCreature
extends Node3D
## A creature roaming the exploration world. Hostile creatures notice the
## player and approach; touching them starts their encounter. Neutral ones
## wander and can be challenged through an interaction prompt.

signal engaged(creature: WorldCreature)

enum State { IDLE, WANDER, NOTICE, CHASE, RETURN, ENGAGED }

@export var creature_id: String = "sporeling"
@export var encounter_id: String = "enc_sporeling"
@export var home_radius: float = 10.0
@export var aggro_radius: float = 9.0
@export var engage_distance: float = 1.9
@export var move_speed: float = 2.2
@export var chase_speed: float = 4.2
## Persistent id for unique encounters (already-won ones won't spawn).
@export var unique_id: String = ""

var data: CreatureData
var rig: CreatureRig
var terrain: DreamTerrain
var state: State = State.IDLE
var home: Vector3
var _target: Vector3
var _timer: float = 0.0
var _player: Node3D
var _cooldown: float = 0.0
var _notice_label: Label3D


func _ready() -> void:
	add_to_group("world_creature")
	data = Database.creature(creature_id)
	if data == null:
		queue_free()
		return
	if unique_id != "" and Game.profile and Game.profile.world.won_encounters.has(unique_id):
		queue_free()
		return
	rig = CreatureBuilder.build(data.visual_kind, data.tint)
	rig.scale = Vector3.ONE * data.visual_scale
	add_child(rig)
	home = global_position
	_target = home
	_timer = randf_range(1.0, 3.0)
	_notice_label = Label3D.new()
	_notice_label.text = "!"
	_notice_label.font_size = 96
	_notice_label.pixel_size = 0.006
	_notice_label.modulate = Color(1.0, 0.4, 0.6)
	_notice_label.outline_size = 12
	_notice_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_notice_label.position = Vector3(0, 1.6 * data.visual_scale + 0.5, 0)
	_notice_label.visible = false
	add_child(_notice_label)
	if data.world_behavior == "neutral":
		var it := ChallengeInteract.new()
		it.prompt = "Challenge"
		it.display_name = data.display_name
		it.radius = 1.4
		it.marker_height = 2.2
		it.creature = self
		it.position = Vector3(0, 0.8, 0)
		add_child(it)


func _physics_process(delta: float) -> void:
	if state == State.ENGAGED or data == null:
		return
	_cooldown -= delta
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
	var to_player := INF
	if _player:
		to_player = global_position.distance_to(_player.global_position)
	if to_player > 70.0:
		rig.walking = false
		return
	var hostile := data.world_behavior == "hostile"
	match state:
		State.IDLE:
			rig.walking = false
			_timer -= delta
			if _timer <= 0.0:
				var a := randf() * TAU
				_target = home + Vector3(cos(a), 0, sin(a)) * randf_range(2.0, home_radius)
				state = State.WANDER
		State.WANDER:
			if _move_to(_target, move_speed, delta):
				state = State.IDLE
				_timer = randf_range(1.5, 4.0)
		State.NOTICE:
			rig.walking = false
			_timer -= delta
			if _player:
				rig.face_towards(_player.global_position, true)
			if _timer <= 0.0:
				_notice_label.visible = false
				state = State.CHASE
		State.CHASE:
			if _player == null or to_player > aggro_radius * 1.8 or global_position.distance_to(home) > home_radius * 3.0:
				state = State.RETURN
			elif to_player <= engage_distance and _cooldown <= 0.0:
				_engage()
			else:
				_move_to(_player.global_position, chase_speed, delta)
		State.RETURN:
			if _move_to(home, move_speed * 1.3, delta):
				state = State.IDLE
				_timer = 2.0
	if hostile and state in [State.IDLE, State.WANDER] and to_player < aggro_radius and _cooldown <= 0.0 and Game.session_active and not Game.in_combat:
		if _player is PlayerController and (_player as PlayerController).input_enabled:
			state = State.NOTICE
			_timer = 0.7
			_notice_label.visible = true
			AudioManager.play_at(_voice(), global_position, get_parent(), -4.0)


func _move_to(target: Vector3, speed: float, delta: float) -> bool:
	var flat := Vector3(target.x - global_position.x, 0, target.z - global_position.z)
	var d := flat.length()
	if d < 0.4:
		rig.walking = false
		return true
	rig.walking = true
	var step := flat.normalized() * minf(speed * delta, d)
	var p := global_position + step
	if terrain:
		p.y = terrain.height_at(p.x, p.z)
		if p.y < terrain.water_level - 0.2:
			# Creatures don't wade into the lake; pick another target.
			_target = home
			return true
	global_position = p
	# Models face +Z, so look "away" from the opposite direction.
	var want := Basis.looking_at(-flat.normalized(), Vector3.UP)
	rig.basis = rig.basis.orthonormalized().slerp(want, minf(1.0, delta * 8.0)).scaled(Vector3.ONE * data.visual_scale)
	return false


func _voice() -> String:
	match data.visual_kind:
		"crystal_beetle":
			return "beetle_click"
		"dream_fox":
			return "fox_yip"
		"bloom_guardian":
			return "guardian_groan"
		"spore_golem":
			return "golem_rumble"
	return "sporeling_chirp"


func _engage() -> void:
	state = State.ENGAGED
	rig.walking = false
	engaged.emit(self)
	EventBus.combat_requested.emit(encounter_id, self)


## Called by the combat manager after combat ends.
func on_combat_result(won: bool, fled: bool) -> void:
	if won:
		if unique_id != "" and Game.profile:
			Game.profile.world.won_encounters[unique_id] = true
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector3.ONE * 0.01, 0.4)
		tw.tween_callback(queue_free)
		return
	# Lost or fled: back off for a while so the player can get away.
	state = State.RETURN
	_cooldown = 8.0 if fled else 12.0
	_notice_label.visible = false
	global_position = home


class ChallengeInteract extends Interactable:
	var creature: WorldCreature

	func _on_interact(_by: Node) -> void:
		if creature and creature.state != WorldCreature.State.ENGAGED and not Game.in_combat:
			creature._engage()
