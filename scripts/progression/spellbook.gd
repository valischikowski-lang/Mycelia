class_name Spellbook
extends RefCounted
## Known spells and the player's combat deck configuration.

signal changed()

const DECK_MIN := 6
const DECK_MAX := 20
const MAX_COPIES := 3

var known: PackedStringArray = []
## spell id -> copies in deck
var deck: Dictionary = {}


func knows(id: String) -> bool:
	return id in known


## Returns true if the spell was new.
func unlock(id: String, auto_add_copies: int = 2) -> bool:
	if knows(id):
		return false
	known.append(id)
	var room := DECK_MAX - deck_size()
	var copies := mini(auto_add_copies, room)
	if copies > 0:
		deck[id] = copies
	changed.emit()
	return true


func deck_size() -> int:
	var n := 0
	for k: String in deck.keys():
		n += int(deck[k])
	return n


func copies(id: String) -> int:
	return int(deck.get(id, 0))


func set_copies(id: String, n: int) -> bool:
	if not knows(id):
		return false
	n = clampi(n, 0, MAX_COPIES)
	var new_size := deck_size() - copies(id) + n
	if new_size > DECK_MAX or new_size < DECK_MIN:
		return false
	if n == 0:
		deck.erase(id)
	else:
		deck[id] = n
	changed.emit()
	return true


## Flat list of spell ids, one entry per copy.
func build_deck_list() -> PackedStringArray:
	var out := PackedStringArray()
	for id: String in deck.keys():
		for i in int(deck[id]):
			out.append(id)
	return out


func to_dict() -> Dictionary:
	return {"known": Array(known), "deck": deck.duplicate()}


func from_dict(d: Dictionary, valid: Callable = Callable()) -> void:
	known.clear()
	deck.clear()
	for id: Variant in d.get("known", []):
		var s := String(id)
		if not valid.is_valid() or bool(valid.call(s)):
			known.append(s)
	var raw: Variant = d.get("deck", {})
	if raw is Dictionary:
		for id: String in (raw as Dictionary).keys():
			if knows(id):
				deck[id] = clampi(int(raw[id]), 0, MAX_COPIES)
	changed.emit()
