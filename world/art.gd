extends RefCounted

static var materials: Dictionary = {}

static func material(color: Color, glow: float = 0.0) -> StandardMaterial3D:
	var key = str(color)+str(glow)
	if materials.has(key): return materials[key]
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.86
	if glow > 0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow
	materials[key] = mat
	return mat

static func shape(parent: Node3D, kind: String, pos: Vector3, size: Vector3, color: Color, glow: float = 0) -> MeshInstance3D:
	var node = MeshInstance3D.new()
	var mesh: PrimitiveMesh
	match kind:
		"sphere":
			mesh = SphereMesh.new()
			mesh.radial_segments = 12
			mesh.rings = 6
		"cone":
			mesh = CylinderMesh.new()
			mesh.top_radius = 0.0
			mesh.bottom_radius = 0.5
			mesh.radial_segments = 7
		"cylinder":
			mesh = CylinderMesh.new()
			mesh.radial_segments = 12
		"torus":
			mesh = TorusMesh.new()
			mesh.inner_radius = 0.82
			mesh.outer_radius = 1.0
			mesh.rings = 24
			mesh.ring_segments = 6
		_:
			mesh = BoxMesh.new()
	node.mesh = mesh
	node.visibility_range_end = 160
	node.visibility_range_end_margin = 8
	node.material_override = material(color,glow)
	node.position = pos
	node.scale = size
	parent.add_child(node)
	return node

static func organism(parent: Node3D, silhouette: String, color: Color, boss: bool = false) -> Node3D:
	var root = Node3D.new()
	parent.add_child(root)
	var dark = color.darkened(0.45)
	shape(root,"sphere",Vector3(0,0.6,0),Vector3(1.3,0.72,1.6),color)
	shape(root,"sphere",Vector3(0,0.8,-0.58),Vector3(0.78,0.6,0.7),dark)
	for x in [-0.23,0.23]:
		shape(root,"sphere",Vector3(x,0.94,-0.89),Vector3(0.17,0.17,0.12),Color("e6ffe5"),1.8)
	match silhouette:
		"grazer":
			for i in range(5): shape(root,"cone",Vector3(randf_range(-0.45,0.45),1.05,randf_range(-0.35,0.55)),Vector3(0.3,0.35,0.3),color.lightened(0.3))
		"mushroom":
			shape(root,"sphere",Vector3(0,1.4,0),Vector3(2,0.48,1.9),color,0.35)
			for i in range(6): shape(root,"sphere",Vector3(sin(i)*0.64,1.7,cos(i)*0.6),Vector3.ONE*0.16,Color("f9e7bf"),1)
		"bat":
			for x in [-1,1]:
				var wing = shape(root,"cone",Vector3(x*0.9,0.7,0),Vector3(1.2,0.12,1.7),dark)
				wing.rotation.z = x*0.2
		"eel":
			for i in range(4): shape(root,"sphere",Vector3(sin(i)*0.25,0.5,0.6+i*0.4),Vector3.ONE*(0.7-i*0.12),color,0.4)
		_:
			shape(root,"sphere",Vector3(0,0.82,0.12),Vector3(1.5,0.65,1.5),color.lightened(0.12))
	for x in [-1,1]:
		for z in [-0.4,0.3,0.7]:
			var leg = shape(root,"cone",Vector3(x*0.65,0.3,z),Vector3(0.22,0.55,0.22),dark)
			leg.rotation.z = x*0.6
	if silhouette == "hopper":
		for x in [-1,1]: shape(root,"sphere",Vector3(x*0.7,0.45,0.6),Vector3(0.65,0.65,0.9),dark)
	if boss:
		for i in range(8):
			var root_limb = shape(root,"cone",Vector3(sin(i*TAU/8)*0.8,0.5,cos(i*TAU/8)*0.8),Vector3(0.5,2.5,0.5),dark)
			root_limb.rotation = Vector3(sin(i)*0.7,0,cos(i)*0.8)
		shape(root,"cone",Vector3(0,2,0.3),Vector3(0.85,1.8,0.85),Color("d3a774"))
	return root

static func label(parent: Node3D, text: String, pos: Vector3, color: Color, size: int = 32) -> Label3D:
	var node = Label3D.new()
	node.text = text
	node.position = pos
	node.font_size = size
	node.pixel_size = 0.008
	node.modulate = color
	node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	node.no_depth_test = false
	parent.add_child(node)
	return node
