extends RefCounted
class_name MeshLib
## Every visible thing in EVOLVEBORN is assembled from these at runtime: no
## imported models, no texture files. Materials are cached and shared so the
## compatibility renderer can batch, which is most of the browser budget.

static var _mats: Dictionary = {}
static var _meshes: Dictionary = {}

static func mat(color: Color, emission := Color(0, 0, 0, 0), roughness := 0.72,
		metallic := 0.0, unshaded := false) -> StandardMaterial3D:
	var key := "%s|%s|%.2f|%.2f|%s" % [color.to_html(), emission.to_html(), roughness, metallic, unshaded]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	m.metallic_specular = 0.35
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if emission.a > 0.001:
		m.emission_enabled = true
		m.emission = Color(emission.r, emission.g, emission.b)
		m.emission_energy_multiplier = emission.a * 2.2
	if color.a < 0.999:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats[key] = m
	return m

static func _cached(key: String, maker: Callable) -> Mesh:
	if _meshes.has(key):
		return _meshes[key]
	var m: Mesh = maker.call()
	_meshes[key] = m
	return m

# --- primitive meshes (shared, scaled by the node) ----------------------------

static func sphere_mesh(segments := 12, rings := 6) -> Mesh:
	return _cached("sph%d_%d" % [segments, rings], func():
		var s := SphereMesh.new()
		s.radius = 0.5
		s.height = 1.0
		s.radial_segments = segments
		s.rings = rings
		return s)

static func hemi_mesh(segments := 12, rings := 5) -> Mesh:
	return _cached("hemi%d_%d" % [segments, rings], func():
		var s := SphereMesh.new()
		s.radius = 0.5
		s.height = 0.5
		s.is_hemisphere = true
		s.radial_segments = segments
		s.rings = rings
		return s)

static func box_mesh() -> Mesh:
	return _cached("box", func():
		var b := BoxMesh.new()
		b.size = Vector3.ONE
		return b)

static func capsule_mesh(segments := 10, rings := 4) -> Mesh:
	return _cached("cap%d_%d" % [segments, rings], func():
		var c := CapsuleMesh.new()
		c.radius = 0.5
		c.height = 2.0
		c.radial_segments = segments
		c.rings = rings
		return c)

static func cylinder_mesh(segments := 10) -> Mesh:
	return _cached("cyl%d" % segments, func():
		var c := CylinderMesh.new()
		c.top_radius = 0.5
		c.bottom_radius = 0.5
		c.height = 1.0
		c.radial_segments = segments
		c.rings = 1
		return c)

static func cone_mesh(segments := 8) -> Mesh:
	return _cached("cone%d" % segments, func():
		var c := CylinderMesh.new()
		c.top_radius = 0.0
		c.bottom_radius = 0.5
		c.height = 1.0
		c.radial_segments = segments
		c.rings = 1
		return c)

static func torus_mesh(inner := 0.35, segments := 10, ring_segments := 16) -> Mesh:
	return _cached("tor%.2f_%d_%d" % [inner, segments, ring_segments], func():
		var t := TorusMesh.new()
		t.inner_radius = inner
		t.outer_radius = 0.5
		t.rings = ring_segments
		t.ring_segments = segments
		return t)

static func quad_mesh(size := Vector2.ONE) -> Mesh:
	return _cached("quad%.2f_%.2f" % [size.x, size.y], func():
		var q := QuadMesh.new()
		q.size = size
		return q)

# --- node builders ------------------------------------------------------------

static func part(mesh: Mesh, size: Vector3, color: Color, pos := Vector3.ZERO,
		emission := Color(0, 0, 0, 0), rough := 0.72) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.scale = size
	mi.position = pos
	mi.material_override = mat(color, emission, rough)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return mi

static func blob(size: Vector3, color: Color, pos := Vector3.ZERO,
		emission := Color(0, 0, 0, 0), detail := 12) -> MeshInstance3D:
	return part(sphere_mesh(detail, maxi(4, detail / 2)), size, color, pos, emission)

static func slab(size: Vector3, color: Color, pos := Vector3.ZERO,
		emission := Color(0, 0, 0, 0)) -> MeshInstance3D:
	return part(box_mesh(), size, color, pos, emission)

static func limb(length: float, thickness: float, color: Color, pos := Vector3.ZERO) -> MeshInstance3D:
	var mi := part(capsule_mesh(8, 3), Vector3(thickness, length * 0.5, thickness), color, pos)
	return mi

static func spike(length: float, thickness: float, color: Color, pos := Vector3.ZERO,
		emission := Color(0, 0, 0, 0)) -> MeshInstance3D:
	return part(cone_mesh(7), Vector3(thickness, length, thickness), color, pos, emission)

static func glow_dot(radius: float, color: Color, pos := Vector3.ZERO) -> MeshInstance3D:
	var mi := part(sphere_mesh(8, 4), Vector3.ONE * radius * 2.0, color, pos, Color(color.r, color.g, color.b, 1.0))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

## A flat ring that lies on the ground; used for telegraphs, pools and webs.
static func ring(radius: float, color: Color, thickness := 0.12) -> MeshInstance3D:
	var mi := part(torus_mesh(1.0 - thickness, 8, 28), Vector3.ONE * radius * 2.0, color,
		Vector3.ZERO, Color(color.r, color.g, color.b, 0.9))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

static func collision_sphere(radius: float, pos := Vector3.ZERO) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = radius
	cs.shape = sh
	cs.position = pos
	return cs

static func collision_capsule(radius: float, height: float, pos := Vector3.ZERO) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var sh := CapsuleShape3D.new()
	sh.radius = radius
	sh.height = maxf(height, radius * 2.0 + 0.01)
	cs.shape = sh
	cs.position = pos
	return cs

## Welds several primitives into one mesh with baked vertex colours, so a
## mushroom or a tree can be drawn hundreds of times as a single MultiMesh.
static func combine(parts: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false
	for p in parts:
		var src: Mesh = p.get("mesh")
		if src == null or src.get_surface_count() == 0:
			continue
		var arrays: Array = src.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var xf: Transform3D = p.get("xf", Transform3D.IDENTITY)
		var col: Color = p.get("color", Color.WHITE)
		var nb := xf.basis.inverse().transposed()
		if indices.is_empty():
			for i in verts.size():
				st.set_color(col)
				st.set_normal((nb * norms[i]).normalized())
				st.add_vertex(xf * verts[i])
		else:
			for i in indices:
				st.set_color(col)
				st.set_normal((nb * norms[i]).normalized())
				st.add_vertex(xf * verts[i])
		any = true
	if not any:
		return null
	st.index()
	return st.commit()

static func vertex_color_material(unshaded := false, rough := 0.9) -> StandardMaterial3D:
	var key := "vcm%s%.2f" % [unshaded, rough]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = rough
	m.metallic_specular = 0.2
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mats[key] = m
	return m
