class_name CrookedArchitecture
extends RefCounted
## Dark-fantasy buildings: leaning half-timbered witch houses with twisted
## witch-hat roofs, a castle of crooked towers and bent iron lanterns. All
## procedural; every result returns separate MeshKits (walls / roofs / glow)
## so callers can batch many buildings into a few draw calls.

const PLASTER := Color("#2b2742")
const PLASTER_TOP := Color("#3b3458")
const BEAM := Color("#120a18")
const ROOF := Color("#16304f")
const ROOF_TIP := Color("#2d5a8c")
const STONE := Color("#25203a")
const STONE_TOP := Color("#3a3352")
const WINDOW := Color(1.0, 0.68, 0.26, 1.0)


## Adds a quad from four new vertices given clockwise as seen from outside
## (top-left, top-right, bottom-right, bottom-left).
static func _face(kit: MeshKit, tl: Vector3, tr: Vector3, br: Vector3, bl: Vector3, c_top: Color, c_bottom: Color) -> void:
	var a := kit.add_vertex(tl, c_top)
	var b := kit.add_vertex(tr, c_top)
	var c := kit.add_vertex(br, c_bottom)
	var d := kit.add_vertex(bl, c_bottom)
	kit.add_quad(a, b, c, d)


## A box from 8 corners: bottom 0..3 then top 4..7, each ring ordered
## (-x,-z), (+x,-z), (+x,+z), (-x,+z). Sides and top only.
static func skew_box(kit: MeshKit, k: Array[Vector3], c_top: Color, c_bottom: Color, with_top: bool = true) -> void:
	_face(kit, k[7], k[6], k[2], k[3], c_top, c_bottom)  # +Z
	_face(kit, k[5], k[4], k[0], k[1], c_top, c_bottom)  # -Z
	_face(kit, k[6], k[5], k[1], k[2], c_top, c_bottom)  # +X
	_face(kit, k[4], k[7], k[3], k[0], c_top, c_bottom)  # -X
	if with_top:
		_face(kit, k[4], k[5], k[6], k[7], c_top, c_top)


static func _corners(center: Vector3, w: float, d: float, h: float, lean: Vector3, twist: float, top_scale: float = 1.0) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var signs := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	for level in 2:
		var s := 1.0 if level == 0 else top_scale
		var rot := Basis(Vector3.UP, twist * level)
		for sg: Vector2 in signs:
			var local := rot * Vector3(sg.x * w * 0.5 * s, 0, sg.y * d * 0.5 * s)
			out.append(center + local + Vector3(0, h * level, 0) + lean * level)
	return out


## Point on a box side (u across, v up, both 0..1) pushed slightly outward.
static func _on_side(k: Array[Vector3], side: int, u: float, v: float) -> Dictionary:
	var idx: Array = [[3, 2], [1, 0], [2, 1], [0, 3]][side]
	var b0: Vector3 = k[idx[0]]
	var b1: Vector3 = k[idx[1]]
	var t0: Vector3 = k[idx[0] + 4]
	var t1: Vector3 = k[idx[1] + 4]
	var p := b0.lerp(b1, u).lerp(t0.lerp(t1, u), v)
	var n := (b1 - b0).cross(t0 - b0).normalized()
	return {"p": p, "n": n}


## A crooked witch-hat roof: a bent cone tube that ends in a curling tip.
static func witch_roof(kit: MeshKit, base_center: Vector3, radius: float, height: float, lean: Vector3, curl: float, sides: int = 8) -> void:
	var path := PackedVector3Array()
	var radii := PackedFloat32Array()
	for i in 10:
		var t := float(i) / 9.0
		var bend := lean * t * t + Vector3(sin(t * PI) * curl, 0, cos(t * PI) * curl * 0.3) * t
		path.append(base_center + Vector3(0, height * t, 0) + bend)
		var r := radius * pow(1.0 - t, 1.3) + 0.03
		if i == 0:
			r *= 1.15
		radii.append(r)
	kit.tube(path, radii, sides, func(t: float) -> Color:
		var c := ROOF.lerp(ROOF_TIP, t)
		c.a = 0.03
		return c, true, true)


