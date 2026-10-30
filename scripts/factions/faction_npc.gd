class_name FactionNPC
extends NPC
## A member of one of the four callings' factions. Reacts to the player's
## standing: friendly banter for kin, wary remarks for outsiders, and guards
## who warn trespassers in the village core — twice — before they fight.
## Disguises, reputation and neutral ground keep the world explorable.
## Roles: "guard" (patrols), "villager" (wanders, chats), "merchant" and
## "mentor" (stay at their post; talk opens their dialogue/shop).

const GUARD_CREATURES := {
	"unseen_covenant": "covenant_guard", "lantern_choir": "choir_warden",
	"spiral_concordance": "concordance_sentinel", "rootborn_hold": "hold_guardian",
}
const WARN_1 := 0.0
const WARN_2 := 7.0
const ATTACK := 13.0

@export var faction_id: String = ""
@export var role: String = "villager"
@export var wander_radius: float = 6.0
@export var patrol: PackedVector3Array = []
## The village core guards protect (global position, radius).
@export var core_center: Vector3 = Vector3.ZERO
@export var core_radius: float = 0.0
@export var walk_speed: float = 1.3

var home: Vector3
var _bubble: Label3D
var _bark_cd: float = 0.0
var _move_target: Vector3
var _idle: float = 0.0
var _patrol_i: int = 0
var _trespass: float = -1.0
var _warned: int = 0
var _fighter: WorldCreature
var _hidden_for: float = 0.0
var _region: Region
var _chat_partner: FactionNPC
var _chat_cd: float = 0.0

const CHATS := [
	["Did you hear the hollow ones near the lake?", "Every night closer. Every night quieter."],
	["The moon smiled at me yesterday.", "It does that. Don't smile back."],
	["Have you seen the Keeper lately?", "Umbel? Still talking to his mushrooms."],
	["Something drinks the dreams under the meadow.", "Then we'll have to stay awake."],
]


func _ready() -> void:
	super._ready()
	add_to_group("faction_npc")
	home = global_position
	_move_target = home
	_idle = randf_range(1.0, 4.0)
	_bubble = Label3D.new()
	_bubble.font = UiTheme.body_font()
	_bubble.font_size = 34
	_bubble.outline_size = 8
	_bubble.pixel_size = 0.005
	_bubble.width = 520
	_bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.modulate = Color(1.0, 0.95, 0.85)
	_bubble.outline_modulate = Color(0.1, 0.0, 0.15, 0.9)
	_bubble.position = Vector3(0, _label_height() + 0.9, 0)
	_bubble.visible = false
	add_child(_bubble)
	_region = get_tree().get_first_node_in_group("region") as Region


func standing() -> String:
	var p := Game.profile
	if p == null:
		return "neutral"
	return p.factions.standing(faction_id, p.play_time)


func say(text: String, seconds: float = 3.5) -> void:
	_bubble.text = text
	_bubble.visible = true
	_bubble.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(seconds)
	tw.tween_property(_bubble, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func() -> void: _bubble.visible = false)


func _bark() -> void:
	var lines: Array = (FactionState.info(faction_id).get("barks", {}) as Dictionary).get(standing(), [])
	if not lines.is_empty():
		say(String(lines[randi() % lines.size()]))


func _process(delta: float) -> void:
	super._process(delta)
	if not visible:
		_hidden_for += delta
		if not is_instance_valid(_fighter) and _hidden_for > 60.0:
			_restore()
		return
	if _player == null:
		return
	var d := global_position.distance_to(_player.global_position)
	_bark_cd -= delta
	_chat_cd -= delta
	if d < 6.0 and _bark_cd <= 0.0 and role != "guard":
		_bark_cd = randf_range(9.0, 16.0)
		_bark()
	match role:
		"guard":
			_guard_logic(delta, d)
		"villager":
			_wander(delta, d)
	if role == "villager" and d > 12.0 and _chat_cd <= 0.0:
		_try_chat()


