class_name MushroomParams
extends Resource
## Parameters for MushroomGenerator. Exported so variants can be authored
## and previewed in the editor.

enum CapShape { DOME, BELL, PARASOL, FUNNEL, WAVY, PUFFBALL, SPIRE }

@export var seed: int = 1
@export var cap_shape: CapShape = CapShape.DOME
@export var stem_height: float = 2.0
@export var stem_width: float = 0.25
## Lateral stem bend (meters at the top) and twist.
@export var stem_bend: float = 0.3
@export var stem_twist: float = 0.0
@export var cap_radius: float = 1.0
@export var cap_height: float = 0.6
## 0..1 — how strongly the cap rim droops / profile curves.
@export_range(0.0, 1.0) var cap_curvature: float = 0.5
@export_range(0.0, 0.5) var cap_asymmetry: float = 0.1
@export var cap_lobes: int = 0
@export_range(6, 48) var cap_segments: int = 18
@export var cap_color: Color = Color(0.7, 0.2, 0.9)
@export var cap_top_color: Color = Color(1.0, 0.4, 0.85)
@export var stem_color: Color = Color(0.85, 0.8, 1.0)
@export var glow_color: Color = Color(0.2, 1.0, 0.95)
@export var spot_color: Color = Color(1.0, 0.9, 0.3)
@export_range(0.0, 1.0) var emission_intensity: float = 0.8
@export_range(0.0, 1.0) var roughness: float = 0.7
@export var spots: int = 6
@export var rim_glow: bool = true
@export var floating: bool = false
@export var tendrils: int = 0
## 0..1 geometric detail (LOD). Small background mushrooms use ~0.3.
@export_range(0.0, 1.0) var detail: float = 1.0
