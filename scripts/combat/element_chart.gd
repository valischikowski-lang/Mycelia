class_name ElementChart
extends RefCounted
## Elemental relationships of the five disciplines.
##
## The Cycle of Mycelia: Fungal decays Nature, Nature cracks Crystal,
## Crystal refracts Cosmic, Cosmic sterilizes Fungal. Chaos ignores the cycle
## but is erratic: it is mildly strong against everything except itself.

const ELEMENTS: PackedStringArray = ["fungal", "crystal", "nature", "cosmic", "chaos"]
const STRONG := 1.5
const WEAK := 0.75
const CHAOS_MULT := 1.1

const BEATS: Dictionary = {
	"fungal": "nature",
	"nature": "crystal",
	"crystal": "cosmic",
	"cosmic": "fungal",
}

const COLORS: Dictionary = {
	"fungal": Color(0.75, 0.35, 1.0),
	"crystal": Color(0.3, 0.95, 1.0),
	"nature": Color(0.55, 1.0, 0.3),
	"cosmic": Color(1.0, 0.85, 0.3),
	"chaos": Color(1.0, 0.3, 0.7),
}

const GLYPHS: Dictionary = {
	"fungal": "✺", "crystal": "◆", "nature": "❦", "cosmic": "✶", "chaos": "✹",
}

const NAMES: Dictionary = {
	"fungal": "Fungal", "crystal": "Crystal", "nature": "Nature", "cosmic": "Cosmic", "chaos": "Chaos",
}


static func multiplier(attack: String, defend: String) -> float:
	if attack == "chaos":
		return 1.0 if defend == "chaos" else CHAOS_MULT
	if BEATS.get(attack, "") == defend:
		return STRONG
	if BEATS.get(defend, "") == attack:
		return WEAK
	return 1.0


static func color(element: String) -> Color:
	return COLORS.get(element, Color.WHITE)


static func glyph(element: String) -> String:
	return GLYPHS.get(element, "•")


static func display_name(element: String) -> String:
	return NAMES.get(element, element.capitalize())
