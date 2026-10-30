class_name Region
extends Node3D
## Base class for a playable region. Subclasses implement _build_content()
## as a coroutine that reports progress; the base class owns atmosphere
## (sky, fog, glow, light), spawn points and graphics-preset reactions.

signal build_progress(fraction: float, label: String)
signal built()

@export var region_id: String = ""
@export var biome_id: String = ""
@export var world_seed: int = 1

var biome: BiomeData
var terrain: DreamTerrain
var environment: Environment
var world_env: WorldEnvironment
var sun: DirectionalLight3D
var spawns: Dictionary = {}
var landmarks: Dictionary = {}
var is_built: bool = false
var rng := RandomNumberGenerator.new()
## Nodes whose visibility depends on graphics quality (detail props).
var detail_nodes: Array[Node3D] = []


func build() -> void:
	rng.seed = world_seed
	biome = Database.biome(biome_id)
	if biome == null:
		push_error("Region: missing biome '%s'" % biome_id)
		biome = BiomeData.new()
	_setup_environment()
	await _build_content()
	apply_graphics()
	Settings.changed.connect(_on_settings_changed)
	is_built = true
	built.emit()


## Override. Must await at least once per heavy step and call report().
func _build_content() -> void:
	await get_tree().process_frame


func report(fraction: float, label: String) -> void:
	build_progress.emit(fraction, label)
	await get_tree().process_frame


## Builds the shared MYCELIA atmosphere (sky, fog, glow, tonemap) for a biome.
static func make_environment(b: BiomeData) -> Environment:
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = MaterialLib.sky(b)
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = b.ambient_color
	e.ambient_light_energy = b.ambient_energy
	e.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 0.92
	e.tonemap_white = 6.0
	e.glow_enabled = Settings.glow_enabled()
	e.glow_intensity = 0.6
	e.glow_strength = 1.0
	e.glow_bloom = 0.06
	e.glow_hdr_threshold = 1.05
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	e.set_glow_level(0, 0.0)
	e.set_glow_level(1, 1.0)
	e.set_glow_level(2, 0.8)
	e.set_glow_level(3, 0.6)
	e.set_glow_level(4, 0.4)
	e.fog_enabled = true
	e.fog_light_color = b.fog_color
	e.fog_light_energy = 1.0
	e.fog_density = b.fog_density
	e.fog_sky_affect = 0.18
	e.fog_height = b.fog_height
	e.fog_height_density = b.fog_height_density
	e.adjustment_enabled = true
	e.adjustment_saturation = 1.18
	e.adjustment_contrast = 1.06
	return e


func get_spawn(spawn_name: String) -> Dictionary:
	if spawns.has(spawn_name):
		return spawns[spawn_name]
	if spawns.has("default"):
		return spawns["default"]
	return {"position": Vector3(0, 5, 0), "yaw": 0.0}


func add_spawn(spawn_name: String, pos: Vector3, yaw: float) -> void:
	spawns[spawn_name] = {"position": pos, "yaw": yaw}


func ground(x: float, z: float) -> float:
	return terrain.height_at(x, z) if terrain else 0.0


func _setup_environment() -> void:
	environment = make_environment(biome)
	world_env = WorldEnvironment.new()
	world_env.environment = environment
	add_child(world_env)
	sun = DirectionalLight3D.new()
	sun.name = "DreamSun"
	sun.light_color = biome.sun_color
	sun.light_energy = biome.sun_energy
	sun.rotation_degrees = biome.sun_rotation_deg
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 70.0
	sun.shadow_bias = 0.05
	sun.shadow_normal_bias = 1.5
	sun.shadow_opacity = 0.75
	add_child(sun)


func _on_settings_changed(section: String) -> void:
	if section == "graphics":
		apply_graphics()


func apply_graphics() -> void:
	if sun:
		sun.shadow_enabled = Settings.shadows_enabled()
	if environment:
		environment.glow_enabled = Settings.glow_enabled()
	var density := Settings.scatter_density()
	for n: Node3D in detail_nodes:
		if is_instance_valid(n):
			n.visible = density >= float(n.get_meta("min_density", 0.0))
			if n is MultiMeshInstance3D:
				var mm := (n as MultiMeshInstance3D).multimesh
				var full := int(n.get_meta("full_count", mm.instance_count))
				mm.visible_instance_count = int(full * clampf(density, 0.0, 1.0))
			if n is GeometryInstance3D and n.has_meta("base_range"):
				(n as GeometryInstance3D).visibility_range_end = float(n.get_meta("base_range")) * Settings.view_distance_scale()


## Registers a detail node so graphics presets can thin it out.
func register_detail(n: Node3D, min_density: float = 0.0, base_range: float = 0.0) -> void:
	n.set_meta("min_density", min_density)
	if base_range > 0.0 and n is GeometryInstance3D:
		n.set_meta("base_range", base_range)
		(n as GeometryInstance3D).visibility_range_end = base_range
		(n as GeometryInstance3D).visibility_range_end_margin = base_range * 0.1
		(n as GeometryInstance3D).visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	if n is MultiMeshInstance3D:
		n.set_meta("full_count", (n as MultiMeshInstance3D).multimesh.instance_count)
	detail_nodes.append(n)
