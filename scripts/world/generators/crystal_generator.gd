class_name CrystalGenerator
extends RefCounted
## Clusters of faceted crystals on an optional rocky base.


static func build(rng: RandomNumberGenerator, biome: BiomeData, height: float, width: float, count: int, with_base: bool = true, glow: float = 1.4) -> Dictionary:
	var kits := build_kits(rng, biome, height, width, count, with_base)
	var mesh := (kits["crystal"] as MeshKit).commit(MaterialLib.crystal(glow))
	if with_base:
		(kits["rock"] as MeshKit).commit(MaterialLib.stone(), mesh)
	return {"mesh": mesh, "height": height, "radius": width * 1.8}


static func build_kits(rng: RandomNumberGenerator, biome: BiomeData, height: float, width: float, count: int, with_base: bool = true) -> Dictionary:
	var kit := MeshKit.new()
	var base_color := biome.pick(biome.crystal_colors, rng, Color(0.3, 0.9, 1.0))
	for i in count:
		var c := base_color.lerp(biome.pick(biome.crystal_colors, rng, base_color), rng.randf() * 0.5)
		c = Color.from_hsv(fposmod(c.h + rng.randf_range(-0.04, 0.04), 1.0), c.s, c.v)
		var h := height * (1.0 if i == 0 else rng.randf_range(0.35, 0.85))
		var w := width * (1.0 if i == 0 else rng.randf_range(0.4, 0.8))
		var tilt := 0.0 if i == 0 else rng.randf_range(0.2, 0.75)
		var dir := Vector3.UP.rotated(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized(), tilt)
		var basis := _basis_up(dir, rng.randf() * TAU)
		var off := Vector3.ZERO if i == 0 else Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized() * width * rng.randf_range(0.5, 1.4)
		kit.crystal_prism(off - Vector3.UP * w * 0.3, basis, h, w, 6 if rng.randf() > 0.3 else 5, c, rng.randf_range(0.2, 0.4))
	var rock := MeshKit.new()
	if with_base:
		var noise := FastNoiseLite.new()
		noise.seed = rng.randi()
		noise.frequency = 1.2
		var rc := biome.rock_color
		rock.ellipsoid(Vector3(0, -width * 0.2, 0), Vector3(width * 2.0, width * 0.9, width * 1.8), rc, 6, 10, Basis.IDENTITY, noise, 0.35,
			func(d: Vector3) -> Color:
				var col := rc.lerp(rc.lightened(0.25), d.y * 0.5 + 0.5)
				col.a = 0.0
				return col)
	return {"crystal": kit, "rock": rock, "height": height, "radius": width * 1.8}


static func _basis_up(up: Vector3, spin: float) -> Basis:
	var ref := Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var z := ref.cross(up).normalized()
	var x := up.cross(z).normalized()
	return Basis(x, up, z) * Basis(Vector3.UP, spin)