## Leaning half-timbered house. Returns {"walls", "roof", "glow"} kits and
## {"size"} (collision box size) in local space of `xf`.
static func crooked_house(rng: RandomNumberGenerator, xf: Transform3D) -> Dictionary:
	var walls := MeshKit.new()
	var roof := MeshKit.new()
	var glow := MeshKit.new()
	var w := rng.randf_range(3.6, 5.2)
	var d := rng.randf_range(3.4, 4.8)
	var h1 := rng.randf_range(2.8, 3.6)
	var lean := Vector3(rng.randf_range(-0.45, 0.45), 0, rng.randf_range(-0.35, 0.35))
	var k1 := _corners(Vector3(0, -0.3, 0), w, d, h1 + 0.3, lean, rng.randf_range(-0.06, 0.06), rng.randf_range(0.95, 1.08))
	skew_box(walls, k1, PLASTER_TOP, PLASTER, false)
	var top_center := (k1[4] + k1[5] + k1[6] + k1[7]) * 0.25
	var top_k := k1
	var floors := 1
	if rng.randf() < 0.65:
		# Overhanging upper storey, leaning further.
		var lean2 := lean * rng.randf_range(0.6, 1.4) + Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.3, 0.3))
		var h2 := rng.randf_range(2.2, 3.0)
		var k2 := _corners(top_center, w * 1.12, d * 1.12, h2, lean2, rng.randf_range(-0.1, 0.1), rng.randf_range(0.92, 1.05))
		skew_box(walls, k2, PLASTER_TOP.lightened(0.05), PLASTER_TOP, false)
		top_k = k2
		top_center = (k2[4] + k2[5] + k2[6] + k2[7]) * 0.25
		floors = 2
	# Timber beams on the corners and floor lines.
	var beam_r := PackedFloat32Array([0.09, 0.09])
	var beams_of := [k1] if floors == 1 else [k1, top_k]
	for kk: Array[Vector3] in beams_of:
		for i in 4:
			walls.tube(PackedVector3Array([kk[i], kk[i + 4]]), beam_r, 4, func(_t: float) -> Color: return BEAM, false, false)
			walls.tube(PackedVector3Array([kk[i + 4], kk[(i + 1) % 4 + 4]]), beam_r, 4, func(_t: float) -> Color: return BEAM, false, false)
			# Diagonal brace.
			if rng.randf() < 0.5:
				walls.tube(PackedVector3Array([kk[i], kk[(i + 1) % 4 + 4]]), PackedFloat32Array([0.06, 0.06]), 4, func(_t: float) -> Color: return BEAM, false, false)
	# Windows (warm, glowing) and a door.
	var all_boxes: Array = [k1] if floors == 1 else [k1, top_k]
	for bi in all_boxes.size():
		var kk: Array[Vector3] = all_boxes[bi]
		for side in 4:
			var count := rng.randi_range(0, 2) if bi == 0 else rng.randi_range(1, 2)
			for wi in count:
				var u := (float(wi) + 1.0) / (count + 1.0) + rng.randf_range(-0.06, 0.06)
				var v := rng.randf_range(0.45, 0.7)
				if bi == 0 and side == 0 and absf(u - 0.5) < 0.2:
					continue
				var at := _on_side(kk, side, u, v)
				var n: Vector3 = at["n"]
				var basis := Basis.looking_at(n, Vector3.UP)
				var round := rng.randf() < 0.3
				var sz := Vector3(0.38, 0.38 if round else 0.55, 0.12)
				glow.ellipsoid((at["p"] as Vector3) + n * 0.04, sz, WINDOW, 4, 8, basis)
				# Dark window frame cross.
				walls.tube(PackedVector3Array([(at["p"] as Vector3) + n * 0.1 + basis.y * sz.y, (at["p"] as Vector3) + n * 0.1 - basis.y * sz.y]), PackedFloat32Array([0.035, 0.035]), 3, func(_t: float) -> Color: return BEAM, false, false)
	var door := _on_side(k1, 0, 0.5, 0.0)
	var dn: Vector3 = door["n"]
	walls.ellipsoid((door["p"] as Vector3) + dn * 0.05 + Vector3.UP * 0.95, Vector3(0.6, 1.0, 0.1), Color(0.05, 0.02, 0.06, 0.0), 5, 10, Basis.looking_at(dn, Vector3.UP))
	glow.ellipsoid((door["p"] as Vector3) + dn * 0.25 + Vector3.UP * 2.25, Vector3(0.14, 0.18, 0.14), WINDOW, 4, 6)
	# Roof and chimney.
	var roof_r := maxf(w, d) * 0.82
	witch_roof(roof, top_center - Vector3(0, 0.2, 0), roof_r, rng.randf_range(3.5, 6.5), lean * 2.0 + Vector3(rng.randf_range(-1.0, 1.0), 0, rng.randf_range(-1.0, 1.0)), rng.randf_range(0.3, 1.2))
	var ch := top_center + Vector3(w * 0.25, 0, -d * 0.2)
	walls.tube(PackedVector3Array([ch, ch + Vector3(0.2, 2.4, 0.1), ch + Vector3(0.45, 3.3, 0.2)]), PackedFloat32Array([0.32, 0.28, 0.3]), 6, func(_t: float) -> Color: return Color("#1c1426"), false, true)
	var result := {
		"walls": _xform(walls, xf), "roof": _xform(roof, xf), "glow": _xform(glow, xf),
		"size": Vector3(w, h1 + 2.5 * (floors - 1), d), "chimney": xf * (ch + Vector3(0.45, 3.4, 0.2)),
	}
	return result


