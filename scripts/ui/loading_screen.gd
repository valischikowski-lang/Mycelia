class_name LoadingScreen
extends Control
## Shown while a region builds. Displays progress, flavour text and tips.

const TIPS: PackedStringArray = [
	"Follow beams of light: they mark things the Mycelium wants you to find.",
	"Bounce mushrooms launch you upwards. Some islands can only be reached from below.",
	"Dream Pools restore your health and mana, and are safe places to rest.",
	"Each discipline beats another: Fungal decays Nature, Nature cracks Crystal, Crystal refracts Cosmic, Cosmic sterilizes Fungal.",
	"Thornlash costs no mana. When you're out of mana, Meditate to recover it.",
	"Flowers turn to watch you. They are harmless. Mostly.",
	"Spend skill points in the Grimoire to grow your Fungal discipline.",
	"Hidden places reward the curious. Look behind curtains of vines.",
]

var _bar: ProgressBar
var _label: Label
var _tip: Label
var _title: Label
var _t: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/transition.gdshader")
	mat.set_shader_parameter("progress", 1.0)
	bg.material = mat
	add_child(bg)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.offset_left = -360
	v.offset_right = 360
	v.offset_top = -120
	v.offset_bottom = 160
	v.add_theme_constant_override("separation", 16)
	add_child(v)
	_title = UiTheme.title("MYCELIA", 64)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_title)
	_label = UiTheme.label("The spores are dreaming...", 22, UiTheme.GLOW)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_label)
	_bar = UiTheme.bar(UiTheme.GLOW, Vector2(720, 14))
	_bar.max_value = 1.0
	v.add_child(_bar)
	_tip = UiTheme.label(TIPS[randi() % TIPS.size()], 18, UiTheme.TEXT_DIM)
	_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.custom_minimum_size.x = 720
	v.add_child(_tip)


func set_progress(fraction: float, text: String) -> void:
	_bar.value = fraction
	_label.text = text


func _process(delta: float) -> void:
	_t += delta
	_title.modulate = Color.from_hsv(fmod(0.8 + sin(_t * 0.5) * 0.08, 1.0), 0.35, 1.0)
