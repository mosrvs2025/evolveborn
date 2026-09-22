extends RefCounted
class_name Props
## Everything growing in the Hollow. Each kind is welded into one mesh and drawn
## through a MultiMesh, so several hundred mushrooms cost one draw call.

static func _xf(pos: Vector3, scale: Vector3, rot := Vector3.ZERO) -> Transform3D:
	var b := Basis.from_euler(rot).scaled(scale)
	return Transform3D(b, pos)

## Returns {"body": Mesh, "glow": Mesh, "height": float, "spread": float}
static func build_kind(kind: String, accent: Color, ground: Color) -> Dictionary:
	var body: Array = []
	var glow: Array = []
	var h := 1.0
	var spread := 1.0
	match kind:
		"crystal":
			for i in 3:
				var a := TAU * float(i) / 3.0
				glow.append({"mesh": cone_lp(), "color": accent.lightened(0.15),
					"xf": _xf(Vector3(sin(a) * 0.18, 0.55 - i * 0.12, cos(a) * 0.18),
						Vector3(0.24, 1.2 - i * 0.24, 0.24), Vector3(cos(a) * 0.22, 0, -sin(a) * 0.22))})
			body.append({"mesh": MeshLib.sphere_mesh(7, 4), "color": ground.darkened(0.3),
				"xf": _xf(Vector3(0, 0.06, 0), Vector3(0.6, 0.22, 0.6))})
			h = 1.6
		"stalagmite":
			body.append({"mesh": cone_lp(), "color": ground.darkened(0.15),
				"xf": _xf(Vector3(0, 0.9, 0), Vector3(0.55, 1.8, 0.55))})
			body.append({"mesh": MeshLib.sphere_mesh(7, 3), "color": ground.darkened(0.25),
				"xf": _xf(Vector3(0, 0.05, 0), Vector3(0.8, 0.22, 0.8))})
			h = 1.8
		"pebble":
			body.append({"mesh": MeshLib.sphere_mesh(6, 3), "color": ground.darkened(0.1),
				"xf": _xf(Vector3(0, 0.1, 0), Vector3(0.45, 0.3, 0.55))})
			body.append({"mesh": MeshLib.sphere_mesh(6, 3), "color": ground.darkened(0.2),
				"xf": _xf(Vector3(0.25, 0.06, -0.1), Vector3(0.26, 0.2, 0.3))})
			h = 0.3
		"mushroom":
			body.append({"mesh": MeshLib.cylinder_mesh(7), "color": Color(0.82, 0.86, 0.78),
				"xf": _xf(Vector3(0, 0.3, 0), Vector3(0.16, 0.6, 0.16))})
			glow.append({"mesh": MeshLib.hemi_mesh(9, 3), "color": accent,
				"xf": _xf(Vector3(0, 0.56, 0), Vector3(0.62, 0.5, 0.62))})
			h = 0.9
		"tall_fungus":
			body.append({"mesh": MeshLib.cylinder_mesh(8), "color": Color(0.5, 0.55, 0.48),
				"xf": _xf(Vector3(0, 1.5, 0), Vector3(0.3, 3.0, 0.3))})
			glow.append({"mesh": MeshLib.hemi_mesh(11, 4), "color": accent.lightened(0.1),
				"xf": _xf(Vector3(0, 2.9, 0), Vector3(1.7, 1.2, 1.7))})
			for i in 3:
				var a2 := TAU * float(i) / 3.0
				glow.append({"mesh": MeshLib.sphere_mesh(6, 3), "color": accent,
					"xf": _xf(Vector3(sin(a2) * 0.9, 2.5 - i * 0.3, cos(a2) * 0.9), Vector3.ONE * 0.2)})
			h = 3.4
			spread = 1.8
		"root":
			body.append({"mesh": MeshLib.torus_mesh(0.3, 7, 12), "color": ground.darkened(0.35),
				"xf": _xf(Vector3(0, 0.1, 0), Vector3(2.0, 1.4, 2.0), Vector3(0.3, 0, 0.2))})
			h = 0.8
			spread = 1.6
		"pillar":
			body.append({"mesh": MeshLib.cylinder_mesh(8), "color": Color(0.46, 0.45, 0.48),
				"xf": _xf(Vector3(0, 2.4, 0), Vector3(1.0, 4.8, 1.0))})
			body.append({"mesh": MeshLib.box_mesh(), "color": Color(0.38, 0.37, 0.4),
				"xf": _xf(Vector3(0, 0.2, 0), Vector3(1.5, 0.4, 1.5))})
			body.append({"mesh": MeshLib.box_mesh(), "color": Color(0.38, 0.37, 0.4),
				"xf": _xf(Vector3(0, 4.7, 0), Vector3(1.4, 0.4, 1.4))})
			h = 5.0
			spread = 1.6
		"block":
			body.append({"mesh": MeshLib.box_mesh(), "color": Color(0.42, 0.41, 0.44),
				"xf": _xf(Vector3(0, 0.35, 0), Vector3(1.4, 0.7, 1.2))})
			h = 0.8
		"tree":
			body.append({"mesh": MeshLib.cylinder_mesh(7), "color": Color(0.3, 0.24, 0.2),
				"xf": _xf(Vector3(0, 2.2, 0), Vector3(0.65, 4.4, 0.65))})
			for i in 3:
				var a3 := TAU * float(i) / 3.0
				body.append({"mesh": MeshLib.sphere_mesh(8, 5), "color": Color(0.26, 0.45, 0.26).lightened(i * 0.06),
					"xf": _xf(Vector3(sin(a3) * 0.9, 4.6 + i * 0.5, cos(a3) * 0.9),
						Vector3(2.6 - i * 0.4, 1.9 - i * 0.3, 2.6 - i * 0.4))})
			h = 6.4
			spread = 2.6
		"bush":
			for i in 3:
				body.append({"mesh": MeshLib.sphere_mesh(7, 4), "color": Color(0.3, 0.44, 0.28).darkened(i * 0.06),
					"xf": _xf(Vector3(0.24 * (i - 1), 0.32 + 0.08 * i, 0.16 * (i - 1)),
						Vector3(0.8 - i * 0.1, 0.6, 0.8 - i * 0.1))})
			h = 0.9
		"grass":
			for i in 3:
				var a4 := PI * float(i) / 3.0
				body.append({"mesh": MeshLib.box_mesh(), "color": Color(0.42, 0.58, 0.3),
					"xf": _xf(Vector3(0, 0.32, 0), Vector3(0.5, 0.64, 0.02), Vector3(0, a4, 0))})
			h = 0.65
		"boulder":
			body.append({"mesh": MeshLib.sphere_mesh(7, 4), "color": ground.darkened(0.18),
				"xf": _xf(Vector3(0, 0.5, 0), Vector3(1.6, 1.1, 1.4))})
			body.append({"mesh": MeshLib.sphere_mesh(6, 3), "color": ground.darkened(0.28),
				"xf": _xf(Vector3(0.6, 0.3, 0.3), Vector3(0.7, 0.55, 0.7))})
			h = 1.2
			spread = 1.6
		"corrupt_growth":
			body.append({"mesh": cone_lp(), "color": Color(0.32, 0.18, 0.28),
				"xf": _xf(Vector3(0, 0.7, 0), Vector3(0.7, 1.4, 0.7))})
			glow.append({"mesh": MeshLib.sphere_mesh(7, 4), "color": Color(0.85, 0.3, 0.5),
				"xf": _xf(Vector3(0, 1.45, 0), Vector3.ONE * 0.42)})
			h = 1.7
	return {
		"body": MeshLib.combine(body),
		"glow": MeshLib.combine(glow),
		"height": h, "spread": spread,
	}

