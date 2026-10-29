class_name NPC
extends Node3D
## A talkable character. Behaviour is generic; personality lives in the
## dialogue JSON referenced by `dialogue_id`. Quests advance through the
## npc_talked event and dialogue actions, never through NPC code.

@export var npc_id: String = ""
@export var display_name: String = ""
@export var title: String = ""
@export var dialogue_id: String = ""
@export var visual_kind: String = "keeper"
@export var talk_radius: float = 1.6
@export var interact_height: float = 1.2
@export var turn_to_player: bool = true
@export var voice: String = "inspect"

var rig: CreatureRig
var interact: NPCInteract
var _player: Node3D
var _name_label: Label3D
var _quest_marker: Label3D


func _ready() -> void:
	add_to_group("npc")
	rig = CreatureBuilder.build(visual_kind)
	add_child(rig)
	interact = NPCInteract.new()
	interact.npc = self
	interact.prompt = "Talk to"
	interact.display_name = display_name
	interact.radius = talk_radius
	interact.marker_height = 1.6
	interact.show_marker = false
	interact.position = Vector3(0, interact_height, 0)
	add_child(interact)
	_name_label = Label3D.new()
	_name_label.text = display_name + ("\n" + title if title != "" else "")
	_name_label.font = UiTheme.bold_font()
	_name_label.font_size = 40
	_name_label.outline_size = 10
	_name_label.pixel_size = 0.005
	_name_label.modulate = Color(1.0, 0.95, 0.8)
	_name_label.outline_modulate = Color(0.2, 0.05, 0.3, 0.9)
	_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_label.position = Vector3(0, _label_height(), 0)
	add_child(_name_label)
	_quest_marker = Label3D.new()
	_quest_marker.font = UiTheme.title_font()
	_quest_marker.font_size = 110
	_quest_marker.outline_size = 14
	_quest_marker.pixel_size = 0.006
	_quest_marker.modulate = UiTheme.GOLD
	_quest_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_quest_marker.position = Vector3(0, _label_height() + 0.55, 0)
	add_child(_quest_marker)
	EventBus.quest_tracker_changed.connect(_refresh_marker)
	EventBus.quest_state_changed.connect(func(_q: String, _s: int) -> void: _refresh_marker())
	EventBus.inventory_changed.connect(_refresh_marker)
	_refresh_marker()


func _label_height() -> float:
	match visual_kind:
		"keeper":
			return 3.0
		"petalune":
			return 4.1
		"ollo":
			return 2.6
	return 2.2


## "!" when this NPC can give a quest, "?" when an objective targets them.
func _refresh_marker() -> void:
	if Game.profile == null or _quest_marker == null:
		return
	var mark := ""
	for qid: String in Game.profile.quests.active_quests():
		var o := Game.profile.quests.current_objective(qid)
		if o and o.type == QuestObjectiveData.Type.TALK and o.target_id == npc_id:
			mark = "?"
	if mark == "" and npc_id in ["madame_petalune", "ollo"]:
		var qid2 := "lights_of_glimmermere" if npc_id == "madame_petalune" else "beetle_bother"
		if Game.profile.quests.get_state(qid2) == QuestData.State.AVAILABLE:
			mark = "!"
	_quest_marker.text = mark


func _process(delta: float) -> void:
	if not turn_to_player or rig == null:
		return
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node3D
		return
	var d := global_position.distance_to(_player.global_position)
	if d < 7.0:
		var flat := Vector3(_player.global_position.x, global_position.y, _player.global_position.z) - global_position
		if flat.length() > 0.1:
			var want := Basis.looking_at(-flat.normalized(), Vector3.UP)
			rig.basis = rig.basis.orthonormalized().slerp(want, minf(1.0, delta * 3.0))


func start_dialogue() -> void:
	EventBus.npc_talked.emit(npc_id)
	EventBus.dialogue_requested.emit(self, dialogue_id)
	AudioManager.play_sfx(voice, -6.0)


class NPCInteract extends Interactable:
	var npc: NPC

	func _on_interact(_by: Node) -> void:
		if npc:
			npc.start_dialogue()
