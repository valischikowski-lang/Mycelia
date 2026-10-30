class_name EnemyAI
extends RefCounted
## Utility-based enemy decisions. Each usable ability is scored from the
## battle situation (own health, player health, shields, existing statuses,
## elemental advantage, cooldowns, boss phase) and weighted by personality.
## Ties are broken by a small seeded jitter so behaviour stays deterministic.

const P := CreatureData.Personality
const K := StatusEffectData.Kind


static func choose(state: BattleState, enemy: Combatant) -> Dictionary:
	var best: SpellData = null
	var best_score := -INF
	var personality: int = enemy.data.personality if enemy.data else P.AGGRESSIVE
	for ab: SpellData in (enemy.data.abilities if enemy.data else []):
		if int(enemy.cooldowns.get(ab.id, 0)) > 0:
			continue
		if ab.min_phase > enemy.phase:
			continue
		var s := score(state, enemy, ab, personality)
		s += state.rng.randf() * (0.9 if personality == P.TRICKSTER else 0.25)
		if s > best_score:
			best_score = s
			best = ab
	return {"ability": best, "target": 0, "score": best_score}


static func score(state: BattleState, enemy: Combatant, ab: SpellData, personality: int) -> float:
	var tags := ab.ai_tags
	var player := state.player
	var s := 1.0
	var hp_ratio := enemy.hp_ratio()
	if "damage" in tags:
		var est := ab.base_damage * (1.0 + enemy.power / 100.0) * ElementChart.multiplier(ab.element, player.element) * enemy.damage_out_mult()
		s += 1.0 + est / maxf(10.0, float(player.max_hp)) * 6.0
		if est >= player.hp + player.shield():
			s += 6.0
		if player.shield() > est:
			s -= 1.0
		if "big" in tags:
			s += 0.6
		if personality == P.AGGRESSIVE:
			s *= 1.5
		elif personality == P.TACTICAL:
			s += (ElementChart.multiplier(ab.element, player.element) - 1.0) * 3.0
	if "heal" in tags:
		if hp_ratio > 0.75:
			s -= 4.0
		else:
			s += (1.0 - hp_ratio) * 6.0
		if personality == P.DEFENSIVE:
			s *= 1.4
	if "shield" in tags or "defend" in tags:
		if enemy.shield() > 0 or enemy.has_kind(K.ARMOR) or enemy.has_kind(K.EVASION):
			s -= 4.0
		else:
			s += (1.0 - hp_ratio) * 3.0 + (1.0 if player.hp_ratio() > 0.6 else 0.0)
		if personality == P.DEFENSIVE:
			s *= 1.6
		elif personality == P.AGGRESSIVE:
			s *= 0.5
	if "buff" in tags:
		if enemy.has_kind(K.EMPOWER) or enemy.has_kind(K.ARMOR) or enemy.has_kind(K.EVASION):
			s -= 3.0
		else:
			s += 1.2
	if "dot" in tags:
		var has_dot := false
		for fx: StatusEffectData in ab.status_effects:
			if player.has_status(fx.id):
				has_dot = true
		s += -1.5 if has_dot else 1.0
	if "charge" in tags:
		# Bosses love a dramatic telegraphed attack, but not every turn.
		s += 2.5 if personality == P.BOSS else 0.5
		if player.has_kind(K.SHIELD):
			s -= 1.5
	if personality == P.BOSS and ab.min_phase > 0:
		s += 1.5
	return s