static func cone_lp() -> Mesh:
	return MeshLib.cone_mesh(7)

## Scatters one kind across the walkable area and returns the nodes to add.
static func scatter(kind: String, count: int, terrain: Terrain, rng: RandomNumberGenerator,
		accent: Color, ground: Color) -> Array[Node3D]:
	var built := build_kind(kind, accent, ground)
	var out: Array[Node3D] = []
	if built.body == null and built.glow == null:
		return out
	var transforms: Array[Transform3D] = []
	var tries := count * 4
	while transforms.size() < count and tries > 0:
		tries -= 1
		var p := terrain.random_point(rng, -1, 3)
		if p == Vector3.ZERO:
			continue
		if not terrain.is_walkable(p.x, p.z):
			continue
		var s := rng.randf_range(0.75, 1.35)
		var basis := Basis.from_euler(Vector3(rng.randf_range(-0.06, 0.06), rng.randf() * TAU,
			rng.randf_range(-0.06, 0.06))).scaled(Vector3(s, s * rng.randf_range(0.85, 1.2), s))
		transforms.append(Transform3D(basis, p - Vector3(0, 0.05, 0)))
	if transforms.is_empty():
		return out
	for pair in [["body", false], ["glow", true]]:
		var mesh: Mesh = built[pair[0]]
		if mesh == null:
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = mesh
		mm.instance_count = transforms.size()
		for i in transforms.size():
			mm.set_instance_transform(i, transforms[i])
			var v := rng.randf_range(0.85, 1.15)
			mm.set_instance_color(i, Color(v, v, v, 1.0))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = MeshLib.vertex_color_material(bool(pair[1]), 0.92)
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if bool(pair[1]) \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		out.append(mmi)
	return out
