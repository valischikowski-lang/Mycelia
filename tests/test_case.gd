class_name TestCase
extends RefCounted
## Minimal test base. Methods named test_* are run by tests/test_runner.gd.
## Async tests may `await`; the runner awaits every test method.

var failures: PackedStringArray = []
var checks: int = 0
var tree: SceneTree
var host: Node


func check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures.append(msg)


func eq(a: Variant, b: Variant, msg: String) -> void:
	checks += 1
	if a != b:
		failures.append("%s (expected %s, got %s)" % [msg, str(b), str(a)])


func near(a: float, b: float, eps: float, msg: String) -> void:
	checks += 1
	if absf(a - b) > eps:
		failures.append("%s (expected %.3f ± %.3f, got %.3f)" % [msg, b, eps, a])


func new_profile() -> PlayerProfile:
	var p := PlayerProfile.new(Database)
	p.new_game()
	return p


func before_each() -> void:
	pass


func after_each() -> void:
	pass
