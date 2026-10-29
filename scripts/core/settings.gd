extends Node
## Player-facing settings: graphics preset, audio volumes, controls.
## Persisted to user://settings.cfg independently of save games.

signal changed(section: String)

enum Quality { LOW, MEDIUM, HIGH }

const PATH := "user://settings.cfg"

var quality: Quality = Quality.MEDIUM
var render_scale: float = 1.0
var show_fps: bool = false
var mouse_sensitivity: float = 0.12
var touch_sensitivity: float = 1.0
var invert_y: bool = false
var head_bob: bool = true
var fov: float = 78.0
var force_touch_controls: bool = false
var volumes: Dictionary = {"Master": 0.85, "Music": 0.6, "Ambient": 0.8, "Effects": 0.85, "UI": 0.7}
var key_overrides: Dictionary = {}


func _ready() -> void:
	load_settings()
	InputConfig.apply(key_overrides)
	if not _has_saved_settings() and OS.has_feature("mobile"):
		quality = Quality.LOW


func _has_saved_settings() -> bool:
	return FileAccess.file_exists(PATH)


## Preset-derived values used by renderers / generators.
func scatter_density() -> float:
	return [0.45, 0.75, 1.0][quality]


func particle_ratio() -> float:
	return [0.35, 0.7, 1.0][quality]


func shadows_enabled() -> bool:
	return quality != Quality.LOW


func glow_enabled() -> bool:
	return quality != Quality.LOW


func view_distance_scale() -> float:
	return [0.6, 0.85, 1.0][quality]


func effective_render_scale() -> float:
	var preset: float = [0.7, 0.85, 1.0][quality]
	return clampf(preset * render_scale, 0.4, 1.0)


func uses_touch() -> bool:
	return force_touch_controls or DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")


func set_quality(q: Quality) -> void:
	quality = q
	save_settings()
	changed.emit("graphics")


func set_volume(bus: String, value: float) -> void:
	volumes[bus] = clampf(value, 0.0, 1.0)
	save_settings()
	changed.emit("audio")


func notify_changed(section: String) -> void:
	save_settings()
	changed.emit(section)


## Applies render scale/MSAA to a viewport. Called by scenes that own 3D views.
func apply_to_viewport(vp: Viewport) -> void:
	vp.scaling_3d_scale = effective_render_scale()
	vp.msaa_3d = Viewport.MSAA_2X if quality == Quality.HIGH else Viewport.MSAA_DISABLED
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if quality != Quality.LOW else Viewport.SCREEN_SPACE_AA_DISABLED


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("graphics", "quality", int(quality))
	cfg.set_value("graphics", "render_scale", render_scale)
	cfg.set_value("graphics", "show_fps", show_fps)
	cfg.set_value("graphics", "fov", fov)
	cfg.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("controls", "touch_sensitivity", touch_sensitivity)
	cfg.set_value("controls", "invert_y", invert_y)
	cfg.set_value("controls", "head_bob", head_bob)
	cfg.set_value("controls", "force_touch_controls", force_touch_controls)
	cfg.set_value("controls", "key_overrides", key_overrides)
	cfg.set_value("audio", "volumes", volumes)
	var err := cfg.save(PATH)
	if err != OK:
		push_warning("Settings: could not save (%s)" % error_string(err))


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	quality = clampi(int(cfg.get_value("graphics", "quality", int(quality))), 0, 2) as Quality
	render_scale = clampf(float(cfg.get_value("graphics", "render_scale", render_scale)), 0.5, 1.0)
	show_fps = bool(cfg.get_value("graphics", "show_fps", show_fps))
	fov = clampf(float(cfg.get_value("graphics", "fov", fov)), 60.0, 100.0)
	mouse_sensitivity = clampf(float(cfg.get_value("controls", "mouse_sensitivity", mouse_sensitivity)), 0.02, 0.6)
	touch_sensitivity = clampf(float(cfg.get_value("controls", "touch_sensitivity", touch_sensitivity)), 0.2, 3.0)
	invert_y = bool(cfg.get_value("controls", "invert_y", invert_y))
	head_bob = bool(cfg.get_value("controls", "head_bob", head_bob))
	force_touch_controls = bool(cfg.get_value("controls", "force_touch_controls", force_touch_controls))
	var ko: Variant = cfg.get_value("controls", "key_overrides", {})
	key_overrides = ko if ko is Dictionary else {}
	var vols: Variant = cfg.get_value("audio", "volumes", volumes)
	if vols is Dictionary:
		for k: String in volumes.keys():
			volumes[k] = clampf(float((vols as Dictionary).get(k, volumes[k])), 0.0, 1.0)
