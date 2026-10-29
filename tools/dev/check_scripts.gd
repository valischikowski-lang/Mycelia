extends Node
## Dev tool: loads every script under res://scripts and res://tools so parse
## and compile errors surface in one headless run.
##   godot --headless res://tools/dev/check_scripts.tscn

func _ready() -> void:
	var failures := 0
	var count := 0
	for dir: String in ["res://scripts", "res://tests", "res://tools/dev"]:
		for path: String in _collect(dir):
			count += 1
			var s: Script = load(path)
			if s == null or not s.can_instantiate():
				failures += 1
				print("FAIL ", path)
	print("check_scripts: %d scripts, %d failed to load" % [count, failures])
	get_tree().quit(1 if failures > 0 else 0)


func _collect(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	var d := DirAccess.open(dir)
	if d == null:
		return out
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		var p := dir.path_join(f)
		if d.current_is_dir():
			out.append_array(_collect(p))
		elif f.ends_with(".gd"):
			out.append(p)
		f = d.get_next()
	return out
