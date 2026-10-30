class_name WeaponModels
extends RefCounted
## Procedural weapon meshes, one silhouette per weapon kind, tinted by the
## item. Models point along +Y from the grip (origin) so a hand node can
## swing them by rotating around X.

static func build(item: ItemData) -> Node3D:
	var root := Node3D.new()
	root.name = "Weapon_" + (item.id if item else "none")
	if item == null:
		return root
	var kit := MeshKit.new()
	var glow := MeshKit.new()
	var col := item.icon_color
	var dark := Color(0.08, 0.06, 0.1, 0.02)
	var metal := Color(col.r * 0.5 + 0.35, col.g * 0.5 + 0.35, col.b * 0.5 + 0.4, 0.12)
	var edge := Color(col.r, col.g, col.b, 0.9)
	var legendary := item.rarity >= ItemData.Rarity.LEGENDARY
	match item.weapon_kind:
		"dagger":
			_blade(kit, glow, 0.42, 0.045, metal, edge)
			_grip(kit, 0.13, dark)
			kit.ellipsoid(Vector3(0, 0.0, 0), Vector3(0.07, 0.02, 0.03), metal, 3, 6)
		"sword":
			_blade(kit, glow, 0.85, 0.06, metal, edge)
			_grip(kit, 0.2, dark)
			kit.ellipsoid(Vector3(0, 0.0, 0), Vector3(0.16, 0.025, 0.04), metal, 3, 6)
		"greatsword":
			_blade(kit, glow, 1.35, 0.1, metal, edge)
			_grip(kit, 0.36, dark)
			kit.ellipsoid(Vector3(0, 0.0, 0), Vector3(0.26, 0.04, 0.06), metal, 3, 8)
		"axe":
			kit.tube(PackedVector3Array([Vector3(0, -0.25, 0), Vector3(0.02, 0.4, 0), Vector3(0, 0.95, 0)]), PackedFloat32Array([0.035, 0.04, 0.035]), 5, func(_t: float) -> Color: return Color(0.25, 0.16, 0.1, 0.02), true, true)
			kit.crystal_prism(Vector3(0.02, 0.82, 0), Basis(Vector3.FORWARD, -PI * 0.5), 0.36, 0.13, 4, metal, 0.3)
			glow.crystal_prism(Vector3(0.36, 0.82, 0), Basis(Vector3.FORWARD, -PI * 0.5), 0.05, 0.12, 4, edge, 0.5)
		"hammer":
			kit.tube(PackedVector3Array([Vector3(0, -0.3, 0), Vector3(0, 0.5, 0), Vector3(0, 1.05, 0)]), PackedFloat32Array([0.04, 0.045, 0.04]), 5, func(_t: float) -> Color: return Color(0.22, 0.16, 0.12, 0.02), true, true)
			kit.ellipsoid(Vector3(0, 1.08, 0), Vector3(0.28, 0.17, 0.17), metal, 5, 8)
			glow.ellipsoid(Vector3(0, 1.08, 0.17), Vector3(0.09, 0.09, 0.03), edge, 4, 6)
		"staff", "wand":
			var length := 1.5 if item.weapon_kind == "staff" else 1.25
			kit.tube(MeshKit.spline(PackedVector3Array([Vector3(0, -0.5, 0), Vector3(0.03, 0.3, 0), Vector3(-0.02, length - 0.3, 0.02), Vector3(0.04, length - 0.05, 0)]), 3), MeshKitFit.fit([0.03, 0.028, 0.025, 0.03], 10), 5, func(_t: float) -> Color: return Color(0.2, 0.13, 0.12, 0.03), true, true)
			glow.ellipsoid(Vector3(0.04, length + 0.06, 0), Vector3.ONE * 0.1, Color(col.r, col.g, col.b, 1.0), 6, 10)
			for k in 3:
				var a := TAU * k / 3.0
				kit.tube(PackedVector3Array([Vector3(0.04, length - 0.1, 0), Vector3(0.04 + cos(a) * 0.12, length + 0.1, sin(a) * 0.12), Vector3(0.04 + cos(a) * 0.04, length + 0.22, sin(a) * 0.04)]), PackedFloat32Array([0.018, 0.012, 0.005]), 3, func(_t: float) -> Color: return metal, false, true)
		"bow":
			var arc := PackedVector3Array()
			var rr := PackedFloat32Array()
			for k in 9:
				var t := float(k) / 8.0
				arc.append(Vector3(0, (t - 0.5) * 1.3, -sin(t * PI) * 0.28))
				rr.append(0.03 * (1.0 - absf(t - 0.5)))
			kit.tube(arc, rr, 4, func(_t: float) -> Color: return Color(col.r * 0.4, col.g * 0.35, col.b * 0.35, 0.05), true, true)
			glow.tube(PackedVector3Array([Vector3(0, -0.65, 0), Vector3(0, 0.65, 0)]), PackedFloat32Array([0.005, 0.005]), 3, func(_t: float) -> Color: return Color(col.r, col.g, col.b, 0.7), false, false)
		"shield":
			kit.ellipsoid(Vector3(0, 0, 0), Vector3(0.27, 0.33, 0.05), metal, 6, 12)
			kit.ellipsoid(Vector3(0, 0, 0.05), Vector3(0.12, 0.12, 0.05), dark, 4, 8)
			glow.ellipsoid(Vector3(0, 0, 0.08), Vector3(0.06, 0.06, 0.03), edge, 4, 6)
		_:
			# Orbs, grimoires and other held artefacts.
			glow.ellipsoid(Vector3(0, 0.15, 0), Vector3.ONE * 0.12, Color(col.r, col.g, col.b, 0.9), 6, 10)
	if kit.vertex_count() > 0:
		var mi := MeshInstance3D.new()
		mi.mesh = kit.commit(MaterialLib.organic("weapon_body", {"emission": 1.2, "pulse": 0.0, "rim": Color(0.7, 0.7, 1.0), "rim_strength": 0.6, "roughness": 0.35}))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	if glow.vertex_count() > 0:
		var gm := MeshInstance3D.new()
		gm.mesh = glow.commit(MaterialLib.organic("weapon_glow", {"emission": 4.0 if legendary else 2.6, "pulse": 0.4, "pulse_speed": 2.0}))
		gm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(gm)
	if legendary:
		var motes := SpellFX.ambient_motes(item.icon_color, 10, Vector3(0.15, 0.5, 0.15), 0.05)
		motes.position.y = 0.6
		root.add_child(motes)
	return root


