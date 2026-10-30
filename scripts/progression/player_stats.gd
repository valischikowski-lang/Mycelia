class_name PlayerStats
extends RefCounted
## Level, experience and attributes. Bonuses from equipment and skills are
## pushed in by PlayerProfile.recalculate().

signal changed()
signal leveled_up(new_level: int)

const MAX_LEVEL := 50
const BASE: Dictionary = {
	"max_health": 100.0, "max_mana": 6.0, "magic_power": 10.0,
	"defense": 4.0, "crit_chance": 5.0, "spell_power": 0.0,
	"evasion": 0.0, "magic_resist": 0.0, "health_regen": 0.0, "mana_regen": 0.0,
}
const GROWTH: Dictionary = {
	"max_health": 14.0, "max_mana": 0.5, "magic_power": 2.0,
	"defense": 1.0, "crit_chance": 0.4, "spell_power": 3.0,
}
const STAT_NAMES: Dictionary = {
	"max_health": "Health", "max_mana": "Mana", "magic_power": "Magic Power",
	"defense": "Defense", "crit_chance": "Critical Chance", "spell_power": "Spell Power",
	"evasion": "Evasion %", "magic_resist": "Magic Resist %", "health_regen": "Health Regen /s", "mana_regen": "Mana Regen",
}

var level: int = 1
var xp: int = 0
var skill_points: int = 0
var health: float = 100.0
var mana: float = 6.0
var bonuses: Dictionary = {}


static func xp_for_level(lvl: int) -> int:
	return int(round(40.0 * pow(float(lvl), 1.6))) + 20


func xp_to_next() -> int:
	return xp_for_level(level)


func get_stat(stat: String) -> float:
	var v: float = float(BASE.get(stat, 0.0)) + float(GROWTH.get(stat, 0.0)) * float(level - 1)
	return v + float(bonuses.get(stat, 0.0))


func max_health() -> int:
	return int(get_stat("max_health"))


func max_mana() -> int:
	return int(get_stat("max_mana"))


## Returns the number of levels gained.
func add_xp(amount: int) -> int:
	if amount <= 0 or level >= MAX_LEVEL:
		return 0
	xp += amount
	var gained := 0
	while level < MAX_LEVEL and xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		skill_points += 1
		gained += 1
		health = max_health()
		mana = max_mana()
		leveled_up.emit(level)
	changed.emit()
	return gained


func heal(amount: float) -> void:
	health = clampf(health + amount, 0.0, max_health())
	changed.emit()


func restore_mana(amount: float) -> void:
	mana = clampf(mana + amount, 0.0, max_mana())
	changed.emit()


func full_restore() -> void:
	health = max_health()
	mana = max_mana()
	changed.emit()


func clamp_pools() -> void:
	health = clampf(health, 0.0, max_health())
	mana = clampf(mana, 0.0, max_mana())


func to_dict() -> Dictionary:
	return {"level": level, "xp": xp, "skill_points": skill_points, "health": health, "mana": mana}


func from_dict(d: Dictionary) -> void:
	level = clampi(int(d.get("level", 1)), 1, MAX_LEVEL)
	xp = maxi(0, int(d.get("xp", 0)))
	skill_points = maxi(0, int(d.get("skill_points", 0)))
	health = float(d.get("health", get_stat("max_health")))
	mana = float(d.get("mana", get_stat("max_mana")))
	clamp_pools()
	changed.emit()
