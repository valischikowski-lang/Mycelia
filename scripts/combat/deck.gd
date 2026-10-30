class_name Deck
extends RefCounted
## Draw pile / hand / discard pile for spell cards (stored as spell ids).

var draw_pile: Array[String] = []
var hand: Array[String] = []
var discard: Array[String] = []
var hand_size: int = 4
var reshuffles: int = 0
var _rng: RandomNumberGenerator


func setup(cards: PackedStringArray, rng: RandomNumberGenerator) -> void:
	_rng = rng
	draw_pile.clear()
	hand.clear()
	discard.clear()
	for c: String in cards:
		draw_pile.append(c)
	_shuffle(draw_pile)


func _shuffle(arr: Array[String]) -> void:
	# Fisher-Yates with the battle's seeded RNG (deterministic).
	for i in range(arr.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp := arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


## Draws up to n cards; reshuffles the discard pile when the draw pile empties.
func draw(n: int) -> int:
	var drawn := 0
	for i in n:
		if draw_pile.is_empty():
			if discard.is_empty():
				break
			draw_pile = discard.duplicate()
			discard.clear()
			_shuffle(draw_pile)
			reshuffles += 1
		hand.append(draw_pile.pop_back())
		drawn += 1
	return drawn


func fill_hand() -> int:
	return draw(maxi(0, hand_size - hand.size()))


## Moves a card from hand to discard and returns its id.
func play(index: int) -> String:
	if index < 0 or index >= hand.size():
		return ""
	var id := hand[index]
	hand.remove_at(index)
	discard.append(id)
	return id


## Card replacement rule: discard one card and draw a new one.
func replace(index: int) -> String:
	var old := play(index)
	if old == "":
		return ""
	draw(1)
	# Keep the new card in the same slot for a stable UI.
	if hand.size() > index:
		var new_card: String = hand.pop_back()
		hand.insert(index, new_card)
	return old


func total() -> int:
	return draw_pile.size() + hand.size() + discard.size()