func _try_chat() -> void:
	_chat_cd = randf_range(18.0, 30.0)
	for n in get_tree().get_nodes_in_group("faction_npc"):
		var o := n as FactionNPC
		if o and o != self and o.faction_id == faction_id and o.visible and o.global_position.distance_to(global_position) < 9.0:
			var c: Array = CHATS[randi() % CHATS.size()]
			say(String(c[0]))
			var other := o
			get_tree().create_timer(2.5).timeout.connect(func() -> void:
				if is_instance_valid(other):
					other.say(String(c[1])))
			return


func _walk_to(target: Vector3, delta: float) -> bool:
	var flat := Vector3(target.x - global_position.x, 0, target.z - global_position.z)
	if flat.length() < 0.3:
		if rig:
			rig.walking = false
		return true
	var p := global_position + flat.normalized() * minf(flat.length(), walk_speed * delta)
	if _region:
		p.y = _region.ground(p.x, p.z)
	global_position = p
	if rig:
		rig.walking = true
		rig.basis = rig.basis.orthonormalized().slerp(Basis.looking_at(-flat.normalized(), Vector3.UP), minf(1.0, delta * 5.0))
	return false


func _wander(delta: float, player_dist: float) -> void:
	if player_dist < 3.5:
		if rig:
			rig.walking = false
		return
	_idle -= delta
	if _idle > 0.0:
		return
	if _walk_to(_move_target, delta):
		var a := randf() * TAU
		_move_target = home + Vector3(cos(a), 0, sin(a)) * randf_range(1.0, wander_radius)
		_idle = randf_range(2.0, 6.0)


func _guard_logic(delta: float, player_dist: float) -> void:
	var st := standing()
	var inside := core_radius > 0.0 and Vector2(_player.global_position.x - core_center.x, _player.global_position.z - core_center.z).length() < core_radius
	if inside and st in ["wary", "hostile"]:
		turn_to_player = true
		if _trespass < 0.0:
			_trespass = 0.0
			_warned = 0
		_trespass += delta
		if st == "hostile" or _trespass >= ATTACK:
			_attack()
			return
		if _warned == 0:
			_warned = 1
			say(String(FactionState.info(faction_id).get("warn", "Turn back.")), 5.0)
			EventBus.notify("%s: \"Turn back, outsider.\" (Leave, wear a disguise, or earn their trust.)" % display_name, "warning")
		elif _warned == 1 and _trespass >= WARN_2:
			_warned = 2
			say("Last warning.", 4.0)
			EventBus.notify("%s draws a weapon. Last warning!" % display_name, "warning")
		if rig:
			rig.walking = false
		return
	_trespass = -1.0
	if player_dist < 6.0 and _bark_cd <= 0.0:
		_bark_cd = randf_range(10.0, 18.0)
		_bark()
	# Patrol.
	if patrol.is_empty():
		return
	turn_to_player = player_dist < 4.0
	if player_dist < 2.5:
		if rig:
			rig.walking = false
		return
	if _walk_to(patrol[_patrol_i], delta):
		_patrol_i = (_patrol_i + 1) % patrol.size()


## The guard steps out of the NPC role and fights as a real-time enemy.
func _attack() -> void:
	if is_instance_valid(_fighter):
		return
	var cid := String(GUARD_CREATURES.get(faction_id, ""))
	if cid == "" or Database.creature(cid) == null:
		return
	_fighter = WorldCreature.new()
	_fighter.creature_id = cid
	_fighter.encounter_id = ""
	_fighter.terrain = _region.terrain if _region else null
	_fighter.hostile_override = true
	_fighter.home_radius = core_radius
	get_parent().add_child(_fighter)
	_fighter.global_position = global_position
	_fighter.home = core_center
	_fighter.notice()
	_fighter.died.connect(func(_c: WorldCreature) -> void:
		if Game.profile:
			Game.profile.factions.change(faction_id, -15)
			EventBus.notify("%s will remember this. (-15 reputation)" % String(FactionState.info(faction_id).get("name", faction_id)), "warning"))
	if Game.profile:
		Game.profile.factions.change(faction_id, -5)
	visible = false
	interact.set_enabled(false)
	_hidden_for = 0.0
	_trespass = -1.0


func _restore() -> void:
	visible = true
	interact.set_enabled(true)
	global_position = home
	_hidden_for = 0.0
