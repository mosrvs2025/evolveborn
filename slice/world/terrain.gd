extends StaticBody3D
class_name Terrain
## Builds a region's cavern from its layout: chambers, the passages between
## them, walls where the floor stops and a roof over the ones that have one.
##
## The same sampling function that makes the mesh also answers "is this point
## walkable and how high is it", which is how props, creatures, pools and the
## player all end up on the ground without a single hand-placed coordinate.

var layout: Dictionary
var colors: Dictionary
var noise := FastNoiseLite.new()
var detail_noise := FastNoiseLite.new()
var cell := 1.8
var amp := 1.0
var bounds := Rect2()
var seed_value := 0

var _mesh_instance: MeshInstance3D
var _ceiling: MeshInstance3D

func build(p_layout: Dictionary, p_colors: Dictionary, p_seed := 1337) -> void:
	layout = p_layout
	colors = p_colors
	seed_value = p_seed
	cell = float(layout.get("cell", 1.8))
	amp = float(layout.get("noise", 1.0))
	noise.seed = p_seed
	noise.frequency = 0.035
	noise.fractal_octaves = 3
	detail_noise.seed = p_seed + 77
	detail_noise.frequency = 0.14
	detail_noise.fractal_octaves = 2
	_compute_bounds()
	_generate()

func _compute_bounds() -> void:
	var minv := Vector2(INF, INF)
	var maxv := Vector2(-INF, -INF)
	for z in layout.zones:
		var c: Vector2 = z.pos
		var r: float = float(z.r) + 6.0
		minv = Vector2(minf(minv.x, c.x - r), minf(minv.y, c.y - r))
		maxv = Vector2(maxf(maxv.x, c.x + r), maxf(maxv.y, c.y + r))
	bounds = Rect2(minv, maxv - minv)

# --- sampling -----------------------------------------------------------------

## Returns (strength, height). Strength 0 means outside the walkable region;
## it softens to 0 over the last fifth of every chamber so edges are not cliffs.
func sample(p: Vector2) -> Vector2:
	var best_strength := 0.0
	var best_height := 0.0
	for z in layout.zones:
		var d: float = p.distance_to(z.pos)
		var r: float = float(z.r)
		if d >= r:
			continue
		var s: float = clampf((r - d) / (r * 0.22), 0.0, 1.0)
		if s > best_strength:
			best_strength = s
			best_height = float(z.h)
	for link in layout.links:
		var a: Dictionary = layout.zones[int(link[0])]
		var b: Dictionary = layout.zones[int(link[1])]
		var w: float = float(link[2])
		var ab: Vector2 = b.pos - a.pos
		var len_sq: float = maxf(ab.length_squared(), 0.001)
		var t: float = clampf((p - a.pos).dot(ab) / len_sq, 0.0, 1.0)
		var closest: Vector2 = a.pos + ab * t
		var d2: float = p.distance_to(closest)
		if d2 >= w:
			continue
		var s2: float = clampf((w - d2) / (w * 0.3), 0.0, 1.0)
		if s2 > best_strength:
			best_strength = s2
			best_height = lerpf(float(a.h), float(b.h), smoothstep(0.0, 1.0, t))
	return Vector2(best_strength, best_height)

func height_at(x: float, z: float) -> float:
	var s := sample(Vector2(x, z))
	if s.x <= 0.0:
		return s.y
	return s.y + _surface_noise(x, z) * s.x

func _surface_noise(x: float, z: float) -> float:
	return noise.get_noise_2d(x, z) * amp + detail_noise.get_noise_2d(x, z) * amp * 0.28

func is_walkable(x: float, z: float) -> bool:
	return sample(Vector2(x, z)).x > 0.25