static func _xform(kit: MeshKit, xf: Transform3D) -> MeshKit:
	var out := MeshKit.new()
	out.merge(kit, xf)
	return out


## Castle of crooked towers. Returns kits {"stone", "roof", "glow"} in world space.
static func dark_castle(rng: RandomNumberGenerator, origin: Vector3, scale: float) -> Dictionary:
	var stone := MeshKit.new()
	var roof := MeshKit.new()
	var glow := MeshKit.new()
	var towers: Array[Vector3] = []
	var count := 8
	for i in count:
		var x := (float(i) / (count - 1) - 0.5) * 110.0 * scale
		var z := sin(i * 1.7) * 18.0 * scale
		var h := (rng.randf_range(30.0, 55.0) if absf(x) > 20.0 * scale else rng.randf_range(65.0, 95.0)) * scale
		var r := rng.randf_range(4.0, 7.5) * scale
		var base := origin + Vector3(x, -6.0, z)
		var lean := Vector3(rng.randf_range(-4.0, 4.0), 0, rng.randf_range(-2.0, 2.0)) * scale
		var path := PackedVector3Array()
		var radii := PackedFloat32Array()
		for k in 8:
			var t := float(k) / 7.0
			path.append(base + Vector3(0, h * t, 0) + lean * t * t)
			radii.append(r * (1.1 - 0.25 * t) * (1.0 + 0.15 * sin(t * 9.0 + i)))
		stone.tube(path, radii, 10, func(t: float) -> Color:
			var c := STONE.lerp(STONE_TOP, t)
			c.a = 0.0
			return c, true, false)
		var top := path[path.size() - 1]
		# A ring of battlements, then a witch-hat roof (or a mushroom cap!).
		var ring := PackedVector3Array()
		var rr := PackedFloat32Array()
		for k in 13:
			var a := TAU * k / 12.0
			ring.append(top + Vector3(cos(a), 0, sin(a)) * r * 1.0)
			rr.append(r * 0.18)
		stone.tube(ring, rr, 5, func(_t: float) -> Color: return STONE_TOP, false, false)
		if i % 3 == 1:
			var p := MushroomParams.new()
			p.seed = rng.randi()
			p.cap_shape = MushroomParams.CapShape.DOME
			p.stem_height = 0.1
			p.stem_width = r * 0.6
			p.cap_radius = r * 1.8
			p.cap_height = r * 1.2
			p.cap_color = Color("#2c0f52")
			p.cap_top_color = Color("#45106a")
			p.glow_color = Color("#6dffb0")
			p.spot_color = Color("#ffb347")
			p.spots = 6
			p.cap_segments = 16
			MushroomGenerator.build_into(roof, p, Transform3D(Basis.IDENTITY, top))
		else:
			witch_roof(roof, top, r * 1.35, r * rng.randf_range(2.5, 4.0), Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-2, 2)) * scale, rng.randf_range(0.5, 2.5) * scale, 10)
		# Windows climbing the tower.
		for wdw in rng.randi_range(4, 9):
			var t2 := rng.randf_range(0.2, 0.92)
			var idx := clampi(int(t2 * 7), 0, 6)
			var c := path[idx].lerp(path[idx + 1], t2 * 7 - idx)
			var a2 := rng.randf_range(-1.2, 1.2) + PI * 0.5
			var n := Vector3(cos(a2), 0, sin(a2))
			glow.ellipsoid(c + n * radii[idx] * 1.02, Vector3(0.7, 1.2, 0.3) * scale, WINDOW, 4, 6, Basis.looking_at(n, Vector3.UP))
		towers.append(top)
		# Curtain wall to the previous tower.
		if i > 0:
			var prev := origin + Vector3((float(i - 1) / (count - 1) - 0.5) * 110.0 * scale, -6.0, sin((i - 1) * 1.7) * 18.0 * scale)
			var mid_h := 18.0 * scale
			var dir := (base - prev)
			var side := Vector3(-dir.z, 0, dir.x).normalized() * 2.0 * scale
			var k: Array[Vector3] = [prev - side, base - side, base + side, prev + side, prev - side + Vector3.UP * mid_h, base - side + Vector3.UP * mid_h * 1.1, base + side + Vector3.UP * mid_h * 1.1, prev + side + Vector3.UP * mid_h]
			skew_box(stone, k, STONE_TOP, STONE, true)
	return {"stone": stone, "roof": roof, "glow": glow}


