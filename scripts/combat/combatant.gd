class_name Combatant
extends RefCounted
## Runtime state of one participant in a battle (player or creature).

const K := StatusEffectData.Kind

var uid: int = 0
var display_name: String = ""
var team: int = 0
var max_hp: int = 1
var hp: int = 1
var base_defense: int = 0
## Percent damage bonus for creatures.
var power: int = 0
var element: String = "fungal"
var speed: int = 10
var level: int = 1
var data: CreatureData
## Each: {"data": StatusEffectData, "remaining": int, "magnitude": float}
var statuses: Array[Dictionary] = []
var cooldowns: Dictionary = {}
var charging: SpellData
var charge_left: int = 0
var phase: int = 0


func is_alive() -> bool:
	return hp > 0


func hp_ratio() -> float:
	return float(hp) / float(maxi(1, max_hp))


func _sum(kind: int) -> float:
	var total := 0.0
	for s: Dictionary in statuses:
		if (s["data"] as StatusEffectData).kind == kind:
			total += float(s["magnitude"])
	return total


func defense() -> float:
	return base_defense + _sum(K.ARMOR)


func shield() -> int:
	return int(_sum(K.SHIELD))


func damage_out_mult() -> float:
	return maxf(0.1, 1.0 + _sum(K.EMPOWER) - _sum(K.WEAKEN))


func damage_in_mult() -> float:
	return 1.0 + _sum(K.VULNERABLE)


func evasion() -> float:
	return clampf(_sum(K.EVASION), 0.0, 0.8)


func is_stunned() -> bool:
	return _sum(K.STUN) > 0.0 or has_kind(K.STUN)


func has_kind(kind: int) -> bool:
	for s: Dictionary in statuses:
		if (s["data"] as StatusEffectData).kind == kind:
			return true
	return false


func has_status(id: String) -> bool:
	for s: Dictionary in statuses:
		if (s["data"] as StatusEffectData).id == id:
			return true
	return false


## Applies or refreshes a status. Returns the resulting instance.
func add_status(fx: StatusEffectData, magnitude: float) -> Dictionary:
	for s: Dictionary in statuses:
		if (s["data"] as StatusEffectData).id == fx.id:
			s["remaining"] = maxi(int(s["remaining"]), fx.duration)
			s["magnitude"] = float(s["magnitude"]) + magnitude if fx.stacks else maxf(float(s["magnitude"]), magnitude)
			return s
	var inst := {"data": fx, "remaining": fx.duration, "magnitude": magnitude}
	statuses.append(inst)
	return inst


## Shields absorb damage first. Returns the amount absorbed.
func absorb(amount: int) -> int:
	var absorbed := 0
	for s: Dictionary in statuses:
		if amount <= 0:
			break
		if (s["data"] as StatusEffectData).kind != K.SHIELD:
			continue
		var take := mini(int(s["magnitude"]), amount)
		s["magnitude"] = float(s["magnitude"]) - take
		amount -= take
		absorbed += take
	statuses = statuses.filter(func(s: Dictionary) -> bool:
		return not ((s["data"] as StatusEffectData).kind == K.SHIELD and float(s["magnitude"]) <= 0.0))
	return absorbed


func status_summary() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s: Dictionary in statuses:
		var d: StatusEffectData = s["data"]
		out.append({"id": d.id, "name": d.display_name, "glyph": d.glyph, "color": d.color, "remaining": int(s["remaining"]), "magnitude": float(s["magnitude"]), "description": d.description})
	return out
