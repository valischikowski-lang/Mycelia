extends Node
## Runs every tests/test_*.gd TestCase and prints a report.
##   godot --headless --fixed-fps 60 res://tests/test_runner.tscn
## Optional filter: -- <substring>   (only test files/methods containing it)
## Exit code = number of failed tests (0 = all green).

func _ready() -> void:
	var filter := ""
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		filter = args[0]
	var files := PackedStringArray()
	var dir := DirAccess.open("res://tests")
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if f.begins_with("test_") and f.ends_with(".gd") and f != "test_runner.gd" and f != "test_case.gd":
			files.append(f)
		f = dir.get_next()
	files.sort()
	var total := 0
	var failed := 0
	var checks := 0
	var t0 := Time.get_ticks_msec()
	for file: String in files:
		var script: GDScript = load("res://tests/" + file)
		if script == null or not script.can_instantiate():
			print("✗ %s failed to load" % file)
			failed += 1
			continue
		for m: Dictionary in script.get_script_method_list():
			var name := String(m["name"])
			if not name.begins_with("test_"):
				continue
			if filter != "" and not (filter in file or filter in name):
				continue
			var tc: TestCase = script.new()
			tc.tree = get_tree()
			tc.host = self
			total += 1
			tc.before_each()
			await tc.call(name)
			tc.after_each()
			checks += tc.checks
			if tc.failures.is_empty():
				print("  ✓ %s :: %s" % [file.get_basename(), name])
			else:
				failed += 1
				print("  ✗ %s :: %s" % [file.get_basename(), name])
				for msg: String in tc.failures:
					print("      - " + msg)
	print("\nTESTS: %d run, %d failed, %d checks, %.1fs" % [total, failed, checks, (Time.get_ticks_msec() - t0) / 1000.0])
	get_tree().quit(failed)
