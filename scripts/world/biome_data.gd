class_name BiomeData
extends Resource
## Palette + atmosphere for a region. Generators read colors from here so every
## region keeps a controlled, recognizable color identity.

@export var id: String = ""
@export var display_name: String = ""
# Sky
@export var sky_top: Color = Color(0.12, 0.04, 0.3)
@export var sky_mid: Color = Color(0.55, 0.12, 0.55)
@export var sky_horizon: Color = Color(1.0, 0.5, 0.35)
@export var sky_band: Color = Color(0.2, 0.95, 0.9)
@export var moon_color: Color = Color(1.0, 0.9, 0.75)
# Light / fog
@export var sun_color: Color = Color(1.0, 0.72, 0.85)
@export var sun_energy: float = 1.1
@export var sun_rotation_deg: Vector3 = Vector3(-28, 140, 0)
@export var ambient_color: Color = Color(0.45, 0.35, 0.8)
@export var ambient_energy: float = 0.9
@export var fog_color: Color = Color(0.5, 0.35, 0.8)
@export var fog_density: float = 0.006
@export var fog_height: float = 6.0
@export var fog_height_density: float = 0.06
# Ground
@export var grass_color: Color = Color(0.1, 0.4, 0.38)
@export var grass_tip_color: Color = Color(0.4, 0.9, 0.55)
@export var moss_color: Color = Color(0.5, 0.3, 0.7)
@export var path_color: Color = Color(0.95, 0.62, 0.55)
@export var rock_color: Color = Color(0.32, 0.18, 0.45)
@export var vein_color: Color = Color(0.2, 1.0, 0.95)
# Flora palettes
@export var mushroom_caps: Array[Color] = []
@export var mushroom_glow: Array[Color] = []
@export var flower_colors: Array[Color] = []
@export var crystal_colors: Array[Color] = []
@export var foliage_colors: Array[Color] = []
@export var bark_colors: Array[Color] = []
# Scattering
@export var grass_density: float = 1.0
@export var flora_density: float = 1.0
@export var music: String = "meadow"
@export var ambience: String = "meadow_ambience"


func pick(colors: Array[Color], rng: RandomNumberGenerator, fallback: Color = Color.WHITE) -> Color:
	if colors.is_empty():
		return fallback
	return colors[rng.randi() % colors.size()]
