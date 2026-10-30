class_name SaveSchema
extends RefCounted
## Versioned save format: validation, defaults for missing fields and
## step-by-step migration from older versions.
##
## v1: early prototype; currency lived at profile.currency, no world block.
## v2: currency moved into inventory.glimmer; world state block added.
## v3: (current) adds "yaw" and "slot_label"; quests.tracked.

const CURRENT_VERSION := 3


static func defaults() -> Dictionary:
	return {
		"version": CURRENT_VERSION,
		"saved_at": 0,
		"slot_label": "",
		"region": "dreaming_meadow",
		"position": null,
		"yaw": 0.0,
		"profile": {},
	}


## Returns a migrated, sanitized copy or {} if the data is unusable.
static func upgrade(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return {}
	var d: Dictionary = (raw as Dictionary).duplicate(true)
	if not d.get("profile", {}) is Dictionary:
		return {}
	var v := int(d.get("version", 1))
	if v > CURRENT_VERSION:
		push_warning("SaveSchema: save from a newer version (%d); loading best-effort." % v)
	while v < CURRENT_VERSION:
		match v:
			1:
				d = _migrate_1_to_2(d)
			2:
				d = _migrate_2_to_3(d)
		v += 1
	d["version"] = CURRENT_VERSION
	return sanitize(d)


static func _migrate_1_to_2(d: Dictionary) -> Dictionary:
	var p: Dictionary = d.get("profile", {})
	var inv: Dictionary = p.get("inventory", {})
	if p.has("currency"):
		inv["glimmer"] = int(p["currency"])
		p.erase("currency")
	p["inventory"] = inv
	if not p.has("world"):
		p["world"] = {}
	d["profile"] = p
	return d


static func _migrate_2_to_3(d: Dictionary) -> Dictionary:
	if not d.has("yaw"):
		d["yaw"] = 0.0
	if not d.has("slot_label"):
		d["slot_label"] = ""
	var p: Dictionary = d.get("profile", {})
	var q: Dictionary = p.get("quests", {})
	if not q.has("tracked"):
		q["tracked"] = ""
	p["quests"] = q
	d["profile"] = p
	return d


static func sanitize(d: Dictionary) -> Dictionary:
	var out := defaults()
	for k: String in out.keys():
		if d.has(k):
			out[k] = d[k]
	if not out["profile"] is Dictionary:
		return {}
	var pos: Variant = out["position"]
	if pos != null:
		if not (pos is Array and (pos as Array).size() == 3):
			out["position"] = null
		else:
			for c: Variant in pos:
				if not (c is float or c is int) or is_nan(float(c)):
					out["position"] = null
					break
	out["region"] = String(out["region"])
	out["yaw"] = float(out["yaw"]) if (out["yaw"] is float or out["yaw"] is int) else 0.0
	out["saved_at"] = int(out["saved_at"]) if (out["saved_at"] is float or out["saved_at"] is int) else 0
	var prof: Dictionary = out["profile"]
	for block: String in ["stats", "inventory", "spellbook", "skills", "quests", "world"]:
		if not prof.get(block, {}) is Dictionary:
			prof[block] = {}
	return out