## Bent iron lantern post. Returns kits {"iron", "glow"} and the lamp position.
static func lantern_post(rng: RandomNumberGenerator, foot: Vector3, facing: Vector3) -> Dictionary:
	var iron := MeshKit.new()
	var glow := MeshKit.new()
	var h := rng.randf_range(3.2, 4.2)
	var lean := Vector3(rng.randf_range(-0.25, 0.25), 0, rng.randf_range(-0.25, 0.25))
	var top := foot + Vector3(0, h, 0) + lean
	iron.tube(PackedVector3Array([foot - Vector3(0, 0.3, 0), foot + Vector3(0, h * 0.5, 0) + lean * 0.3, top]), PackedFloat32Array([0.11, 0.07, 0.06]), 6,
		func(_t: float) -> Color: return Color("#0e0a14"), true, false)
	var hook_end := top + facing * 0.9 + Vector3(0, 0.25, 0)
	iron.tube(MeshKit.spline(PackedVector3Array([top, top + facing * 0.5 + Vector3(0, 0.45, 0), hook_end]), 3), PackedFloat32Array([0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05]), 4,
		func(_t: float) -> Color: return Color("#0e0a14"), false, true)
	var lamp := hook_end - Vector3(0, 0.55, 0)
	glow.ellipsoid(lamp, Vector3(0.2, 0.28, 0.2), WINDOW, 5, 8)
	iron.crystal_prism(lamp + Vector3(0, 0.22, 0), Basis.IDENTITY, 0.25, 0.26, 4, Color("#0e0a14"), 0.9)
	return {"iron": iron, "glow": glow, "lamp": lamp}
