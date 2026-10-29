class_name SpellData
extends Resource
## A spell card (player) or creature ability. One resource type serves both so
## creatures and the player share the same resolution rules.

enum TargetType { SINGLE_ENEMY, ALL_ENEMIES, SELF, RANDOM_ENEMY }
enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
## fungal | crystal | nature | cosmic | chaos
@export var element: String = "fungal"
@export var mana_cost: int = 1
@export var base_damage: int = 0
@export var damage_variance: float = 0.1
@export var healing_value: int = 0
@export_range(0.0, 1.0) var accuracy: float = 0.95
@export var target_type: TargetType = TargetType.SINGLE_ENEMY
@export var target_count: int = 1
## Status effects applied to targets (or self when the effect says so).
@export var status_effects: Array[StatusEffectData] = []
## Default duration hint shown on the card for effects with no own duration.
@export var duration: int = 0
@export var rarity: Rarity = Rarity.COMMON
## Fraction of target defense ignored.
@export_range(0.0, 1.0) var armor_pierce: float = 0.0
@export var mana_gain: int = 0
@export var draw_cards: int = 0
## Identifier for special-case logic in BattleRules (e.g. "chaos_rift").
@export var special: String = ""
## Visual configuration consumed by SpellVFX.
@export var vfx_style: String = "fungal_spore"
@export var icon_glyph: String = "✺"
@export var icon: Texture2D
@export var visual_effect_scene: PackedScene
@export var sound_cast: String = ""
@export var sound_impact: String = ""
@export var animation: Dictionary = {"cast_time": 0.45, "travel_time": 0.5}
# --- creature-ability only ---
@export var cooldown: int = 0
@export var ai_tags: PackedStringArray = []
@export var min_phase: int = 0
## Turns of telegraphed charge before the ability fires (boss mechanic).
@export var charge_turns: int = 0


func is_offensive() -> bool:
	return target_type in [TargetType.SINGLE_ENEMY, TargetType.ALL_ENEMIES, TargetType.RANDOM_ENEMY]


func needs_target_choice() -> bool:
	return target_type == TargetType.SINGLE_ENEMY


func summary_line() -> String:
	var parts: PackedStringArray = []
	if base_damage > 0:
		parts.append("%d dmg" % base_damage)
	if healing_value > 0:
		parts.append("+%d hp" % healing_value)
	for fx: StatusEffectData in status_effects:
		parts.append(fx.display_name)
	if mana_gain > 0:
		parts.append("+%d mana" % mana_gain)
	if draw_cards > 0:
		parts.append("draw %d" % draw_cards)
	return " · ".join(parts)
