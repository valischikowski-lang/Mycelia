class_name StatusEffectData
extends Resource
## A status effect template applied by spells or abilities.

enum Kind { DOT, HOT, SHIELD, STUN, WEAKEN, VULNERABLE, EMPOWER, EVASION, ARMOR, CHARGE, SUMMON }

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var kind: Kind = Kind.DOT
## DOT/HOT: points per turn. SHIELD: absorb amount. WEAKEN/VULNERABLE/EMPOWER: fraction (0.3 = 30%).
## EVASION: miss chance. ARMOR: flat defense. SUMMON: damage dealt to a random
## enemy at the start of the owner's turn.
@export var magnitude: float = 0.0
@export var duration: int = 2
@export var element: String = "fungal"
@export var color: Color = Color(0.6, 1.0, 0.4)
@export var glyph: String = "•"
## Chance that the effect lands (0..1).
@export var chance: float = 1.0
## True: applying again refreshes duration and adds magnitude. False: refresh only.
@export var stacks: bool = false
@export var apply_to_self: bool = false


func is_harmful() -> bool:
	return kind in [Kind.DOT, Kind.STUN, Kind.WEAKEN, Kind.VULNERABLE]
