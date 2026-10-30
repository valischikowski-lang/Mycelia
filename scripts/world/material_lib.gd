class_name MaterialLib
extends RefCounted
## Central factory and cache for MYCELIA's reusable materials. Generators ask
## for materials by intent ("glowing mushroom", "living root") so the look of
## the whole world can be tuned in one place.

const ORGANIC := preload("res://shaders/organic.gdshader")
const GROUND := preload("res://shaders/ground.gdshader")
const WATER := preload("res://shaders/water.gdshader")
const CRYSTAL := preload("res://shaders/crystal.gdshader")
const SKY := preload("res://shaders/dream_sky.gdshader")
const GLOW := preload("res://shaders/glow_additive.gdshader")

static var _cache: Dictionary = {}
static var _noise_tex: NoiseTexture2D
static var _vein_tex: NoiseTexture2D


static func clear_cache() -> void:
	_cache.clear()


static func noise_texture() -> NoiseTexture2D:
	if _noise_tex == null:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.frequency = 0.012
		n.fractal_octaves = 4
		n.seed = 1337
		_noise_tex = NoiseTexture2D.new()
		_noise_tex.width = 256
		_noise_tex.height = 256
		_noise_tex.seamless = true
		_noise_tex.noise = n
		_noise_tex.generate_mipmaps = true
	return _noise_tex


static func vein_texture() -> NoiseTexture2D:
	if _vein_tex == null:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_CELLULAR
		n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
		n.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
		n.frequency = 0.045
		n.fractal_type = FastNoiseLite.FRACTAL_NONE
		n.seed = 7
		_vein_tex = NoiseTexture2D.new()
		_vein_tex.width = 256
		_vein_tex.height = 256
		_vein_tex.seamless = true
		_vein_tex.noise = n
		_vein_tex.normalize = true
		_vein_tex.generate_mipmaps = true
	return _vein_tex


## Generic organic material. Options: emission, pulse, rim (Color), sway,
## sway_height, breathe, roughness, tint.
static func organic(key: String = "default", opts: Dictionary = {}) -> ShaderMaterial:
	var cache_key := "organic:" + key
	if _cache.has(cache_key):
		return _cache[cache_key]
	var m := ShaderMaterial.new()
	m.shader = ORGANIC
	m.set_shader_parameter("emission_strength", float(opts.get("emission", 2.2)))
	m.set_shader_parameter("pulse_amount", float(opts.get("pulse", 0.3)))
	m.set_shader_parameter("pulse_speed", float(opts.get("pulse_speed", 1.1)))
	m.set_shader_parameter("rim_color", opts.get("rim", Color(0.55, 0.9, 1.0)))
	m.set_shader_parameter("rim_strength", float(opts.get("rim_strength", 0.55)))
	m.set_shader_parameter("sway_strength", float(opts.get("sway", 0.0)))
	m.set_shader_parameter("sway_height", float(opts.get("sway_height", 4.0)))
	m.set_shader_parameter("sway_speed", float(opts.get("sway_speed", 1.0)))
	m.set_shader_parameter("breathe", float(opts.get("breathe", 0.0)))
	m.set_shader_parameter("roughness_value", float(opts.get("roughness", 0.75)))
	m.set_shader_parameter("tint", opts.get("tint", Color.WHITE))
	m.set_shader_parameter("shadow_tint", opts.get("shadow_tint", Color(0.35, 0.2, 0.75)))
	_cache[cache_key] = m
	return m


static func mushroom() -> ShaderMaterial:
	return organic("mushroom", {"emission": 2.6, "pulse": 0.35, "rim": Color(0.7, 0.5, 1.0), "roughness": 0.6})


static func mushroom_breathing() -> ShaderMaterial:
	return organic("mushroom_breathe", {"emission": 2.6, "pulse": 0.35, "rim": Color(0.7, 0.5, 1.0), "roughness": 0.6, "breathe": 0.025})


static func foliage() -> ShaderMaterial:
	return organic("foliage", {"emission": 1.8, "sway": 0.25, "sway_height": 6.0, "rim": Color(0.6, 1.0, 0.7), "roughness": 0.85})


static func bark() -> ShaderMaterial:
	return organic("bark", {"emission": 2.0, "pulse": 0.5, "pulse_speed": 0.6, "rim": Color(0.8, 0.5, 1.0), "rim_strength": 0.35, "roughness": 0.9})


static func plant() -> ShaderMaterial:
	return organic("plant", {"emission": 2.4, "sway": 0.12, "sway_height": 1.5, "sway_speed": 1.6, "rim": Color(1.0, 0.7, 0.9), "roughness": 0.7})


static func grass() -> ShaderMaterial:
	return organic("grass", {"emission": 1.2, "sway": 0.14, "sway_height": 0.7, "sway_speed": 1.8, "rim": Color(0.5, 1.0, 0.8), "rim_strength": 0.3, "roughness": 0.95})


