class_name ItemData
extends Resource
## Static definition of an item. Runtime ownership lives in Inventory.

enum Category { QUEST, COLLECTIBLE, INGREDIENT, SCROLL, EQUIPMENT, COSMETIC, CONSUMABLE }
enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY, MYTHIC }

const RARITY_COLORS: Array[Color] = [
	Color(0.85, 0.85, 0.92), Color(0.45, 1.0, 0.55), Color(0.3, 0.85, 1.0),
	Color(0.85, 0.45, 1.0), Color(1.0, 0.72, 0.25), Color(1.0, 0.3, 0.45),
]
## "staff" is the main weapon slot (kept for save compatibility), "hat" the
## helm and "robe" the armour.
const EQUIP_SLOTS: PackedStringArray = ["hat", "robe", "boots", "staff", "offhand", "ranged", "ring", "artifact"]
const SLOT_NAMES: Dictionary = {
	"hat": "Helm", "robe": "Armor", "boots": "Boots", "staff": "Weapon", "offhand": "Off-hand",
	"ranged": "Bow", "ring": "Trinket", "artifact": "Artifact",
}
## dagger, sword, greatsword, axe, hammer, staff, wand, bow, shield
const WEAPON_KINDS: PackedStringArray = ["dagger", "sword", "greatsword", "axe", "hammer", "staff", "wand", "bow", "shield"]

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
@export_group("Combat")
## "" = any class may use it.
@export var class_id: String = ""
## One of WEAPON_KINDS for weapons/shields/bows.
@export var weapon_kind: String = ""
@export var damage: float = 0.0
## Attacks per second for the light combo.
@export var attack_speed: float = 1.5
@export var reach: float = 2.0
## Shields: damage blocked fraction (0..1) and perfect-parry window (s).
@export var block_power: float = 0.0
@export var parry_window: float = 0.0
## Named special behaviour handled by PlayerCombat (e.g. "backstab_bonus",
## "silent", "cleave", "shockwave", "soul_drain", "vanish").
@export var special: String = ""
@export_group("")
## Where it is found or how it is obtained (shown in the item details).
@export var source: String = ""


func is_weapon() -> bool:
	return weapon_kind != "" and weapon_kind != "shield"


func slot_name() -> String:
	return String(SLOT_NAMES.get(equip_slot, equip_slot.capitalize()))


func is_equipment() -> bool:
	return category == Category.EQUIPMENT or category == Category.COSMETIC


func is_usable() -> bool:
	return not use_effect.is_empty()


func rarity_color() -> Color:
	return RARITY_COLORS[rarity]


func category_name() -> String:
	return String(Category.keys()[category]).capitalize()
