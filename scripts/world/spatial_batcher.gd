class_name SpatialBatcher
extends RefCounted
## Static batching: merges many small unique meshes into one mesh per
## (grid cell, material). Trades per-object culling for far fewer draw calls,
## which matters most on mobile GPUs.

var parent: Node3D
var cells: int
var half_size: float
var _buckets: Dictionary = {}


func _init(parent_node: Node3D, grid: int = 2, world_half_size: float = 160.0) -> void:
	parent = parent_node
	cells = grid
	half_size = world_half_size


func add(kit: MeshKit, material: Material, xform: Transform3D) -> void:
	if kit == null or kit.vertex_count() == 0:
		return
	var cx := clampi(int((xform.origin.x + half_size) / (half_size * 2.0) * cells), 0, cells - 1)
	var cz := clampi(int((xform.origin.z + half_size) / (half_size * 2.0) * cells), 0, cells - 1)
	var key := "%d_%d_%d" % [cx, cz, material.get_instance_id()]
	if not _buckets.has(key):
		_buckets[key] = {"kit": MeshKit.new(), "material": material}
	(_buckets[key]["kit"] as MeshKit).merge(kit, xform)


func commit(base_name: String, shadows: bool) -> void:
	for key: String in _buckets.keys():
		var b: Dictionary = _buckets[key]
		var mi := MeshInstance3D.new()
		mi.name = "%s_%s" % [base_name, key]
		mi.mesh = (b["kit"] as MeshKit).commit(b["material"])
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)
	_buckets.clear()