func ceiling_at(p: Vector2) -> float:
	var best := 0.0
	var best_s := 0.0
	for z in layout.zones:
		var d: float = p.distance_to(z.pos)
		var r: float = float(z.r) + 4.0
		if d >= r:
			continue
		var s: float = 1.0 - d / r
		if s > best_s:
			best_s = s
			best = float(z.h) + float(z.ceil)
	for link in layout.links:
		var a: Dictionary = layout.zones[int(link[0])]
		var b: Dictionary = layout.zones[int(link[1])]
		var ab: Vector2 = b.pos - a.pos
		var t: float = clampf((p - a.pos).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		var closest: Vector2 = a.pos + ab * t
		var w: float = float(link[2]) + 3.0
		var d2: float = p.distance_to(closest)
		if d2 >= w:
			continue
		var s2: float = (1.0 - d2 / w) * 0.9
		if s2 > best_s:
			best_s = s2
			best = lerpf(float(a.h) + float(a.ceil), float(b.h) + float(b.ceil), t) * 0.62
	return best

## A random walkable point, optionally constrained to one chamber.
func random_point(rng: RandomNumberGenerator, zone_index := -1, tries := 28) -> Vector3:
	for i in tries:
		var p: Vector2
		if zone_index >= 0 and zone_index < layout.zones.size():
			var z: Dictionary = layout.zones[zone_index]
			var a := rng.randf() * TAU
			var r: float = sqrt(rng.randf()) * float(z.r) * 0.82
			p = Vector2(z.pos) + Vector2(sin(a) * r, cos(a) * r)
		else:
			p = Vector2(rng.randf_range(bounds.position.x, bounds.end.x),
				rng.randf_range(bounds.position.y, bounds.end.y))
		if sample(p).x > 0.45:
			return Vector3(p.x, height_at(p.x, p.y), p.y)
	var fallback: Dictionary = layout.zones[maxi(zone_index, 0)]
	var fp: Vector2 = fallback.pos
	return Vector3(fp.x, height_at(fp.x, fp.y), fp.y)

func zone_center(index: int) -> Vector3:
	var z: Dictionary = layout.zones[clampi(index, 0, layout.zones.size() - 1)]
	var p: Vector2 = z.pos
	return Vector3(p.x, height_at(p.x, p.y), p.y)

func point_in_zone(index: int, offset: Vector2) -> Vector3:
	var z: Dictionary = layout.zones[clampi(index, 0, layout.zones.size() - 1)]
	var p: Vector2 = Vector2(z.pos) + offset
	if sample(p).x < 0.3:
		p = z.pos
	return Vector3(p.x, height_at(p.x, p.y), p.y)

# --- mesh ---------------------------------------------------------------------

func _generate() -> void:
	var nx := int(ceil(bounds.size.x / cell))
	var nz := int(ceil(bounds.size.y / cell))
	var heights := []
	var strengths := []
	heights.resize(nx + 1)
	strengths.resize(nx + 1)
	for i in nx + 1:
		var hrow := PackedFloat32Array()
		var srow := PackedFloat32Array()
		hrow.resize(nz + 1)
		srow.resize(nz + 1)
		for j in nz + 1:
			var wx := bounds.position.x + float(i) * cell
			var wz := bounds.position.y + float(j) * cell
			var s := sample(Vector2(wx, wz))
			srow[j] = s.x
			hrow[j] = s.y + _surface_noise(wx, wz) * s.x
		heights[i] = hrow
		strengths[i] = srow

	var ground: Color = colors.get("ground", Color(0.3, 0.3, 0.34))
	var ground_alt: Color = colors.get("ground_alt", Color(0.2, 0.2, 0.25))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var inside := func(i: int, j: int) -> bool:
		if i < 0 or j < 0 or i >= nx or j >= nz:
			return false
		return strengths[i][j] > 0.0 and strengths[i + 1][j] > 0.0 \
			and strengths[i][j + 1] > 0.0 and strengths[i + 1][j + 1] > 0.0

	for i in nx:
		for j in nz:
			if not inside.call(i, j):
				continue
			var x0 := bounds.position.x + float(i) * cell
			var z0 := bounds.position.y + float(j) * cell
			var x1 := x0 + cell
			var z1 := z0 + cell
			var v00 := Vector3(x0, heights[i][j], z0)
			var v10 := Vector3(x1, heights[i + 1][j], z0)
			var v01 := Vector3(x0, heights[i][j + 1], z1)
			var v11 := Vector3(x1, heights[i + 1][j + 1], z1)
			# Winding matters twice over: it decides which side is drawn AND,
			# through ConcavePolygonShape3D, which side the player can stand on.
			_tri(st, v00, v11, v01, ground, ground_alt)
			_tri(st, v00, v10, v11, ground, ground_alt)
			# Walls: wherever the floor stops, the rock starts.
			for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if inside.call(i + dir.x, j + dir.y):
					continue
				var a: Vector3
				var b: Vector3
				if dir == Vector2i(1, 0):
					a = v10; b = v11
				elif dir == Vector2i(-1, 0):
					a = v01; b = v00
				elif dir == Vector2i(0, 1):
					a = v11; b = v01
				else:
					a = v00; b = v10
				var top_a := a + Vector3(0, _wall_height(a), 0)
				var top_b := b + Vector3(0, _wall_height(b), 0)
				var wall_c: Color = ground_alt.darkened(0.25)
				var wall_top: Color = ground_alt.darkened(0.55)
				_tri_flat(st, a, top_b, b, wall_c, wall_top)
				_tri_flat(st, a, top_a, top_b, wall_c, wall_top)

	st.index()
	var mesh := st.commit()
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = mesh
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.92
	m.metallic_specular = 0.15
	_mesh_instance.material_override = m
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON \
		if Settings.shadows_enabled() else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh_instance)

	# Collision comes straight off the mesh that was just built, so what the
	# player walks on is exactly what they can see.
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(mesh.get_faces())
	var cs := CollisionShape3D.new()
	cs.shape = shape
	add_child(cs)
	collision_layer = 1
	collision_mask = 0

	# The roof is pure overdraw, so the low preset does without it.
	if bool(layout.get("roof", true)) and Settings.quality_resolved != "low":
		_build_ceiling(nx, nz, strengths)

