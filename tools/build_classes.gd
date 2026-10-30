extends SceneTree
## MYCELIA class content builder: the four callings, their 20 signature items
## and 20 real-time abilities, plus shared weapons.
## Re-run after editing:  godot --headless --script res://tools/build_classes.gd

const C := ItemData.Category
const R := ItemData.Rarity

var _count := 0


func _init() -> void:
	build_abilities()
	build_items()
	build_classes()
	build_faction_content()
	print("build_classes: wrote %d resources" % _count)
	quit()


func save(res: Resource, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	res.take_over_path(path)
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("Failed to save %s: %s" % [path, error_string(err)])
	_count += 1


# ------------------------------------------------------------------ abilities
func ab(id: String, name: String, cls: String, kind: String, glyph: String, col: String, mana: float, cd: float, power: float, desc: String, opts := {}) -> void:
	var a := AbilityData.new()
	a.id = id
	a.display_name = name
	a.class_id = cls
	a.kind = kind
	a.glyph = glyph
	a.color = Color(col)
	a.mana_cost = mana
	a.cooldown = cd
	a.power = power
	a.description = desc
	a.radius = float(opts.get("radius", 3.0))
	a.ability_range = float(opts.get("range", 8.0))
	a.duration = float(opts.get("duration", 0.0))
	a.world_tag = String(opts.get("world", ""))
	a.unlock_level = int(opts.get("level", 1))
	save(a, "res://resources/abilities/%s.tres" % id)


func build_abilities() -> void:
	# ASSASSIN — shadow, deception, precision.
	ab("shadow_dash", "Shadow Dash", "assassin", "dash", "➶", "#9a7bff", 1, 3.5, 12,
		"Become shadow and streak forward through enemies, cutting each one you pass. Passes through Shadow Veils.", {"range": 8.0, "world": "shadow"})
	ab("backstab", "Backstab", "assassin", "backstab", "⚔", "#ff4f7a", 1, 5, 26,
		"A brutal strike at the nearest foe. Triple damage from behind or against an enemy that hasn't noticed you.", {"range": 3.0})
	ab("smoke_veil", "Smoke Veil", "assassin", "smoke", "☁", "#8a8aa8", 2, 12, 0.6,
		"A cloud of night-smoke. Enemies inside lose track of you and miss 60% of their attacks.", {"radius": 5.0, "duration": 6.0})
	ab("phantom_clone", "Phantom Clone", "assassin", "clone", "◐", "#b49aff", 2, 14, 18,
		"Leave a shadow-double behind. Enemies attack it instead of you; it bursts when it fades.", {"duration": 6.0, "radius": 3.5})
	ab("nightfall", "Nightfall", "assassin", "nightfall", "☾", "#5a3cff", 4, 22, 60,
		"Vanish, reappear behind your target and strike from the dark for massive damage.", {"range": 14.0, "level": 3})
	# SPIRIT — souls, protection, the unseen.
	ab("soul_pulse", "Soul Pulse", "spirit", "soul_pulse", "◎", "#7ef9ff", 2, 6, 14,
		"A ring of soul-light bursts out from you, damaging and hurling back every enemy nearby.", {"radius": 6.0})
	ab("spirit_companion", "Spirit Companion", "spirit", "companion", "✧", "#b8fff2", 2, 18, 6,
		"Call a little ghost-light that circles you and shoots soul darts at your enemies.", {"duration": 20.0, "range": 12.0})
	ab("astral_shift", "Astral Shift", "spirit", "astral", "⇢", "#c9a0ff", 1, 5, 0,
		"Slip half out of the world: blink forward, untouchable, through Astral Barriers.", {"range": 7.0, "duration": 1.2, "world": "astral"})
	ab("soul_shield", "Soul Shield", "spirit", "shield", "◈", "#7ef9ff", 2, 14, 40,
		"Wrap yourself in a shield of remembered courage that absorbs damage.", {"duration": 8.0})
	ab("echo_of_the_ancients", "Echo of the Ancients", "spirit", "echo", "♅", "#ffe9a8", 1, 10, 0,
		"Let the past speak. Reveals hidden enemies, weak points and ghostly echoes of what happened here.", {"radius": 18.0, "duration": 10.0, "world": "echo"})
	# WIZARD — elements, arcana, reality.
	ab("arcane_bolt", "Arcane Bolt", "wizard", "bolt", "✦", "#8ab4ff", 1, 0.9, 16,
		"A fast, homing bolt of pure arcana. Strikes runes to wake them.", {"range": 30.0, "world": "rune"})
	ab("frost_nova", "Frost Nova", "wizard", "nova", "❄", "#bff4ff", 2, 9, 12,
		"Ice explodes outward from you, damaging and slowing every enemy around you.", {"radius": 6.0, "duration": 4.0})
	ab("flame_spiral", "Flame Spiral", "wizard", "spiral", "☀", "#ff8a3a", 3, 12, 8,
		"Three fire-motes spin around you, scorching anything they touch.", {"radius": 2.6, "duration": 6.0})
	ab("gravity_well", "Gravity Well", "wizard", "gravity", "◉", "#b46aff", 3, 15, 5,
		"Open a point of crushing gravity ahead that drags enemies together and grinds them.", {"radius": 7.0, "duration": 4.0, "range": 9.0})
	ab("reality_rift", "Reality Rift", "wizard", "rift", "✶", "#ff5fe0", 5, 24, 70,
		"Tear the world open at your target. After a heartbeat, the rift snaps shut on everything inside.", {"radius": 5.0, "range": 16.0, "level": 3})
	# GRIMLET — roots, spores, growth.
	ab("root_snare", "Root Snare", "grimlet", "snare", "⚘", "#9cff4a", 1, 7, 6,
		"Roots burst up under your target and hold it fast. Wakes sleeping Root Gates.", {"range": 12.0, "duration": 3.0, "world": "root"})
	ab("spore_burst", "Spore Burst", "grimlet", "burst", "✺", "#c44dff", 2, 8, 14,
		"You exhale a storm of spores that damages and infects everything near you.", {"radius": 5.0, "duration": 4.0})
	ab("barkskin", "Barkskin", "grimlet", "barkskin", "⬢", "#8ac24a", 2, 16, 12,
		"Your hide thickens to bark: +12 defense and steady regeneration.", {"duration": 10.0})
	ab("mycelium_link", "Mycelium Link", "grimlet", "link", "⚯", "#36fff0", 1, 10, 4,
		"Plug into the network under your feet. Each hit you land heals you; dormant Mycelium Nodes wake.", {"duration": 8.0, "radius": 10.0, "world": "mycelium"})
	ab("colossus_growth", "Colossus Growth", "grimlet", "colossus", "♜", "#ffb347", 4, 28, 0.6,
		"Grow to a towering colossus: bigger, +60% damage, half damage taken, heavy blows shake the ground.", {"duration": 10.0, "level": 3})


# ------------------------------------------------------------------ items
func it(id: String, name: String, cls: String, slot: String, rarity: int, glyph: String, col: String, desc: String, src: String, opts := {}) -> void:
	var i := ItemData.new()
	i.id = id
	i.display_name = name
	i.class_id = cls
	i.category = C.EQUIPMENT
	i.rarity = rarity
	i.equip_slot = slot
	i.icon_glyph = glyph
	i.icon_color = Color(col)
	i.description = desc
	i.source = src
	i.max_stack = 1
	i.value = int(opts.get("value", 40))
	i.weapon_kind = String(opts.get("kind", ""))
	i.damage = float(opts.get("damage", 0.0))
	i.attack_speed = float(opts.get("speed", 1.5))
	i.reach = float(opts.get("reach", 2.0))
	i.block_power = float(opts.get("block", 0.0))
	i.parry_window = float(opts.get("parry", 0.0))
	i.special = String(opts.get("special", ""))
	i.stat_bonuses = opts.get("stats", {})
	save(i, "res://resources/items/%s.tres" % id)


func build_items() -> void:
	# Assassin.
	it("shadowfang_daggers", "Shadowfang Daggers", "assassin", "staff", R.RARE, "⚔", "#9a7bff",
		"Twin daggers forged from a moonless night. Fast combos; strikes from behind deal double damage.", "Starting gear of the Unseen Covenant.",
		{"kind": "dagger", "damage": 7, "speed": 3.2, "reach": 1.9, "special": "backstab_bonus"})
	it("cloak_of_vanishing", "Cloak of Vanishing", "assassin", "artifact", R.EPIC, "◐", "#5a4a8a",
		"When your health falls below a third, the cloak swallows you: 3 seconds of true invisibility (once every 30s).", "Starting gear of the Unseen Covenant.",
		{"special": "vanish", "stats": {"evasion": 5}})
	it("nightpiercer_bow", "Nightpiercer Bow", "assassin", "ranged", R.RARE, "➹", "#6a5cff",
		"A silent bow. Arrows never alert the target, and fully drawn shots against unaware foes always crit.", "Starting gear of the Unseen Covenant.",
		{"kind": "bow", "damage": 14, "speed": 1.4, "reach": 40.0, "special": "silent"})
	it("venomglass_armor", "Venomglass Armor", "assassin", "robe", R.UNCOMMON, "♜", "#3fbf8a",
		"Light plates of green glass. +12% chance to evade a blow entirely.", "Starting gear of the Unseen Covenant.",
		{"stats": {"defense": 2, "evasion": 12}})
	it("phantomstep_boots", "Phantomstep Boots", "assassin", "boots", R.RARE, "♞", "#b49aff",
		"Your dodge becomes a 40% longer phantom dash that passes through enemies.", "Starting gear of the Unseen Covenant.",
		{"special": "phantom_dash", "stats": {"defense": 1}})
	# Spirit.
	it("soulbound_staff", "Soulbound Staff", "spirit", "staff", R.RARE, "⚚", "#7ef9ff",
		"A staff with a sleeping soul inside. Heavy attacks release a homing soul bolt.", "Starting gear of the Lantern Choir.",
		{"kind": "staff", "damage": 9, "speed": 1.6, "reach": 2.4, "special": "soul_bolt"})
	it("lantern_of_whispers", "Lantern of Whispers", "spirit", "artifact", R.EPIC, "☄", "#ffe9a8",
		"Its light shows what the living can't see: spirit echoes, hidden paths and invisible foes within 12 m.", "Starting gear of the Lantern Choir.",
		{"special": "whispers", "stats": {"max_mana": 1}})
	it("ethereal_shield", "Ethereal Shield", "spirit", "offhand", R.RARE, "⛨", "#a8f0ff",
		"Blocks 65% of physical blows and every magical projectile. Generous parry window.", "Starting gear of the Lantern Choir.",
		{"kind": "shield", "block": 0.65, "parry": 0.28, "special": "ethereal"})
	it("wraith_robes", "Wraith Robes", "spirit", "robe", R.UNCOMMON, "♜", "#6a7aa8",
		"Woven from mist that remembers being cloth. Magic damage taken -25%.", "Starting gear of the Lantern Choir.",
		{"stats": {"defense": 2, "magic_resist": 25}})
	it("spiritcaller_bell", "Spiritcaller Bell", "spirit", "ring", R.RARE, "♫", "#ffd88a",
		"Ring it and the dead remember you. Spirit Companions last 50% longer and come in pairs.", "Starting gear of the Lantern Choir.",
		{"special": "bell"})
	# Wizard.
	it("arcane_staff", "Arcane Staff", "wizard", "staff", R.RARE, "⚚", "#8ab4ff",
		"A spiral of living crystal. Every light attack also flings an arcane spark; heavy attacks fire a full bolt.", "Starting gear of the Spiral Concordance.",
		{"kind": "wand", "damage": 8, "speed": 1.5, "reach": 26.0, "special": "arcane_missile"})
	it("grimoire_of_forgotten_worlds", "Grimoire of Forgotten Worlds", "wizard", "artifact", R.EPIC, "❧", "#c49aff",
		"Half its pages describe places that no longer exist. Ability cooldowns -15%, +10 spell power.", "Starting gear of the Spiral Concordance.",
		{"special": "grimoire", "stats": {"spell_power": 10}})
	it("crystal_orb", "Crystal Orb", "wizard", "offhand", R.RARE, "◯", "#bff4ff",
		"Hums near hidden things. Treasure, runes and secret doors within 15 m shimmer through walls.", "Starting gear of the Spiral Concordance.",
		{"special": "orb_sight", "stats": {"magic_power": 2}})
	it("runebound_robes", "Runebound Robes", "wizard", "robe", R.UNCOMMON, "♜", "#3a4cff",
		"Runes crawl across the cloth. +2 max mana and 50% faster mana regeneration.", "Starting gear of the Spiral Concordance.",
		{"stats": {"defense": 1, "max_mana": 2, "mana_regen": 0.5}})
	it("astral_crown", "Astral Crown", "wizard", "hat", R.LEGENDARY, "♛", "#ffe36a",
		"A circlet of captured starlight. Every fourth ability you cast is free and twice as strong — the crown flares when it's ready.", "Starting gear of the Spiral Concordance (an heirloom).",
		{"special": "astral_echo", "stats": {"spell_power": 4}})
	# Grimlet.
	it("rootbreaker_axe", "Rootbreaker Axe", "grimlet", "staff", R.RARE, "⚒", "#9cff4a",
		"A heavy axe of petrified root. Every swing cleaves through all enemies in front of you.", "Starting gear of the Rootborn Hold.",
		{"kind": "axe", "damage": 15, "speed": 1.1, "reach": 2.4, "special": "cleave"})
	it("sporeguard_shield", "Sporeguard Shield", "grimlet", "offhand", R.RARE, "⛨", "#c44dff",
		"A living shield. Blocks 80% of blows, and every blocked hit puffs spores into the attacker's face.", "Starting gear of the Rootborn Hold.",
		{"kind": "shield", "block": 0.8, "parry": 0.2, "special": "spore_guard"})
	it("mycelium_hammer", "Mycelium Hammer", "grimlet", "staff", R.RARE, "⚒", "#36fff0",
		"Slow and enormous. Heavy attacks slam a shockwave through the ground. (Switch weapons to wield it.)", "Starting gear of the Rootborn Hold.",
		{"kind": "hammer", "damage": 22, "speed": 0.75, "reach": 2.5, "special": "shockwave"})
	it("thornhide_armor", "Thornhide Armor", "grimlet", "robe", R.UNCOMMON, "♜", "#5a7a3a",
		"Bark and thorn grown, not made. +8 defense; melee attackers take 15% of their damage back.", "Starting gear of the Rootborn Hold.",
		{"special": "thorns", "stats": {"defense": 8}})
	it("eldercap_helm", "Eldercap Helm", "grimlet", "hat", R.EPIC, "♛", "#ffb347",
		"An elder grimlet's cap, given back. Nature abilities +25%, and you slowly regrow health.", "Starting gear of the Rootborn Hold.",
		{"special": "elder", "stats": {"max_health": 20, "health_regen": 0.8}})
	# Shared weapons found in the world.
	it("dreamsteel_sword", "Dreamsteel Sword", "", "staff", R.UNCOMMON, "†", "#c9d4ff",
		"A plain, honest sword. In a dream, that's rare.", "Treasure chests in the Dreaming Meadow.",
		{"kind": "sword", "damage": 11, "speed": 1.8, "reach": 2.2})
	it("moonsplitter", "Moonsplitter", "", "staff", R.LEGENDARY, "†", "#ffe9a8",
		"A greatsword that remembers the night the moon fell. Heavy attacks throw a crescent of moonlight that cuts everything in its path.", "The Sunken Hollow's deepest vault.",
		{"kind": "greatsword", "damage": 24, "speed": 0.9, "reach": 2.8, "special": "moon_arc"})
	it("gnarlwood_shield", "Gnarlwood Shield", "", "offhand", R.COMMON, "⛨", "#8a6a4a",
		"Knotted wood. It has stopped worse than you.", "Ollo's shop.",
		{"kind": "shield", "block": 0.5, "parry": 0.18})
	for ar: Array in [["ember_arrow", "Ember Arrow", "#ff7a3a", "Sets what it hits on fire for a few seconds."],
			["frost_arrow", "Frost Arrow", "#9ff0ff", "Slows what it hits to a dreamy crawl."],
			["spore_arrow", "Spore Arrow", "#c44dff", "Bursts into clinging spores that eat away at the target."]]:
		var a := ItemData.new()
		a.id = ar[0]
		a.display_name = ar[1]
		a.category = C.INGREDIENT
		a.rarity = R.UNCOMMON
		a.icon_glyph = "➶"
		a.icon_color = Color(String(ar[2]))
		a.description = String(ar[3]) + " Draw your bow and press Switch to choose arrows."
		a.source = "Treasure chests, Ollo and Mother Grizzleroot."
		a.max_stack = 60
		a.value = 3
		save(a, "res://resources/items/%s.tres" % a.id)
	var wk := ItemData.new()
	wk.id = "wanderkey"
	wk.display_name = "Wanderkey"
	wk.category = C.QUEST
	wk.rarity = R.EPIC
	wk.icon_glyph = "⚿"
	wk.icon_color = Color("#ffe36a")
	wk.description = "A key with no teeth that fits every Class Seal once. For Dreamers who want to see what the other callings hide."
	wk.source = "Ollo sells them, slowly. Sometimes found in chests."
	wk.max_stack = 9
	wk.value = 60
	save(wk, "res://resources/items/wanderkey.tres")
	it("twig_bow", "Twig Bow", "", "ranged", R.COMMON, "➹", "#c48d5a",
		"A bent branch with ideas.", "Starting gear of every Dreamer.",
		{"kind": "bow", "damage": 9, "speed": 1.0, "reach": 30.0})


# ------------------------------------------------------------------ classes
func cls(id: String, name: String, glyph: String, col: String, faction: String, tagline: String, lore: String, trial: String, stats: Dictionary, feel: Dictionary, items: Array, abilities: Array, paths: Array, rig: String, rig_opts := {}) -> void:
	var k := ClassData.new()
	k.id = id
	k.display_name = name
	k.glyph = glyph
	k.color = Color(col)
	k.faction_id = faction
	k.tagline = tagline
	k.lore = lore
	k.trial = trial
	k.stat_mods = stats
	k.feel = feel
	k.start_items = PackedStringArray(items)
	k.abilities = PackedStringArray(abilities)
	k.learning_paths = PackedStringArray(paths)
	k.rig_kind = rig
	k.rig_opts = rig_opts
	save(k, "res://resources/classes/%s.tres" % id)


func build_classes() -> void:
	cls("assassin", "Assassin", "☾", "#9a7bff", "unseen_covenant",
		"Swift. Silent. Already behind you.",
		"When Ysmera, the Dreaming Root, first closed her eyes, the darkness between her thoughts woke up hungry. The Unseen Covenant are its children: they live in hidden hollows and under the roots, they move between heartbeats, and they guard the Key of Shadows.",
		"The Stone of Shadows asks you to cross a room full of watching eyes without being seen.",
		{"max_health": -10, "crit_chance": 10, "evasion": 5}, {"move": 1.12, "dodge": 1.35, "stamina": 110},
		["shadowfang_daggers", "cloak_of_vanishing", "nightpiercer_bow", "venomglass_armor", "phantomstep_boots"],
		["shadow_dash", "backstab", "smoke_veil", "phantom_clone", "nightfall"],
		["shadow_arts", "precision", "mobility", "deception", "lethality"], "assassin")
	cls("spirit", "Spirit", "♅", "#7ef9ff", "lantern_choir",
		"The dead remember. So do you.",
		"Everything Ysmera ever dreamed is still somewhere, as an echo. The Lantern Choir hear those echoes. They live in floating villages and old forest shrines, speak with the departed and keep the Key of Souls.",
		"The Stone of Souls asks you to find a voice that only the dead can hear.",
		{"max_mana": 2, "magic_resist": 15}, {"move": 1.0, "dodge": 1.0, "stamina": 100},
		["soulbound_staff", "lantern_of_whispers", "ethereal_shield", "wraith_robes", "spiritcaller_bell"],
		["soul_pulse", "spirit_companion", "astral_shift", "soul_shield", "echo_of_the_ancients"],
		["soul_magic", "protection", "summoning", "astral_travel", "ancient_knowledge"], "spirit")
	cls("wizard", "Wizard", "✶", "#8ab4ff", "spiral_concordance",
		"Reality is a suggestion.",
		"Ysmera's dream has rules — gravity, fire, frost, the order of moments. The Spiral Concordance study those rules until they can bend them. Their towers and libraries float above the clouds, and they keep the Key of Laws.",
		"The Stone of Laws asks you to wake a rune that has forgotten its own name.",
		{"max_mana": 3, "spell_power": 8, "max_health": -15}, {"move": 1.0, "dodge": 1.0, "stamina": 90},
		["arcane_staff", "grimoire_of_forgotten_worlds", "crystal_orb", "runebound_robes", "astral_crown"],
		["arcane_bolt", "frost_nova", "flame_spiral", "gravity_well", "reality_rift"],
		["elemental_magic", "arcane_power", "spell_control", "reality_manipulation", "mana_mastery"], "dreamer",
		{"robe_color": Color("#1d2a66"), "hat_color": Color("#3a1a7a")})
	cls("grimlet", "Grimlet", "⚘", "#9cff4a", "rootborn_hold",
		"Grm. We are the forest's fist.",
		"Grimlets grow, they are not born: when an elder cap falls, a grimlet sprouts from it, carrying a little of the elder's memory. They live in hollow mushroom-cities and root-halls deep under the meadow, speak as 'we', and guard the Key of Growth. When a grimlet dies, it 'goes to loam' — and something new grows there.",
		"The Stone of Growth asks you to wake a gate of roots that has slept for a thousand years.",
		{"max_health": 40, "defense": 6, "max_mana": -1, "health_regen": 0.6}, {"move": 0.92, "dodge": 0.85, "stamina": 130},
		["rootbreaker_axe", "sporeguard_shield", "mycelium_hammer", "thornhide_armor", "eldercap_helm"],
		["root_snare", "spore_burst", "barkskin", "mycelium_link", "colossus_growth"],
		["nature_magic", "heavy_combat", "regeneration", "spore_arts", "ancient_growth"], "grimlet")


# ------------------------------------------------------------------ factions
func build_faction_content() -> void:
	var F := [
		["unseen_covenant", "assassin", "Covenant", "#9a7bff", "covenant_veil", "Covenant Veil", "duskglass_signet", "Duskglass Signet", {"crit_chance": 6, "evasion": 4}],
		["lantern_choir", "spirit", "Choir", "#7ef9ff", "choir_shroud", "Choir Shroud", "lantern_signet", "Lantern Signet", {"max_mana": 1, "magic_resist": 10}],
		["spiral_concordance", "wizard", "Concordance", "#8ab4ff", "concordance_mantle", "Concordance Mantle", "spiral_signet", "Spiral Signet", {"spell_power": 8, "mana_regen": 0.2}],
		["rootborn_hold", "grimlet", "Hold", "#9cff4a", "rootmoss_cloak", "Rootmoss Cloak", "loam_signet", "Loam Signet", {"max_health": 25, "health_regen": 0.5}],
	]
	for f: Array in F:
		var v := ItemData.new()
		v.id = f[4]
		v.display_name = f[5]
		v.category = C.CONSUMABLE
		v.rarity = R.RARE
		v.icon_glyph = "☖"
		v.icon_color = Color(String(f[3]))
		v.description = "Wear it and the %s's guards take you for one of their own — mostly. Lasts 8 minutes. Use it from the satchel." % String(f[2])
		v.use_effect = {"disguise": f[0], "minutes": 8.0}
		v.source = "Ollo's crossing (neutral ground)."
		v.max_stack = 5
		v.value = 30
		save(v, "res://resources/items/%s.tres" % v.id)
		it(f[6], f[7], f[1], "ring", R.EPIC, "◯", f[3],
			"A signet only the %s gives to those it trusts. (Needs a friendly standing to buy.)" % String(f[2]), "%s weapon master, friendly standing." % String(f[2]),
			{"stats": f[8], "value": 90})
	# Faction guards fight in real time (enemy_profiles.json).
	var nib: SpellData = load("res://resources/creatures/abilities/nibble.tres")
	var G := [
		["covenant_guard", "Covenant Blade", "assassin", 70, 4],
		["choir_warden", "Choir Warden", "spirit", 80, 6],
		["concordance_sentinel", "Concordance Sentinel", "dreamer", 70, 5],
		["hold_guardian", "Hold Guardian", "grimlet", 110, 9],
	]
	for g: Array in G:
		var cr := CreatureData.new()
		cr.id = g[0]
		cr.display_name = g[1]
		cr.element = "chaos"
		cr.max_health = g[3]
		cr.defense = g[4]
		cr.power = 8
		cr.speed = 12
		var ab: Array[SpellData] = [nib]
		cr.abilities = ab
		cr.personality = CreatureData.Personality.TACTICAL
		cr.xp_reward = 30
		cr.glimmer_min = 0
		cr.glimmer_max = 4
		cr.visual_kind = g[2]
		cr.level = 4
		cr.world_behavior = "hostile"
		cr.description = "A guard defending their village."
		save(cr, "res://resources/creatures/%s.tres" % cr.id)
