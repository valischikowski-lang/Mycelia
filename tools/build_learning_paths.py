#!/usr/bin/env python3
"""Writes resources/skills/class_<id>.json: five Learning Paths per calling,
four tiers each, bought with Mana Essence.  Node effects:
  bonuses        stat bonuses (PlayerStats keys)
  ability_mods   {ability_id: {power, cooldown, mana, radius, duration}} (fractions, mana absolute)
  unlock_ability makes an ability usable before its level
  perk           a named passive handled in code (world or combat)
Re-run after editing:  python3 tools/build_learning_paths.py
"""
import json, os

COST = {1: 2, 2: 3, 3: 5, 4: 7}
LEVEL = {1: 1, 2: 2, 3: 3, 4: 5}

def node(path, tier, nid, name, desc, **fx):
    n = {"id": nid, "branch": path, "tier": tier, "name": name, "description": desc,
         "cost": COST[tier], "min_level": LEVEL[tier], "requires": [], "bonuses": fx.pop("bonuses", {})}
    n.update(fx)
    return n

def chain(nodes):
    for i in range(1, len(nodes)):
        nodes[i]["requires"] = [nodes[i - 1]["id"]]
    return nodes

CLASSES = {
 "assassin": ("#9a7bff", "The Ways of the Unseen", "Shadow, precision and deceit — learned in the dark under the roots.", [
  ("shadow_arts", "Shadow Arts", [
    ("deep_shadow", "Deeper Shadows", "Shadow Dash reaches 30% further and hits 25% harder.", {"ability_mods": {"shadow_dash": {"power": 0.25, "range": 0.3}}}),
    ("shade_step", "Shade Step", "Shadow Dash cooldown -30%.", {"ability_mods": {"shadow_dash": {"cooldown": -0.3}}}),
    ("early_nightfall", "Early Dusk", "Learn Nightfall now, whatever your level.", {"unlock_ability": "nightfall"}),
    ("long_night", "The Long Night", "Nightfall deals 40% more damage and costs 1 less mana.", {"ability_mods": {"nightfall": {"power": 0.4, "mana": -1}}}),
  ]),
  ("precision", "Precision", [
    ("keen_eye", "Keen Eye", "+5% critical chance.", {"bonuses": {"crit_chance": 5}}),
    ("steady_draw", "Steady Draw", "Bow damage +20%.", {"bonuses": {"bow_power": 0.2}}),
    ("vital_points", "Vital Points", "Backstab deals 30% more damage.", {"ability_mods": {"backstab": {"power": 0.3}}}),
    ("perfect_cut", "Perfect Cut", "+10% critical chance, melee damage +10%.", {"bonuses": {"crit_chance": 10, "melee_power": 0.1}}),
  ]),
  ("mobility", "Mobility", [
    ("light_feet", "Light Feet", "+8% movement speed.", {"bonuses": {"move_speed": 0.08}}),
    ("second_wind", "Second Wind", "+25 stamina.", {"bonuses": {"max_stamina": 25}}),
    ("wall_whisper", "Rooftop Runner", "Jump 20% higher — rooftops and caps are yours.", {"perk": "high_jump"}),
    ("ghost_dodge", "Ghost Dodge", "+10% evasion.", {"bonuses": {"evasion": 10}}),
  ]),
  ("deception", "Deception", [
    ("thick_smoke", "Thick Smoke", "Smoke Veil lasts 50% longer and is 30% wider.", {"ability_mods": {"smoke_veil": {"duration": 0.5, "radius": 0.3}}}),
    ("second_self", "Second Self", "Phantom Clone bursts for 60% more damage.", {"ability_mods": {"phantom_clone": {"power": 0.6}}}),
    ("quiet_steps", "Quiet Steps", "Hostile creatures notice you from 40% closer.", {"perk": "quiet_steps"}),
    ("mirror_mask", "Mirror Mask", "Phantom Clone cooldown -35%.", {"ability_mods": {"phantom_clone": {"cooldown": -0.35}}}),
  ]),
  ("lethality", "Lethality", [
    ("sharp_edges", "Sharp Edges", "Melee damage +10%.", {"bonuses": {"melee_power": 0.1}}),
    ("venom_coat", "Venom Coat", "+4 spell power, +3 crit chance.", {"bonuses": {"spell_power": 4, "crit_chance": 3}}),
    ("executioner", "Executioner", "Backstab cooldown -30%, costs no mana.", {"ability_mods": {"backstab": {"cooldown": -0.3, "mana": -1}}}),
    ("shadowmaster", "Shadowmaster", "Melee damage +20%, +20 health.", {"bonuses": {"melee_power": 0.2, "max_health": 20}}),
  ]),
 ]),
 "spirit": ("#7ef9ff", "The Choir's Teachings", "Lessons sung by the dead to those who still have voices.", [
  ("soul_magic", "Soul Magic", [
    ("bright_soul", "Bright Soul", "Soul Pulse +25% damage and range.", {"ability_mods": {"soul_pulse": {"power": 0.25, "radius": 0.25}}}),
    ("soul_well", "Soul Well", "+2 maximum mana.", {"bonuses": {"max_mana": 2}}),
    ("echo_pulse", "Echoing Pulse", "Soul Pulse cooldown -30%.", {"ability_mods": {"soul_pulse": {"cooldown": -0.3}}}),
    ("choir_voice", "Voice of the Choir", "+12 spell power.", {"bonuses": {"spell_power": 12}}),
  ]),
  ("protection", "Protection", [
    ("ward_skin", "Ward Skin", "+15% magic resistance.", {"bonuses": {"magic_resist": 15}}),
    ("stronger_shield", "Remembered Courage", "Soul Shield absorbs 50% more.", {"ability_mods": {"soul_shield": {"power": 0.5}}}),
    ("guardian", "Guardian", "+5 defense, +20 health.", {"bonuses": {"defense": 5, "max_health": 20}}),
    ("undying", "Undying Hymn", "Soul Shield lasts twice as long.", {"ability_mods": {"soul_shield": {"duration": 1.0}}}),
  ]),
  ("summoning", "Summoning", [
    ("kind_ghost", "Kind Ghosts", "Spirit Companions hit 30% harder.", {"ability_mods": {"spirit_companion": {"power": 0.3}}}),
    ("long_vigil", "Long Vigil", "Spirit Companions stay 50% longer.", {"ability_mods": {"spirit_companion": {"duration": 0.5}}}),
    ("beast_calm", "Beast Whisperer", "Wild creatures are calmer around you: they notice you from 40% closer.", {"perk": "quiet_steps"}),
    ("host", "The Host", "Spirit Companion cooldown -40%.", {"ability_mods": {"spirit_companion": {"cooldown": -0.4}}}),
  ]),
  ("astral_travel", "Astral Travel", [
    ("far_shift", "Far Shift", "Astral Shift travels 40% further.", {"ability_mods": {"astral_shift": {"range": 0.4}}}),
    ("light_soul", "Light Soul", "+8% movement speed, +20 stamina.", {"bonuses": {"move_speed": 0.08, "max_stamina": 20}}),
    ("featherfall", "Featherfall", "Jump 20% higher and land softly.", {"perk": "high_jump"}),
    ("free_shift", "Unbound", "Astral Shift costs no mana.", {"ability_mods": {"astral_shift": {"mana": -1}}}),
  ]),
  ("ancient_knowledge", "Ancient Knowledge", [
    ("long_memory", "Long Memory", "Echo of the Ancients reveals 50% further.", {"ability_mods": {"echo_of_the_ancients": {"radius": 0.5}}}),
    ("treasure_sense", "Treasure Sense", "Chests within 40 m glow through walls.", {"perk": "treasure_sense"}),
    ("old_tongues", "Old Tongues", "+10% mana regeneration, +4 spell power.", {"bonuses": {"mana_regen": 0.1, "spell_power": 4}}),
    ("seer", "Seer", "Echo of the Ancients exposes enemies for its whole duration.", {"ability_mods": {"echo_of_the_ancients": {"power": 1.0}}}),
  ]),
 ]),
 "wizard": ("#8ab4ff", "The Spiral Curriculum", "Seven floors of library, five of them reachable by stairs.", [
  ("elemental_magic", "Elemental Magic", [
    ("cold_hands", "Cold Hands", "Frost Nova +30% damage, slows 50% longer.", {"ability_mods": {"frost_nova": {"power": 0.3, "duration": 0.5}}}),
    ("hotter_flames", "Hotter Flames", "Flame Spiral +35% damage.", {"ability_mods": {"flame_spiral": {"power": 0.35}}}),
    ("wide_frost", "Winter's Reach", "Frost Nova radius +30%.", {"ability_mods": {"frost_nova": {"radius": 0.3}}}),
    ("firestorm", "Firestorm", "Flame Spiral lasts 60% longer and is 30% wider.", {"ability_mods": {"flame_spiral": {"duration": 0.6, "radius": 0.3}}}),
  ]),
  ("arcane_power", "Arcane Power", [
    ("focused_bolt", "Focused Bolt", "Arcane Bolt +25% damage.", {"ability_mods": {"arcane_bolt": {"power": 0.25}}}),
    ("arcane_mind", "Arcane Mind", "+10 spell power.", {"bonuses": {"spell_power": 10}}),
    ("early_rift", "Early Rift", "Learn Reality Rift now, whatever your level.", {"unlock_ability": "reality_rift"}),
    ("archmage", "Archmage", "+15 spell power, +5% crit.", {"bonuses": {"spell_power": 15, "crit_chance": 5}}),
  ]),
  ("spell_control", "Spell Control", [
    ("heavy_well", "Heavy Well", "Gravity Well lasts 50% longer.", {"ability_mods": {"gravity_well": {"duration": 0.5}}}),
    ("quick_hands", "Quick Hands", "Frost Nova and Gravity Well cooldowns -25%.", {"ability_mods": {"frost_nova": {"cooldown": -0.25}, "gravity_well": {"cooldown": -0.25}}}),
    ("binding_circle", "Binding Circle", "Gravity Well radius +30%, +40% damage.", {"ability_mods": {"gravity_well": {"radius": 0.3, "power": 0.4}}}),
    ("composure", "Composure", "+5 defense, +15% magic resistance.", {"bonuses": {"defense": 5, "magic_resist": 15}}),
  ]),
  ("reality_manipulation", "Reality Manipulation", [
    ("rune_reader", "Rune Reader", "Arcane Bolt cooldown -30%.", {"ability_mods": {"arcane_bolt": {"cooldown": -0.3}}}),
    ("wider_rift", "Wider Rift", "Reality Rift radius +30%.", {"ability_mods": {"reality_rift": {"radius": 0.3}}}),
    ("treasure_sense_w", "Divination", "Chests within 40 m glow through walls.", {"perk": "treasure_sense"}),
    ("unmake", "Unmake", "Reality Rift +50% damage.", {"ability_mods": {"reality_rift": {"power": 0.5}}}),
  ]),
  ("mana_mastery", "Mana Mastery", [
    ("deep_well", "Deep Well", "+2 maximum mana.", {"bonuses": {"max_mana": 2}}),
    ("flow", "Flow", "+30% mana regeneration.", {"bonuses": {"mana_regen": 0.3}}),
    ("thrift", "Thrift", "Flame Spiral and Reality Rift cost 1 less mana.", {"ability_mods": {"flame_spiral": {"mana": -1}, "reality_rift": {"mana": -1}}}),
    ("overflow", "Overflow", "+3 maximum mana, +30% mana regeneration.", {"bonuses": {"max_mana": 3, "mana_regen": 0.3}}),
  ]),
 ]),
 "grimlet": ("#9cff4a", "The Rootborn Ways", "Grm. We teach what the soil taught us.", [
  ("nature_magic", "Nature Magic", [
    ("thick_roots", "Thick Roots", "Root Snare holds 50% longer.", {"ability_mods": {"root_snare": {"duration": 0.5}}}),
    ("green_mind", "Green Mind", "+8 spell power.", {"bonuses": {"spell_power": 8}}),
    ("quick_roots", "Quick Roots", "Root Snare cooldown -35%.", {"ability_mods": {"root_snare": {"cooldown": -0.35}}}),
    ("forest_wrath", "Forest Wrath", "Root Snare deals triple damage.", {"ability_mods": {"root_snare": {"power": 2.0}}}),
  ]),
  ("heavy_combat", "Heavy Combat", [
    ("heavy_hands", "Heavy Hands", "Melee damage +12%.", {"bonuses": {"melee_power": 0.12}}),
    ("iron_lungs", "Iron Lungs", "+30 stamina.", {"bonuses": {"max_stamina": 30}}),
    ("bulwark", "Bulwark", "+6 defense.", {"bonuses": {"defense": 6}}),
    ("earthshaker", "Earthshaker", "Melee damage +20%, +30 health.", {"bonuses": {"melee_power": 0.2, "max_health": 30}}),
  ]),
  ("regeneration", "Regeneration", [
    ("green_blood", "Green Blood", "+0.8 health regeneration per second.", {"bonuses": {"health_regen": 0.8}}),
    ("thick_bark", "Thick Bark", "Barkskin lasts 50% longer.", {"ability_mods": {"barkskin": {"duration": 0.5}}}),
    ("deep_link", "Deep Link", "Mycelium Link lasts 50% longer.", {"ability_mods": {"mycelium_link": {"duration": 0.5}}}),
    ("evergreen", "Evergreen", "+1.5 health regeneration per second, +40 health.", {"bonuses": {"health_regen": 1.5, "max_health": 40}}),
  ]),
  ("spore_arts", "Spore Arts", [
    ("thick_spores", "Thick Spores", "Spore Burst +30% damage.", {"ability_mods": {"spore_burst": {"power": 0.3}}}),
    ("cloud_burst", "Cloud Burst", "Spore Burst radius +30%.", {"ability_mods": {"spore_burst": {"radius": 0.3}}}),
    ("spore_sense", "Spore Sense", "Chests within 40 m glow through walls.", {"perk": "treasure_sense"}),
    ("rot_bloom", "Rot Bloom", "Spore Burst cooldown -35%, spores last twice as long.", {"ability_mods": {"spore_burst": {"cooldown": -0.35, "duration": 1.0}}}),
  ]),
  ("ancient_growth", "Ancient Growth", [
    ("elder_memory", "Elder Memory", "+25 health.", {"bonuses": {"max_health": 25}}),
    ("early_colossus", "Early Growth", "Learn Colossus Growth now, whatever your level.", {"unlock_ability": "colossus_growth"}),
    ("longer_growth", "Long Growth", "Colossus Growth lasts 50% longer.", {"ability_mods": {"colossus_growth": {"duration": 0.5}}}),
    ("world_tree", "World Tree", "Colossus Growth cooldown -35%, +6 defense.", {"ability_mods": {"colossus_growth": {"cooldown": -0.35}}, "bonuses": {"defense": 6}}),
  ]),
 ]),
}

out_dir = os.path.join(os.path.dirname(__file__), "..", "resources", "skills")
for cls, (color, name, desc, paths) in CLASSES.items():
    nodes = []
    branches = []
    for pid, pname, tiers in paths:
        branches.append({"id": pid, "name": pname})
        chain_nodes = []
        for i, (nid, nname, ndesc, fx) in enumerate(tiers):
            chain_nodes.append(node(pid, i + 1, nid, nname, ndesc, **dict(fx)))
        nodes += chain(chain_nodes)
    tree = {"id": "class_" + cls, "name": name, "description": desc, "color": color,
            "class": cls, "currency": "mana_essence", "branches": branches, "nodes": nodes}
    with open(os.path.join(out_dir, "class_%s.json" % cls), "w") as f:
        json.dump(tree, f, indent="\t", ensure_ascii=False)
print("wrote", len(CLASSES), "learning-path files")
