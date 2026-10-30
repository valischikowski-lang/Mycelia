class_name ClassSeal
extends Interactable
## A barrier only one calling can open with its ability (or anyone with a
## Wanderkey). Tags: "shadow" (Assassin: Shadow Dash), "astral" (Spirit:
## Astral Shift), "echo" (Spirit: Echo of the Ancients), "rune" (Wizard:
## Arcane Bolt), "root" (Grimlet: Root Snare), "mycelium" (Grimlet:
## Mycelium Link). Seals only guard optional treasure, never the story.

signal opened()

const INFO := {
	"shadow": {"name": "Shadow Veil", "class": "assassin", "ability": "Shadow Dash", "color": Color("#5a3cff")},
	"astral": {"name": "Astral Barrier", "class": "spirit", "ability": "Astral Shift", "color": Color("#c9a0ff")},
	"echo": {"name": "Silent Echo", "class": "spirit", "ability": "Echo of the Ancients", "color": Color("#ffe9a8")},
	"rune": {"name": "Sleeping Rune", "class": "wizard", "ability": "Arcane Bolt", "color": Color("#8ab4ff")},
	"root": {"name": "Root Gate", "class": "grimlet", "ability": "Root Snare", "color": Color("#9cff4a")},
	"mycelium": {"name": "Dormant Mycelium Node", "class": "grimlet", "ability": "Mycelium Link", "color": Color("#36fff0")},
}

@export var seal_id: String = ""
@export var tag: String = "shadow"
@export var dome_radius: float = 1.9
## How far away an ability may be cast and still reach the seal.
@export var reach: float = 4.0
## Shown when an Echo is revealed.
@export_multiline var echo_text: String = ""

var _dome: MeshInstance3D
var _body: StaticBody3D
var _open: bool = false


func _after_ready() -> void:
	add_to_group("class_seal")
	var info: Dictionary = INFO.get(tag, INFO["shadow"])
	prompt = "Examine"
	display_name = String(info["name"])
	marker_color = info["color"]
	marker_height = dome_radius + 0.6
	_build_visual(info["color"])
	if Game.profile and Game.profile.world.is_consumed(seal_id):
		_set_open(true)


func _build_visual(col: Color) -> void:
	_dome = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = dome_radius
	sm.height = dome_radius * 2.0
	sm.radial_segments = 24
	sm.rings = 12
	_dome.mesh = sm
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(col, 0.22 if tag != "shadow" else 0.75)
	if tag == "shadow":
		m.albedo_color = Color(0.03, 0.01, 0.08, 0.85)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.rim_enabled = true
	_dome.material_override = m
	_dome.position.y = dome_radius * 0.55
	add_child(_dome)
	var p := SpellFX.ambient_motes(col, 24, Vector3.ONE * dome_radius, 0.12)
	p.position.y = dome_radius * 0.55
	_dome.add_child(p)
	_body = StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = dome_radius
	cs.shape = sh
	cs.position.y = dome_radius * 0.55
	_body.add_child(cs)
	add_child(_body)
	if tag in ["rune", "mycelium", "echo"]:
		# A focus object the ability is aimed at.
		var kit := MeshKit.new()
		kit.crystal_prism(Vector3(dome_radius + 0.6, 0, 0), Basis.IDENTITY, 1.8, 0.28, 6, Color(col.r, col.g, col.b, 0.9), 0.3)
		var fm := MeshInstance3D.new()
		fm.mesh = kit.commit(MaterialLib.crystal(2.0))
		add_child(fm)


func is_open() -> bool:
	return _open


func _on_interact(_by: Node) -> void:
	var info: Dictionary = INFO.get(tag, INFO["shadow"])
	var prof := Game.profile
	if prof and prof.inventory.has("wanderkey"):
		prof.inventory.remove("wanderkey", 1)
		EventBus.notify("The Wanderkey turns in a lock that isn't there.", "success")
		break_seal()
		return
	var c := Database.player_class(String(info["class"]))
	var mine := prof != null and prof.class_id == String(info["class"])
	if mine:
		EventBus.notify("%s: use %s here to open it." % [info["name"], info["ability"]], "info")
	else:
		EventBus.notify("%s. Only a %s's %s opens it — or a Wanderkey." % [info["name"], c.display_name if c else "?", info["ability"]], "info")


## Called by AbilityRunner when a matching ability is used nearby.
func on_ability(ability_tag: String) -> void:
	if _open or ability_tag != tag:
		return
	break_seal()


func break_seal() -> void:
	if _open:
		return
	_set_open(false)
	if Game.profile:
		Game.profile.world.consume(seal_id)
	EventBus.object_activated.emit(seal_id)
	AudioManager.play_sfx("mechanism")
	RtFx.burst(get_parent(), global_position + Vector3.UP, marker_color, 40, 0.2, 5.0)
	if tag == "echo" and echo_text != "":
		get_tree().call_group("hud", "show_lore", "An Echo Remembers", echo_text)
	else:
		EventBus.notify("The %s opens." % display_name, "success")
	opened.emit()


func _set_open(instant: bool) -> void:
	_open = true
	set_enabled(false)
	_body.process_mode = Node.PROCESS_MODE_DISABLED
	_body.queue_free()
	if instant:
		_dome.visible = false
	else:
		var tw := create_tween()
		tw.tween_property(_dome, "scale", Vector3.ONE * 1.4, 0.5)
		tw.parallel().tween_property(_dome, "transparency", 1.0, 0.5)
		tw.tween_callback(func() -> void: _dome.visible = false)
