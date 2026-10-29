class_name ItemData
extends Resource
## Static definition of an item. Runtime ownership lives in Inventory.

enum Category { QUEST, COLLECTIBLE, INGREDIENT, SCROLL, EQUIPMENT, COSMETIC, CONSUMABLE }
enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

const RARITY_COLORS: Array[Color] = [
	Color(0.85, 0.85, 0.92), Color(0.45, 1.0, 0.55), Color(0.3, 0.85, 1.0),
	Color(0.85, 0.45, 1.0), Color(1.0, 0.72, 0.25),
]
const EQUIP_SLOTS: PackedStringArray = ["hat", "robe", "boots", "staff", "ring", "artifact"]

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var category: Category = Category.COLLECTIBLE
@export var rarity: Rarity = Rarity.COMMON
@export var max_stack: int = 99
@export var value: int = 1
## Procedural icon: base color + a single glyph drawn by ItemIcon.
@export var icon_color: Color = Color(0.7, 0.4, 1.0)
@export var icon_glyph: String = "✦"
## Equipment only: one of EQUIP_SLOTS.
@export var equip_slot: String = ""
## e.g. {"max_health": 10, "spell_power": 5}
@export var stat_bonuses: Dictionary = {}
## Consumables: {"heal": 30, "mana": 4, "unlock_spell": "spell_id"}
@export var use_effect: Dictionary = {}


func is_equipment() -> bool:
	return category == Category.EQUIPMENT or category == Category.COSMETIC


func is_usable() -> bool:
	return not use_effect.is_empty()


func rarity_color() -> Color:
	return RARITY_COLORS[rarity]


func category_name() -> String:
	return String(Category.keys()[category]).capitalize()