static func _blade(kit: MeshKit, glow: MeshKit, length: float, width: float, metal: Color, edge: Color) -> void:
	kit.crystal_prism(Vector3(0, 0.02, 0), Basis.IDENTITY.scaled(Vector3(1.0, 1.0, 0.25)), length, width, 4, metal, 0.18)
	glow.crystal_prism(Vector3(0, 0.05, 0.012), Basis.IDENTITY.scaled(Vector3(1.0, 1.0, 0.1)), length * 0.92, width * 0.25, 4, edge, 0.2)


static func _grip(kit: MeshKit, length: float, col: Color) -> void:
	kit.tube(PackedVector3Array([Vector3(0, -length, 0), Vector3(0, 0, 0)]), PackedFloat32Array([0.03, 0.026]), 5, func(_t: float) -> Color: return col, true, true)


## Tiny helper so this file doesn't depend on CreatureBuilder internals.
class MeshKitFit:
	static func fit(values: Array, count: int) -> PackedFloat32Array:
		var out := PackedFloat32Array()
		for i in count:
			var t := float(i) / maxf(1.0, count - 1) * (values.size() - 1)
			var a := int(floor(t))
			var b := mini(a + 1, values.size() - 1)
			out.append(lerpf(float(values[a]), float(values[b]), t - a))
		return out
