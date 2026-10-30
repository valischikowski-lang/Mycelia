extends SceneTree
## MYCELIA content builder. Authors all data Resources (.tres) from the
## definitions below so the files are always valid and consistent.
## Re-run after editing:  godot --headless --script res://tools/build_content.gd
## The generated .tres files are the source of truth for the game and can
## also be tweaked in the Godot inspector afterwards.

const SK := StatusEffectData.Kind
const TT := SpellData.TargetType

var fx: Dictionary = {}
var spells: Dictionary = {}
var creatures: Dictionary = {}
var _count := 0


func _init() -> void:
	build_biomes()
	build_status_effects()
	build_spells()
	build_creature_abilities_and_creatures()
	build_encounters()
	build_items()
	build_quests()
	print("build_content: wrote %d resources" % _count)
	quit()


func save(res: Resource, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	res.take_over_path(path)
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("Failed to save %s: %s" % [path, error_string(err)])
	_count += 1


func c(hex: String) -> Color:
	return Color(hex)


# ------------------------------------------------------------------ biomes
func build_biomes() -> void:
	var b := BiomeData.new()
	b.id = "dreaming_meadow"
	b.display_name = "The Dreaming Meadow"
	# Dark fantasy night: indigo and near-black, cold moonlight, sickly green
	# mycelium, and warm amber as the only cosy colour (windows, lanterns).
	b.sky_top = c("#020208")
	b.sky_mid = c("#0b0c33")
	b.sky_horizon = c("#24124a")
	b.sky_band = c("#3d63ff")
	b.moon_color = c("#ffcf73")
	b.sun_color = c("#8a96ff")
	b.sun_energy = 0.42
	b.sun_rotation_deg = Vector3(-38, 205, 0)
	b.ambient_color = c("#1b1a4a")
	b.ambient_energy = 0.38
	b.fog_color = c("#121338")
	b.fog_density = 0.0085
	b.fog_height = 0.5
	b.fog_height_density = 0.05
	b.grass_color = c("#0a2a28")
	b.grass_tip_color = c("#1f5a48")
	b.moss_color = c("#2a1c52")
	b.path_color = c("#3a3552")
	b.rock_color = c("#1d1733")
	b.vein_color = c("#5dffb0")
	b.mushroom_caps = [c("#2c0f52"), c("#45106a"), c("#191a66"), c("#5c0f38"), c("#0f3046"), c("#3a1a5e")]
	b.mushroom_glow = [c("#6dffb0"), c("#ffb347"), c("#b18cff"), c("#4ad9ff")]
	b.flower_colors = [c("#8a1f4a"), c("#c2652a"), c("#5a2a8a"), c("#2a6a8a"), c("#e0a84a")]
	b.crystal_colors = [c("#3a4cff"), c("#7a3cff"), c("#2ad1ff"), c("#5a2aff")]
	b.foliage_colors = [c("#0f3a3a"), c("#1d2a5a"), c("#2a1a4a"), c("#12402a")]
	b.bark_colors = [c("#120c1c"), c("#1c1028"), c("#0e0a14")]
	b.music = "music_meadow"
	b.ambience = "meadow_ambience"
	save(b, "res://resources/biomes/dreaming_meadow.tres")

	var a := b.duplicate() as BiomeData
	a.id = "dream_arena"
	a.display_name = "The Dreaming Arena"
	a.sky_top = c("#010106")
	a.sky_mid = c("#120a3a")
	a.sky_horizon = c("#3a0f3a")
	a.sky_band = c("#5a7aff")
	a.fog_density = 0.003
	a.sun_rotation_deg = Vector3(-40, 150, 0)
	save(a, "res://resources/biomes/dream_arena.tres")


# ------------------------------------------------------------------ status
func effect(id: String, name: String, kind: int, mag: float, dur: int, element: String, col: String, glyph: String, desc: String, chance := 1.0, to_self := false, stacks := false) -> StatusEffectData:
	var e := StatusEffectData.new()
	e.id = id
	e.display_name = name
	e.kind = kind
	e.magnitude = mag
	e.duration = dur
	e.element = element
	e.color = c(col)
	e.glyph = glyph
	e.description = desc
	e.chance = chance
	e.apply_to_self = to_self
	e.stacks = stacks
	save(e, "res://resources/status_effects/%s.tres" % id)
	fx[id] = e
	return e


func build_status_effects() -> void:
	effect("spore_rot", "Spore Rot", SK.DOT, 3, 3, "fungal", "#c44dff", "✺", "Spores feed on the target: damage each turn.", 1.0, false, true)
	effect("spore_rot_weak", "Spore Rot", SK.DOT, 2, 2, "fungal", "#c44dff", "✺", "Spores feed on the target: damage each turn.", 1.0, false, true)
	effect("golem_rot", "Ancient Rot", SK.DOT, 4, 3, "fungal", "#9d3cff", "✺", "Old, patient spores. Damage each turn.", 1.0, false, true)
	effect("regrowth", "Regrowth", SK.HOT, 6, 3, "nature", "#7dff5a", "❦", "Living sap restores health each turn.")
	effect("prism_shield", "Prism Ward", SK.SHIELD, 16, 3, "crystal", "#4ff3ff", "◆", "A refracting barrier absorbs incoming damage.", 1.0, true)
	effect("rooted", "Rooted", SK.STUN, 0, 1, "nature", "#9cff4a", "⚘", "Roots hold the target fast: it loses its next action.", 0.7)
	effect("weightless", "Weightless", SK.WEAKEN, 0.3, 2, "cosmic", "#ffe36a", "✶", "Gravity forgets the target: its attacks deal 30% less.")
	effect("shattered", "Shattered", SK.VULNERABLE, 0.25, 2, "crystal", "#7fe9ff", "✧", "Cracked defenses: takes 25% more damage.")
	effect("glitter_curse", "Glitter Curse", SK.VULNERABLE, 0.2, 2, "chaos", "#ff5fc8", "✹", "Reality sparkles wrongly around the target: +20% damage taken.")
	effect("empowered", "Empowered", SK.EMPOWER, 0.35, 2, "cosmic", "#ffd54a", "☼", "Deals 35% more damage.", 1.0, true)
	effect("golem_roar", "Awakened", SK.EMPOWER, 0.4, 3, "fungal", "#ff8a2a", "☼", "The golem's network roars awake: +40% damage.", 1.0, true)
	effect("dream_veil", "Dream Veil", SK.EVASION, 0.45, 2, "cosmic", "#b4a0ff", "☾", "Half-real: 45% chance to avoid attacks.", 1.0, true)
	effect("carapace", "Carapace", SK.ARMOR, 8, 2, "crystal", "#43b8ff", "⬢", "Hardened shell: +8 defense.", 1.0, true)
	effect("bark_skin", "Bark Skin", SK.ARMOR, 10, 3, "nature", "#8ac24a", "⬢", "Thick bark: +10 defense.", 1.0, true)
	effect("beetle_glint", "Shell Glint", SK.SHIELD, 10, 2, "crystal", "#43b8ff", "◆", "Absorbs damage.", 1.0, true)
	effect("hollow_quiver", "Quivering Husk", SK.SHIELD, 8, 2, "chaos", "#ff5fc8", "◆", "Absorbs damage.", 1.0, true)
	effect("mycelial_armor", "Mycelial Armor", SK.SHIELD, 28, 3, "fungal", "#c44dff", "◆", "A lattice of living threads absorbs damage.", 1.0, true)
	effect("hexed", "Hexed", SK.WEAKEN, 0.25, 2, "chaos", "#9dff3a", "☠", "A crone's curse sours your strength: attacks deal 25% less.")
	effect("crone_brew", "Bitter Brew", SK.HOT, 5, 2, "chaos", "#7dff5a", "♨", "Something green and bubbling restores health each turn.", 1.0, true)
	effect("gremlin_giggle", "Giggling", SK.EMPOWER, 0.3, 2, "chaos", "#b6ff3a", "☼", "Giggling madly: +30% damage.", 1.0, true)
	effect("sentinel", "Spore Sentinel", SK.SUMMON, 7, 3, "fungal", "#e07bff", "♟", "A small fungal guardian strikes an enemy each turn.", 1.0, true)


# ------------------------------------------------------------------ spells
func spell(id: String, name: String, element: String, cost: int, dmg: int, heal: int, target: int, desc: String, opts := {}) -> SpellData:
	var s := SpellData.new()
	s.id = id
	s.display_name = name
	s.element = element
	s.mana_cost = cost
	s.base_damage = dmg
	s.healing_value = heal
	s.target_type = target
	s.description = desc
	s.accuracy = float(opts.get("accuracy", 0.95))
	s.armor_pierce = float(opts.get("pierce", 0.0))
	s.mana_gain = int(opts.get("mana_gain", 0))
	s.draw_cards = int(opts.get("draw", 0))
	s.special = String(opts.get("special", ""))
	s.vfx_style = String(opts.get("vfx", element))
	s.icon_glyph = String(opts.get("glyph", ElementChart.glyph(element)))
	s.rarity = int(opts.get("rarity", 0))
	s.cooldown = int(opts.get("cooldown", 0))
	s.ai_tags = PackedStringArray(opts.get("tags", []))
	s.min_phase = int(opts.get("phase", 0))
	s.charge_turns = int(opts.get("charge", 0))
	s.damage_variance = float(opts.get("variance", 0.1))
	s.sound_cast = "cast_" + element
	s.sound_impact = "impact_" + element
	var fxs: Array[StatusEffectData] = []
	for e: String in opts.get("effects", []):
		fxs.append(fx[e])
	s.status_effects = fxs
	if not fxs.is_empty():
		s.duration = fxs[0].duration
	var folder := String(opts.get("folder", "spells"))
	save(s, "res://resources/%s/%s.tres" % [folder, id])
	spells[id] = s
	return s


func build_spells() -> void:
	var E := TT.SINGLE_ENEMY
	var A := TT.ALL_ENEMIES
	var S := TT.SELF
	spell("thornlash", "Thornlash", "nature", 0, 6, 0, E, "A whip of dream-thorns, always within reach. Costs nothing.", {"glyph": "❦", "vfx": "nature_thorn"})
	spell("prism_ward", "Prism Ward", "crystal", 2, 0, 0, S, "Fold light into a faceted barrier that absorbs 16 damage for 3 turns.", {"effects": ["prism_shield"], "vfx": "crystal_shield", "glyph": "◆"})
	spell("sporeburst", "Sporeburst", "fungal", 1, 9, 0, E, "Hurl a puffball that bursts into hungry spores. Inflicts Spore Rot.", {"effects": ["spore_rot"], "vfx": "fungal_spore", "glyph": "✺"})
	spell("mycelial_mend", "Mycelial Mend", "fungal", 2, 0, 24, S, "Threads of the Mycelium knit your wounds closed.", {"vfx": "fungal_heal", "glyph": "✚"})
	spell("puffcap_cascade", "Puffcap Cascade", "fungal", 3, 11, 0, A, "Mushrooms erupt beneath every enemy at once.", {"vfx": "fungal_eruption", "glyph": "✺", "rarity": 1})
	spell("rootbind", "Rootbind", "nature", 2, 7, 0, E, "Roots burst from the ground and seize the foe. 70% chance to Root (skip a turn).", {"effects": ["rooted"], "vfx": "nature_vines", "glyph": "⚘", "rarity": 1})
	spell("shardstorm", "Shardstorm", "crystal", 3, 18, 0, E, "A fan of razor prisms that ignores half of armor and leaves the target Shattered.", {"effects": ["shattered"], "pierce": 0.5, "vfx": "crystal_shards", "glyph": "✧", "rarity": 1})
	spell("gravity_well", "Gravity Well", "cosmic", 3, 6, 0, A, "Open a tiny collapsing star. All enemies become Weightless (deal 30% less).", {"effects": ["weightless"], "vfx": "cosmic_gravity", "glyph": "◎", "rarity": 2})
	spell("starfall_seed", "Starfall Seed", "cosmic", 5, 34, 0, E, "Plant a seed in the sky. A star grows from it — and falls.", {"accuracy": 0.85, "vfx": "cosmic_star", "glyph": "✶", "rarity": 3})
	spell("kaleidoscope_rift", "Kaleidoscope Rift", "chaos", 2, 0, 0, E, "Tear a hole in what is real. Deals 4–30 damage. Something else may happen.", {"special": "chaos_rift", "vfx": "chaos_rift", "glyph": "✹", "rarity": 2})
	spell("wild_bloom", "Wild Bloom", "nature", 3, 0, 8, S, "A flower opens inside your chest. Heals now and every turn after.", {"effects": ["regrowth"], "vfx": "nature_bloom", "glyph": "✿", "rarity": 1})
	spell("paradox_gift", "Paradox Gift", "chaos", 1, 0, 0, S, "Borrow 3 mana and a card from a future you. They won't mind. Probably.", {"mana_gain": 3, "draw": 1, "vfx": "chaos_gift", "glyph": "∞", "rarity": 2})
	spell("spore_sentinel", "Spore Sentinel", "fungal", 3, 0, 0, S, "Grow a tiny fungal guardian that strikes an enemy each turn for 3 turns.", {"effects": ["sentinel"], "vfx": "fungal_summon", "glyph": "♟", "rarity": 2})
	spell("rot_bloom", "Rot Bloom", "fungal", 4, 14, 0, A, "The meadow remembers every fallen leaf. Damages all enemies and infects them with Spore Rot.", {"effects": ["spore_rot"], "vfx": "fungal_eruption", "glyph": "❁", "rarity": 3})


func ability(id: String, name: String, element: String, dmg: int, heal: int, target: int, desc: String, opts := {}) -> SpellData:
	opts["folder"] = "creatures/abilities"
	return spell(id, name, element, 0, dmg, heal, target, desc, opts)


func creature(id: String, name: String, element: String, hp: int, defense: int, power: int, speed: int, abilities: Array, personality: int, xp: int, glim: Vector2i, loot: Array, kind: String, opts := {}) -> CreatureData:
	var cr := CreatureData.new()
	cr.id = id
	cr.display_name = name
	cr.element = element
	cr.max_health = hp
	cr.defense = defense
	cr.power = power
	cr.speed = speed
	var ab: Array[SpellData] = []
	for a: String in abilities:
		ab.append(spells[a])
	cr.abilities = ab
	cr.personality = personality
	cr.xp_reward = xp
	cr.glimmer_min = glim.x
	cr.glimmer_max = glim.y
	var lt: Array[Dictionary] = []
	for l: Dictionary in loot:
		lt.append(l)
	cr.loot_table = lt
	cr.visual_kind = kind
	cr.level = int(opts.get("level", 1))
	cr.visual_scale = float(opts.get("scale", 1.0))
	cr.tint = opts.get("tint", Color.WHITE)
	cr.world_behavior = String(opts.get("behavior", "hostile"))
	cr.description = String(opts.get("desc", ""))
	cr.lore = String(opts.get("lore", ""))
	cr.phase_thresholds = PackedFloat32Array(opts.get("phases", []))
	save(cr, "res://resources/creatures/%s.tres" % id)
	creatures[id] = cr
	return cr


func build_creature_abilities_and_creatures() -> void:
	var E := TT.SINGLE_ENEMY
	var S := TT.SELF
	var P := CreatureData.Personality
	ability("nibble", "Nibble", "fungal", 5, 0, E, "A surprisingly toothy nibble.", {"tags": ["damage"], "vfx": "melee"})
	ability("spore_puff", "Spore Puff", "fungal", 3, 0, E, "A sneeze of spores.", {"effects": ["spore_rot_weak"], "tags": ["damage", "dot"], "cooldown": 2, "vfx": "fungal_spore"})
	ability("glitch_bite", "Glitch Bite", "chaos", 7, 0, E, "Its mouth opens wider than it should.", {"tags": ["damage"], "vfx": "melee"})
	ability("void_puff", "Hollow Puff", "chaos", 4, 0, E, "Grey spores that smell like forgetting.", {"effects": ["spore_rot_weak"], "tags": ["damage", "dot"], "cooldown": 2, "vfx": "chaos_rift"})
	ability("quiver", "Quiver", "chaos", 0, 0, S, "Its husk hardens and flickers.", {"effects": ["hollow_quiver"], "tags": ["shield"], "cooldown": 3, "vfx": "crystal_shield"})
	ability("mandible_snap", "Mandible Snap", "crystal", 7, 0, E, "Crystal jaws close with a chime.", {"tags": ["damage"], "vfx": "melee"})
	ability("carapace_shine", "Carapace Shine", "crystal", 0, 0, S, "Its shell catches the moonlight and hardens.", {"effects": ["carapace", "beetle_glint"], "tags": ["shield", "buff"], "cooldown": 3, "vfx": "crystal_shield"})
	ability("refracting_charge", "Refracting Charge", "crystal", 12, 0, E, "It charges, splitting into three glittering afterimages.", {"tags": ["damage", "big"], "cooldown": 3, "vfx": "crystal_shards"})
	ability("starlit_pounce", "Starlit Pounce", "cosmic", 9, 0, E, "A leap that leaves footprints of light in the air.", {"tags": ["damage"], "vfx": "melee"})
	ability("moon_veil", "Moon Veil", "cosmic", 0, 0, S, "The fox becomes mostly a rumour.", {"effects": ["dream_veil"], "tags": ["buff", "defend"], "cooldown": 3, "vfx": "cosmic_gravity"})
	ability("moonlight_lick", "Moonlight Lick", "cosmic", 0, 14, S, "It licks its paw; the paw glows; the wound closes.", {"tags": ["heal"], "cooldown": 3, "vfx": "fungal_heal"})
	ability("thorn_crush", "Thorn Crush", "nature", 14, 0, E, "A fist of braided thorns.", {"tags": ["damage", "big"], "vfx": "nature_vines"})
	ability("petal_storm", "Petal Storm", "nature", 8, 0, E, "A whirlwind of razor petals.", {"tags": ["damage"], "vfx": "nature_bloom"})
	ability("photosynthesis", "Photosynthesis", "nature", 0, 22, S, "It turns its face to the moon and drinks.", {"tags": ["heal"], "cooldown": 3, "vfx": "nature_bloom"})
	ability("bark_up", "Bark Skin", "nature", 0, 0, S, "Its stem thickens with bark.", {"effects": ["bark_skin"], "tags": ["buff", "defend"], "cooldown": 4, "vfx": "crystal_shield"})
	ability("fungal_slam", "Fungal Slam", "fungal", 15, 0, E, "A slow, enormous fist of compressed spores.", {"tags": ["damage"], "vfx": "fungal_eruption"})
	ability("spore_cloud", "Spore Cloud", "fungal", 6, 0, E, "Ancient spores fill the air.", {"effects": ["golem_rot"], "tags": ["damage", "dot"], "cooldown": 3, "vfx": "fungal_spore"})
	ability("network_pulse", "Network Pulse", "fungal", 34, 0, E, "The golem draws power from the whole meadow, then releases it.", {"tags": ["damage", "big", "charge"], "cooldown": 4, "charge": 1, "vfx": "fungal_eruption"})
	ability("mycelial_armor_up", "Mycelial Armor", "fungal", 0, 0, S, "Threads weave over its body.", {"effects": ["mycelial_armor"], "tags": ["shield"], "cooldown": 4, "phase": 1, "vfx": "crystal_shield"})
	ability("awakening_roar", "Awakening Roar", "fungal", 0, 0, S, "Every mushroom in the arena turns to face you.", {"effects": ["golem_roar"], "tags": ["buff"], "cooldown": 5, "phase": 1, "vfx": "cosmic_gravity"})
	ability("hex_bolt", "Hex Bolt", "chaos", 9, 0, E, "A crooked finger points. Something green follows it.", {"effects": ["hexed"], "tags": ["damage", "debuff"], "cooldown": 2, "vfx": "chaos_rift"})
	ability("cackle", "Cackle", "chaos", 0, 0, S, "A laugh that goes on far too long.", {"effects": ["dream_veil"], "tags": ["buff", "defend"], "cooldown": 3, "vfx": "cosmic_gravity"})
	ability("two_tooth_bite", "Two-Tooth Bite", "chaos", 11, 0, E, "Only two teeth left. Both of them very, very sharp.", {"tags": ["damage"], "vfx": "melee"})
	ability("brew_sip", "Sip of the Brew", "chaos", 0, 12, S, "She sips from a cauldron-cup. It smokes.", {"effects": ["crone_brew"], "tags": ["heal"], "cooldown": 4, "vfx": "fungal_heal"})
	ability("wrench_whack", "Wrench Whack", "chaos", 8, 0, E, "A rusty wrench, swung with joy.", {"tags": ["damage"], "vfx": "melee"})
	ability("spark_bomb", "Spark Bomb", "cosmic", 13, 0, E, "A tiny bomb with a long fuse and a short temper.", {"effects": ["shattered"], "tags": ["damage", "big"], "cooldown": 3, "vfx": "crystal_shards"})
	ability("giggle", "Giggle", "chaos", 0, 0, S, "Hee. Hee hee. HEE.", {"effects": ["gremlin_giggle"], "tags": ["buff"], "cooldown": 3, "vfx": "cosmic_gravity"})

	creature("sporeling", "Sporeling", "fungal", 30, 2, 0, 12, ["nibble", "spore_puff"], P.AGGRESSIVE, 22, Vector2i(2, 5),
		[{"item_id": "sporeling_cap", "chance": 0.6, "min": 1, "max": 2}, {"item_id": "mana_moss", "chance": 0.2, "min": 1, "max": 1}], "sporeling",
		{"desc": "A curious little walking mushroom.", "lore": "Sporelings are the Mycelium's way of looking around. They chirp when they find something interesting, which is everything."})
	creature("hollow_sporeling", "Hollow-Eyed Sporeling", "chaos", 42, 2, 10, 14, ["glitch_bite", "void_puff", "quiver"], P.AGGRESSIVE, 45, Vector2i(6, 10),
		[{"item_id": "sporeling_cap", "chance": 1.0, "min": 1, "max": 2}, {"item_id": "dewdrop_tonic", "chance": 0.5, "min": 1, "max": 1}], "sporeling",
		{"tint": Color(0.55, 0.5, 0.65), "desc": "A sporeling whose eyes have gone dark and hollow.", "lore": "Something has scooped the curiosity out of it. What remains still moves.", "level": 2})
	creature("crystal_beetle", "Crystal Beetle", "crystal", 46, 8, 0, 8, ["mandible_snap", "carapace_shine", "refracting_charge"], P.DEFENSIVE, 34, Vector2i(4, 8),
		[{"item_id": "beetle_shard", "chance": 0.7, "min": 1, "max": 2}, {"item_id": "dewdrop_tonic", "chance": 0.15, "min": 1, "max": 1}], "crystal_beetle",
		{"desc": "An armored insect that eats light.", "lore": "Crystal Beetles grow their shells from moonlight they swallow. Their song is a single, very patient note.", "level": 2})
	creature("dream_fox", "Dream Fox", "cosmic", 52, 4, 5, 18, ["starlit_pounce", "moon_veil", "moonlight_lick"], P.TACTICAL, 55, Vector2i(8, 14),
		[{"item_id": "fox_starfur", "chance": 0.8, "min": 1, "max": 1}], "dream_fox",
		{"behavior": "neutral", "desc": "Neither friendly nor not. It is deciding.", "lore": "The Dream Fox appears in the dreams of everyone who has ever slept in the meadow. Nobody remembers inviting it.", "level": 3})
	creature("bloom_guardian", "Bloom Guardian", "nature", 120, 6, 8, 6, ["thorn_crush", "petal_storm", "photosynthesis", "bark_up"], P.TACTICAL, 120, Vector2i(20, 30),
		[{"item_id": "bloom_petal", "chance": 1.0, "min": 2, "max": 3}, {"item_id": "dewdrop_tonic", "chance": 0.6, "min": 1, "max": 2}], "bloom_guardian",
		{"desc": "An ancient flower that guards the Rootstone Circle.", "lore": "Bloom Guardians were planted by whoever built the circles. They have been waiting so long they forgot for what.", "level": 4, "scale": 1.0})
	creature("spore_golem", "Ancient Spore Golem", "fungal", 260, 8, 10, 4, ["fungal_slam", "spore_cloud", "network_pulse", "mycelial_armor_up", "awakening_roar"], P.BOSS, 300, Vector2i(60, 90),
		[{"item_id": "golem_heartspore", "chance": 1.0, "min": 1, "max": 1}, {"item_id": "heartspore_amulet", "chance": 1.0, "min": 1, "max": 1}], "spore_golem",
		{"phases": [0.5], "behavior": "neutral", "desc": "A hill that stood up.", "lore": "The Spore Golem was the meadow's first gardener. It sleeps at the Hollow Gate and dreams of the caves below.", "level": 6, "scale": 1.0})

	creature("hollow_crone", "Hollow Crone", "chaos", 58, 4, 8, 10, ["hex_bolt", "cackle", "two_tooth_bite", "brew_sip"], P.TRICKSTER, 60, Vector2i(9, 16),
		[{"item_id": "crone_tooth", "chance": 0.7, "min": 1, "max": 1}, {"item_id": "mana_moss", "chance": 0.4, "min": 1, "max": 2}], "witch",
		{"desc": "A crooked witch with two teeth and too many opinions.", "lore": "The crones of Crookhollow trade in bad dreams. They keep the good ones in jars, and never open them.", "level": 3})
	creature("cackling_crone", "Cackling Crone", "chaos", 50, 3, 10, 13, ["hex_bolt", "cackle", "two_tooth_bite"], P.TRICKSTER, 55, Vector2i(8, 14),
		[{"item_id": "crone_tooth", "chance": 0.6, "min": 1, "max": 2}], "witch",
		{"tint": Color(0.8, 0.95, 0.8), "desc": "Three teeth. She is very proud of the third.", "lore": "Nobody has heard her stop laughing. Nobody has asked her to.", "level": 3})
	creature("gnasher_gremlin", "Gnasher Gremlin", "chaos", 40, 3, 6, 16, ["wrench_whack", "spark_bomb", "giggle"], P.AGGRESSIVE, 40, Vector2i(6, 12),
		[{"item_id": "gremlin_cog", "chance": 0.75, "min": 1, "max": 2}, {"item_id": "dewdrop_tonic", "chance": 0.2, "min": 1, "max": 1}], "gremlin",
		{"desc": "Goggles, propeller, grin. In that order.", "lore": "Gremlins took apart the old castle clock to see where the time went. They are still looking.", "level": 2})


# ------------------------------------------------------------------ encounters
func encounter(id: String, name: String, enemy_ids: Array, opts := {}) -> void:
	var e := EncounterData.new()
	e.id = id
	e.display_name = name
	var list: Array[CreatureData] = []
	for cid: String in enemy_ids:
		list.append(creatures[cid])
	e.enemies = list
	e.can_flee = bool(opts.get("flee", true))
	e.unique = bool(opts.get("unique", false))
	e.music = String(opts.get("music", "music_combat"))
	e.bonus_xp = int(opts.get("xp", 0))
	e.bonus_glimmer = int(opts.get("glimmer", 0))
	e.intro_text = String(opts.get("intro", ""))
	e.ambush = bool(opts.get("ambush", false))
	save(e, "res://resources/encounters/%s.tres" % id)


func build_encounters() -> void:
	encounter("enc_corrupted_sporeling", "The Hollow-Eyed", ["hollow_sporeling"], {"flee": false, "unique": true, "xp": 20, "intro": "Its eyes are empty. It is not curious anymore."})
	encounter("enc_sporeling", "Curious Sporeling", ["sporeling"])
	encounter("enc_sporelings", "Sporeling Gaggle", ["sporeling", "sporeling"])
	encounter("enc_crystal_beetle", "Crystal Beetle", ["crystal_beetle"])
	encounter("enc_beetle_pair", "Glittering Nest", ["crystal_beetle", "sporeling"])
	encounter("enc_dream_fox", "The Dream Fox", ["dream_fox"], {"intro": "The fox grins. It wants to play a game whose rules it is inventing."})
	encounter("enc_bloom_guardian", "The Bloom Guardian", ["bloom_guardian"], {"flee": false, "unique": true, "xp": 40, "intro": "The circle's guardian unfolds, petal by petal, awake and afraid."})
	encounter("enc_crone", "The Hollow Crone", ["hollow_crone"], {"intro": "She grins. Two teeth. Neither of them friendly."})
	encounter("enc_coven", "A Little Coven", ["hollow_crone", "cackling_crone"], {"xp": 25, "intro": "Two crones, one cauldron, and you look like an ingredient."})
	encounter("enc_gremlin", "Gnasher Gremlin", ["gnasher_gremlin"], {"intro": "Something buzzes overhead, giggling."})
	encounter("enc_gremlin_gang", "Gremlin Gang", ["gnasher_gremlin", "gnasher_gremlin"], {"xp": 15, "intro": "Two propellers. Two wrenches. Zero plans."})
	encounter("enc_spore_golem", "Ancient Spore Golem", ["spore_golem"], {"unique": true, "music": "music_boss", "xp": 100, "glimmer": 50, "intro": "The hill stands up."})


# ------------------------------------------------------------------ items
func item(id: String, name: String, cat: int, rarity: int, desc: String, col: String, glyph: String, opts := {}) -> void:
	var i := ItemData.new()
	i.id = id
	i.display_name = name
	i.category = cat
	i.rarity = rarity
	i.description = desc
	i.icon_color = c(col)
	i.icon_glyph = glyph
	i.max_stack = int(opts.get("stack", 99))
	i.value = int(opts.get("value", 1))
	i.equip_slot = String(opts.get("slot", ""))
	i.stat_bonuses = opts.get("stats", {})
	i.use_effect = opts.get("use", {})
	save(i, "res://resources/items/%s.tres" % id)


func build_items() -> void:
	var C := ItemData.Category
	var R := ItemData.Rarity
	item("spore_fragment", "Spore Fragment", C.QUEST, R.RARE, "A seed-shaped shard of the Mycelium's memory. It hums when you hold it near your ear.", "#36fff0", "✺", {"stack": 9})
	item("dream_mote", "Dream Mote", C.COLLECTIBLE, R.UNCOMMON, "A drifting speck of someone's forgotten dream. Madame Petalune collects them.", "#ffe14f", "✦", {"value": 5})
	item("dewdrop_tonic", "Dewdrop Tonic", C.CONSUMABLE, R.COMMON, "Morning dew from a flower that never sleeps. Restores 40 health.", "#ff6f91", "♥", {"use": {"heal": 40}, "value": 8, "stack": 20})
	item("mana_moss", "Mana Moss", C.CONSUMABLE, R.COMMON, "Chew slowly. Restores 4 mana.", "#3fd8ff", "❖", {"use": {"mana": 4}, "value": 6, "stack": 20})
	item("sporeling_cap", "Sporeling Cap", C.INGREDIENT, R.COMMON, "A shed cap. Sporelings grow a new one by morning.", "#c44dff", "◒", {"value": 2})
	item("beetle_shard", "Beetle Shard", C.INGREDIENT, R.UNCOMMON, "A sliver of crystal carapace, still faintly singing.", "#43b8ff", "◆", {"value": 5})
	item("fox_starfur", "Fox Starfur", C.INGREDIENT, R.RARE, "A tuft of fur with tiny stars caught in it.", "#b4a0ff", "✶", {"value": 15})
	item("bloom_petal", "Guardian Petal", C.INGREDIENT, R.UNCOMMON, "Heavy as a shield, soft as a whisper.", "#ff5fae", "✿", {"value": 8})
	item("golem_heartspore", "Golem Heartspore", C.INGREDIENT, R.EPIC, "The beating, glowing heart of an ancient gardener. Still warm.", "#ff8a2a", "❂", {"value": 60, "stack": 5})
	item("crone_tooth", "Crone's Tooth", C.INGREDIENT, R.UNCOMMON, "Long, yellow and crooked. It still bites if you're careless.", "#d8d27a", "⚸", {"value": 9})
	item("gremlin_cog", "Gremlin Cog", C.INGREDIENT, R.COMMON, "A brass cog that ticks backwards.", "#c9a04a", "⚙", {"value": 4})
	item("toadstool_tea", "Toadstool Tea", C.CONSUMABLE, R.UNCOMMON, "Mother Grizzleroot's brew. Tastes like a swamp at midnight. Restores 70 health.", "#7dff5a", "♨", {"use": {"heal": 70}, "value": 18, "stack": 20})
	item("night_ink", "Bottled Night", C.CONSUMABLE, R.UNCOMMON, "A cork, a bottle, and a little piece of sky. Restores 7 mana.", "#6a5cff", "❖", {"use": {"mana": 7}, "value": 16, "stack": 20})
	item("crooked_hat", "Crooked Witch Hat", C.EQUIPMENT, R.RARE, "It leans. It whispers. It is, frankly, fabulous.", "#3a2a6a", "♛", {"slot": "hat", "stats": {"spell_power": 9, "max_mana": 1}, "value": 55, "stack": 1})
	item("scroll_wild_bloom", "Scroll: Wild Bloom", C.SCROLL, R.UNCOMMON, "Reading it aloud makes your palms smell like spring. Teaches Wild Bloom.", "#7dff5a", "✿", {"use": {"unlock_spell": "wild_bloom"}, "value": 30, "stack": 5})
	item("scroll_paradox_gift", "Scroll: Paradox Gift", C.SCROLL, R.RARE, "Written tomorrow. Teaches Paradox Gift.", "#ff5fc8", "∞", {"use": {"unlock_spell": "paradox_gift"}, "value": 45, "stack": 5})
	item("moss_woven_robe", "Moss-Woven Robe", C.EQUIPMENT, R.UNCOMMON, "Soft, warm, and slightly alive.", "#3fd8a0", "♜", {"slot": "robe", "stats": {"max_health": 15, "defense": 2}, "value": 25, "stack": 1})
	item("dreamers_cap", "Dreamer's Cap", C.EQUIPMENT, R.RARE, "A floppy mushroom hat that thinks along with you.", "#e02fb0", "♛", {"slot": "hat", "stats": {"spell_power": 6, "crit_chance": 2}, "value": 40, "stack": 1})
	item("driftwalker_boots", "Driftwalker Boots", C.EQUIPMENT, R.UNCOMMON, "They remember how to float, a little.", "#9b7bff", "♞", {"slot": "boots", "stats": {"defense": 2, "max_mana": 1}, "value": 30, "stack": 1})
	item("keeper_staff", "Keeper's Lantern Staff", C.EQUIPMENT, R.RARE, "A gift from Umbel. The spore inside the lantern is named Pip.", "#ffe14f", "⚚", {"slot": "staff", "stats": {"spell_power": 8, "magic_power": 3}, "value": 50, "stack": 1})
	item("apprentice_wand", "Twig of Beginnings", C.EQUIPMENT, R.COMMON, "A crooked twig that happens to be magic.", "#c48d5a", "⚚", {"slot": "staff", "stats": {"spell_power": 3}, "value": 10, "stack": 1})
	item("lumen_ring", "Lumen Ring", C.EQUIPMENT, R.RARE, "A ring of hardened moonlight from a beetle's nest.", "#4ff3ff", "◯", {"slot": "ring", "stats": {"crit_chance": 4, "magic_power": 2}, "value": 45, "stack": 1})
	item("heartspore_amulet", "Heartspore Amulet", C.EQUIPMENT, R.EPIC, "It beats in time with the meadow.", "#ff8a2a", "❂", {"slot": "artifact", "stats": {"max_health": 30, "spell_power": 6, "max_mana": 1}, "value": 120, "stack": 1})
	item("glowcap_hat", "Glowcap Hat", C.COSMETIC, R.UNCOMMON, "Purely decorative. Purely magnificent.", "#36fff0", "♛", {"slot": "hat", "value": 20, "stack": 1})


# ------------------------------------------------------------------ quests
func objective(id: String, desc: String, type: int, target: String, amount := 1, hint := Vector3.ZERO) -> QuestObjectiveData:
	var o := QuestObjectiveData.new()
	o.id = id
	o.description = desc
	o.type = type
	o.target_id = target
	o.required_amount = amount
	o.map_hint = hint
	o.hint_region = "dreaming_meadow"
	return o


func quest(id: String, title: String, desc: String, cat: int, objs: Array, opts := {}) -> void:
	var q := QuestData.new()
	q.id = id
	q.title = title
	q.description = desc
	q.category = cat
	var list: Array[QuestObjectiveData] = []
	for o: QuestObjectiveData in objs:
		list.append(o)
	q.objectives = list
	q.prerequisites = PackedStringArray(opts.get("pre", []))
	q.auto_start = bool(opts.get("auto", false))
	q.sequential = bool(opts.get("sequential", true))
	q.reward_xp = int(opts.get("xp", 0))
	q.reward_glimmer = int(opts.get("glimmer", 0))
	q.reward_items = opts.get("items", {})
	q.reward_spells = PackedStringArray(opts.get("spells", []))
	q.reward_skill_points = int(opts.get("sp", 0))
	q.completion_text = String(opts.get("done", ""))
	q.min_level = int(opts.get("level", 1))
	save(q, "res://resources/quests/%s.tres" % id)


func build_quests() -> void:
	var T := QuestObjectiveData.Type
	var Q := QuestData.Category
	quest("first_awakening", "The First Awakening",
		"You woke in a meadow you have never seen, which somehow remembers you. Find out where you are — and why the ground is humming.",
		Q.MAIN, [
			objective("wake_up", "Wake up in the Dreaming Meadow", T.VISIT, "awakening_hollow", 1, Vector3(0, 0, 92)),
			objective("find_keeper", "Follow the glowing path to the giant mushroom house", T.VISIT, "keeper_grove", 1, Vector3(12, 0, -42)),
			objective("talk_keeper", "Speak with the Mushroom Keeper", T.TALK, "mushroom_keeper", 1, Vector3(12, 0, -40)),
			objective("collect_fragments", "Collect Spore Fragments (look for the beams of light)", T.COLLECT, "spore_fragment", 3),
			objective("return_keeper", "Return the fragments to the Mushroom Keeper", T.TALK, "mushroom_keeper", 1, Vector3(12, 0, -40)),
			objective("learn_fungal", "Learn Fungal Magic from Umbel", T.ACTIVATE, "learn_fungal_magic", 1, Vector3(12, 0, -40)),
			objective("spot_creature", "Investigate the strange chirping near the house", T.VISIT, "corrupted_sighting", 1, Vector3(-14, 0, -58)),
			objective("defeat_creature", "Defeat the Hollow-Eyed Sporeling", T.DEFEAT, "enc_corrupted_sporeling", 1, Vector3(-14, 0, -58)),
			objective("report_keeper", "Tell Umbel what you saw", T.TALK, "mushroom_keeper", 1, Vector3(12, 0, -40)),
		], {"auto": true, "xp": 80, "glimmer": 25, "items": {"dewdrop_tonic": 2, "moss_woven_robe": 1}, "sp": 1,
			"done": "The Mycelium noticed you. You noticed it back."})
	quest("hum_beneath", "The Hum Beneath",
		"Where the hollow-eyed sporeling fell, the ground split open. Something in the Mycelium is wrong, and it seems to be spreading from below.",
		Q.MAIN, [
			objective("inspect_rift", "Inspect the Mycelial Rift where the sporeling fell", T.ACTIVATE, "mycelial_rift", 1, Vector3(-14, 0, -58)),
			objective("attune_circle", "Attune the Rootstone Circle to the west", T.ACTIVATE, "rootstone_circle", 1, Vector3(-72, 0, -18)),
			objective("defeat_guardian", "Calm the Bloom Guardian", T.DEFEAT, "enc_bloom_guardian", 1, Vector3(-72, 0, -18)),
			objective("tell_keeper", "Return to Umbel", T.TALK, "mushroom_keeper", 1, Vector3(12, 0, -40)),
		], {"pre": ["first_awakening"], "auto": true, "xp": 160, "glimmer": 60, "items": {"keeper_staff": 1}, "spells": ["wild_bloom"], "sp": 1,
			"done": "The circle sings again. Far below, something heard it."})
	quest("sealed_gate", "The Sealed Gate",
		"Umbel says the trouble comes from beyond the meadow's northern gate — and from the caves beneath the Hollow Gate, where the oldest gardener sleeps.",
		Q.MAIN, [
			objective("reach_gate", "Reach the Northern Gate", T.VISIT, "north_gate", 1, Vector3(0, 0, -124)),
			objective("wake_golem", "Face the Ancient Spore Golem at the Hollow Gate", T.DEFEAT, "enc_spore_golem", 1, Vector3(-58, 0, -96)),
		], {"pre": ["hum_beneath"], "auto": true, "xp": 300, "glimmer": 120, "sp": 2,
			"done": "The Golem's heartspore beats in your hand. Beyond the gates, the Whispering Forest waits. (To be continued...)"})
	quest("lights_of_glimmermere", "Lights of Glimmermere",
		"Madame Petalune has lost her collection of Dream Motes to the wind. They drifted all over the meadow — some to places only the curious will find.",
		Q.COLLECTION, [
			objective("collect_motes", "Collect Dream Motes for Madame Petalune", T.COLLECT, "dream_mote", 5),
			objective("return_petalune", "Return to Madame Petalune", T.TALK, "madame_petalune", 1, Vector3(52, 0, 44)),
		], {"xp": 90, "glimmer": 40, "items": {"driftwalker_boots": 1}, "done": "Madame Petalune is radiant. Mostly with smugness."})
	# Class quests — given by each faction's mentor to their own calling.
	quest("class_assassin", "The Unseen Path",
		"Vesper Nightwhisk of the Unseen Covenant wants proof that you move like one of them.",
		Q.CLASS, [
			objective("open_veil", "Shadow Dash through the Shadow Veil in the western woods", T.ACTIVATE, "seal_chest_shadow_nook", 1, Vector3(-90, 0, -42)),
			objective("crones", "Silence two Hollow Crones", T.DEFEAT, "hollow_crone", 2),
			objective("return", "Return to Vesper in Duskhollow", T.TALK, "covenant_mentor", 1, Vector3(-106, 0, 42)),
		], {"xp": 160, "glimmer": 60, "items": {"wanderkey": 1, "ember_arrow": 10}, "done": "Vesper nods once. From the Covenant, that's a parade."})
	quest("class_spirit", "Songs of the Departed",
		"Elder Ondine of the Lantern Choir asks you to listen where the dead still speak.",
		Q.CLASS, [
			objective("echo", "Hear the Echo at the Rootstone Circle", T.ACTIVATE, "seal_chest_circle_echo", 1, Vector3(-64, 0, -8)),
			objective("astral", "Astral Shift through the barrier by the lake shrine", T.ACTIVATE, "seal_chest_astral_shrine", 1, Vector3(84, 0, 36)),
			objective("return", "Return to Elder Ondine in Lanternhome", T.TALK, "choir_mentor", 1, Vector3(96, 0, 48)),
		], {"xp": 160, "glimmer": 60, "items": {"wanderkey": 1, "night_ink": 2}, "done": "The lanterns brighten as you arrive. They were listening too."})
	quest("class_wizard", "The Forgotten Rune",
		"Magister Quillon of the Spiral Concordance has a rune that forgot its name — and gremlins in the workshop.",
		Q.CLASS, [
			objective("rune", "Wake the Sleeping Rune north of the Keeper's grove", T.ACTIVATE, "seal_chest_rune_north", 1, Vector3(22, 0, -104)),
			objective("gremlins", "Chase off three Gnasher Gremlins", T.DEFEAT, "gnasher_gremlin", 3),
			objective("return", "Report to Magister Quillon in Spireholm", T.TALK, "concordance_mentor", 1, Vector3(86, 0, -62)),
		], {"xp": 160, "glimmer": 60, "items": {"wanderkey": 1, "night_ink": 2}, "done": "Quillon writes your name in the ledger. In the margin. In ink."})
	quest("class_grimlet", "Roots Remember",
		"Barkmother Grum of the Rootborn Hold wants the old roots woken. Grm.",
		Q.CLASS, [
			objective("gate", "Wake the Root Gate near Crookhollow", T.ACTIVATE, "seal_chest_root_gate", 1, Vector3(-50, 0, 70)),
			objective("node", "Wake the Mycelium Node south of the lake", T.ACTIVATE, "seal_chest_mycelium", 1, Vector3(40, 0, 72)),
			objective("return", "Return to Barkmother Grum in Gnarlhollow", T.TALK, "hold_mentor", 1, Vector3(-100, 0, 6)),
		], {"xp": 160, "glimmer": 60, "items": {"wanderkey": 1, "toadstool_tea": 2}, "done": "Grum thumps the ground. Somewhere, a root thumps back."})
	quest("beetle_bother", "Beetle Bother",
		"Ollo the snail-merchant's wares keep getting eaten by Crystal Beetles. He would deal with them himself, but he would get there next week.",
		Q.COMBAT, [
			objective("defeat_beetles", "Defeat Crystal Beetles", T.DEFEAT, "crystal_beetle", 3),
			objective("return_ollo", "Return to Ollo", T.TALK, "ollo", 1, Vector3(-8, 0, 30)),
		], {"xp": 100, "glimmer": 50, "items": {"lumen_ring": 1}, "done": "Ollo is so grateful he almost moves."})
	quest("wanderer_of_dreams", "Wanderer of Dreams",
		"The meadow is bigger than it looks, and it looks enormous. Discover its hidden places.",
		Q.DISCOVERY, [
			objective("d_lantern", "Discover the Lantern Cap", T.DISCOVER, "lantern_cap", 1, Vector3(-28, 0, -2)),
			objective("d_lake", "Discover Glimmermere", T.DISCOVER, "glimmermere", 1, Vector3(68, 0, 12)),
			objective("d_circle", "Discover the Rootstone Circle", T.DISCOVER, "rootstone_circle", 1, Vector3(-72, 0, -18)),
			objective("d_hollow", "Discover the Hidden Hollow", T.DISCOVER, "hidden_hollow"),
			objective("d_isle", "Reach the Drift Isle", T.DISCOVER, "drift_isle"),
			objective("d_gate", "Find the Northern Gate", T.DISCOVER, "north_gate", 1, Vector3(0, 0, -124)),
		], {"auto": true, "sequential": false, "xp": 120, "glimmer": 30, "items": {"dreamers_cap": 1}, "done": "You have walked every dream the meadow had."})