static func stone() -> ShaderMaterial:
	return organic("stone", {"emission": 2.8, "pulse": 0.4, "pulse_speed": 0.5, "rim": Color(0.4, 0.8, 1.0), "rim_strength": 0.3, "roughness": 0.95})


static func creature() -> ShaderMaterial:
	return organic("creature", {"emission": 2.4, "pulse": 0.2, "rim": Color(1.0, 0.85, 1.0), "rim_strength": 0.8, "roughness": 0.55})


static func crystal(glow: float = 1.4) -> ShaderMaterial:
	var cache_key := "crystal:%0.2f" % glow
	if _cache.has(cache_key):
		return _cache[cache_key]
	var m := ShaderMaterial.new()
	m.shader = CRYSTAL
	m.set_shader_parameter("glow", glow)
	_cache[cache_key] = m
	return m


static func water(key: String = "lake", opts: Dictionary = {}) -> ShaderMaterial:
	var cache_key := "water:" + key
	if _cache.has(cache_key):
		return _cache[cache_key]
	var m := ShaderMaterial.new()
	m.shader = WATER
	m.set_shader_parameter("noise_tex", noise_texture())
	m.set_shader_parameter("deep_color", opts.get("deep", Color(0.03, 0.18, 0.42)))
	m.set_shader_parameter("shallow_color", opts.get("shallow", Color(0.12, 0.95, 0.88)))
	m.set_shader_parameter("alpha", float(opts.get("alpha", 0.82)))
	m.set_shader_parameter("glow", float(opts.get("glow", 0.8)))
	m.set_shader_parameter("flow_speed", float(opts.get("flow_speed", 0.0)))
	m.set_shader_parameter("flow_dir", opts.get("flow_dir", Vector2(0, 1)))
	m.set_shader_parameter("wave_height", float(opts.get("wave_height", 0.08)))
	_cache[cache_key] = m
	return m


static func glow(color: Color, intensity: float = 1.5, uv_fade: bool = true, fresnel: bool = false) -> ShaderMaterial:
	var cache_key := "glow:%s:%0.2f:%s:%s" % [color.to_html(), intensity, uv_fade, fresnel]
	if _cache.has(cache_key):
		return _cache[cache_key]
	var m := ShaderMaterial.new()
	m.shader = GLOW
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("intensity", intensity)
	m.set_shader_parameter("use_uv_fade", uv_fade)
	m.set_shader_parameter("fresnel_fade", fresnel)
	_cache[cache_key] = m
	return m


## Fresh (uncached) glow so callers may animate its parameters.
static func glow_unique(color: Color, intensity: float = 1.5, uv_fade: bool = false, fresnel: bool = false) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = GLOW
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("intensity", intensity)
	m.set_shader_parameter("use_uv_fade", uv_fade)
	m.set_shader_parameter("fresnel_fade", fresnel)
	return m


static func ground(biome: BiomeData) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = GROUND
	m.set_shader_parameter("detail_noise", noise_texture())
	m.set_shader_parameter("vein_noise", vein_texture())
	m.set_shader_parameter("vein_color", biome.vein_color)
	return m


static func sky(biome: BiomeData) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SKY
	m.set_shader_parameter("noise_tex", noise_texture())
	m.set_shader_parameter("top_color", biome.sky_top)
	m.set_shader_parameter("mid_color", biome.sky_mid)
	m.set_shader_parameter("horizon_color", biome.sky_horizon)
	m.set_shader_parameter("band_color", biome.sky_band)
	m.set_shader_parameter("moon_color", biome.moon_color)
	m.set_shader_parameter("ghost_color", biome.vein_color)
	return m


## Simple particle billboard material (StandardMaterial3D; cheap on mobile).
static func particle(color: Color, emission: float = 3.0) -> StandardMaterial3D:
	var cache_key := "particle:%s:%0.1f" % [color.to_html(), emission]
	if _cache.has(cache_key):
		return _cache[cache_key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_color = color * emission
	m.albedo_texture = soft_dot_texture()
	m.disable_receive_shadows = true
	_cache[cache_key] = m
	return m


static var _dot_tex: ImageTexture


static func soft_dot_texture() -> ImageTexture:
	if _dot_tex == null:
		var size := 32
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		for y in size:
			for x in size:
				var d := Vector2(x - size * 0.5 + 0.5, y - size * 0.5 + 0.5).length() / (size * 0.5)
				var a := clampf(1.0 - d, 0.0, 1.0)
				a = a * a * (3.0 - 2.0 * a)
				img.set_pixel(x, y, Color(1, 1, 1, a))
		_dot_tex = ImageTexture.create_from_image(img)
	return _dot_tex
