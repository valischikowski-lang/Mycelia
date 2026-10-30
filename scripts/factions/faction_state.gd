class_name FactionState
extends RefCounted
## Reputation with the four callings' factions (-100..100) plus temporary
## disguises. Standing tiers drive how faction NPCs react: hostile (< -50),
## wary (< 0), neutral (< 25), friendly (< 60), honored.

signal changed(faction_id: String, rep: int)

const PATH := "res://resources/factions/factions.json"
const TIERS := ["hostile", "wary", "neutral", "friendly", "honored"]
static var _data: Dictionary = {}

var rep: Dictionary = {}
## {"faction": id, "until": play_time seconds}
var disguise: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_data = parsed
	return _data


static func info(fid: String) -> Dictionary:
	return data().get(fid, {})


static func faction_of_class(cls: String) -> String:
	for fid: String in data().keys():
		if String(data()[fid].get("class", "")) == cls:
			return fid
	return ""


## Your own calling starts friendly; the other three are wary of you.
func start(class_id: String) -> void:
	rep.clear()
	for fid: String in data().keys():
		rep[fid] = 30 if String(data()[fid].get("class", "")) == class_id else -20


func get_rep(fid: String) -> int:
	return int(rep.get(fid, 0))


func change(fid: String, delta: int) -> void:
	if not data().has(fid):
		return
	rep[fid] = clampi(get_rep(fid) + delta, -100, 100)
	changed.emit(fid, int(rep[fid]))


static func tier_of(value: int) -> String:
	if value < -50:
		return "hostile"
	if value < 0:
		return "wary"
	if value < 25:
		return "neutral"
	if value < 60:
		return "friendly"
	return "honored"


## Standing as NPCs see it: a disguise passes you off as neutral at least.
func standing(fid: String, play_time: float) -> String:
	var t := tier_of(get_rep(fid))
	if is_disguised_as(fid, play_time) and TIERS.find(t) < TIERS.find("neutral"):
		return "neutral"
	return t


func is_disguised_as(fid: String, play_time: float) -> bool:
	return String(disguise.get("faction", "")) == fid and float(disguise.get("until", 0.0)) > play_time


## Merchants charge outsiders more and their own people less.
func price_mult(fid: String, play_time: float) -> float:
	match standing(fid, play_time):
		"honored":
			return 0.8
		"friendly":
			return 0.9
		"neutral":
			return 1.0
		"wary":
			return 1.3
	return 99.0


func to_dict() -> Dictionary:
	return {"rep": rep.duplicate(), "disguise": disguise.duplicate()}


func from_dict(d: Dictionary) -> void:
	rep.clear()
	var r: Dictionary = d.get("rep", {})
	for k: String in r.keys():
		rep[k] = int(r[k])
	disguise = d.get("disguise", {})