func _wall_height(v: Vector3) -> float:
	var c := ceiling_at(Vector2(v.x, v.z))
	return maxf(c - v.y, 4.0)

func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		low: Color, high: Color) -> void:
	var n := (c - a).cross(b - a).normalized()
	for v: Vector3 in [a, b, c]:
		st.set_normal(n)
		st.set_color(_ground_color(v, low, high))
		st.add_vertex(v)

func _tri_flat(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		bottom: Color, top: Color) -> void:
	var n := (c - a).cross(b - a).normalized()
	var base_y := minf(minf(a.y, b.y), c.y)
	for v: Vector3 in [a, b, c]:
		st.set_normal(n)
		st.set_color(bottom.lerp(top, clampf((v.y - base_y) / 6.0, 0.0, 1.0)))
		st.add_vertex(v)

func _ground_color(v: Vector3, low: Color, high: Color) -> Color:
	var n := (detail_noise.get_noise_2d(v.x * 1.4, v.z * 1.4) + 1.0) * 0.5
	var slope_tint := clampf(_surface_noise(v.x, v.z) / maxf(amp, 0.001) * 0.5 + 0.5, 0.0, 1.0)
	return low.lerp(high, clampf(n * 0.7 + slope_tint * 0.3, 0.0, 1.0))

## The roof is visual only: it seals the cavern so the sky never leaks in.
func _build_ceiling(nx: int, nz: int, strengths: Array) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var roof_color: Color = Color(colors.get("ground_alt", Color(0.2, 0.2, 0.25))).darkened(0.55)
	var step := 2
	for i in range(0, nx, step):
		for j in range(0, nz, step):
			if strengths[i][j] <= 0.0:
				continue
			var x0 := bounds.position.x + float(i) * cell
			var z0 := bounds.position.y + float(j) * cell
			var x1 := x0 + cell * step
			var z1 := z0 + cell * step
			var h00 := ceiling_at(Vector2(x0, z0)) + detail_noise.get_noise_2d(x0, z0) * 1.5
			var h10 := ceiling_at(Vector2(x1, z0)) + detail_noise.get_noise_2d(x1, z0) * 1.5
			var h01 := ceiling_at(Vector2(x0, z1)) + detail_noise.get_noise_2d(x0, z1) * 1.5
			var h11 := ceiling_at(Vector2(x1, z1)) + detail_noise.get_noise_2d(x1, z1) * 1.5
			var v00 := Vector3(x0, h00, z0)
			var v10 := Vector3(x1, h10, z0)
			var v01 := Vector3(x0, h01, z1)
			var v11 := Vector3(x1, h11, z1)
			for tri in [[v00, v11, v01], [v00, v10, v11]]:
				var t0: Vector3 = tri[0]
				var t1: Vector3 = tri[1]
				var t2: Vector3 = tri[2]
				var n: Vector3 = (t1 - t0).cross(t2 - t0).normalized()
				for v: Vector3 in [t0, t1, t2]:
					st.set_normal(n)
					st.set_color(roof_color)
					st.add_vertex(v)
	st.index()
	_ceiling = MeshInstance3D.new()
	_ceiling.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.98
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ceiling.material_override = m
	_ceiling.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ceiling)
