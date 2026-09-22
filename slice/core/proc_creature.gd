extends RefCounted
class_name ProcCreature
## Body plans. Each one assembles a creature out of primitives and hands back
## the pieces that move, so CreatureVisuals can animate a walk, a flap or a
## throat inflating without any of it being a canned clip.
##
## Returned dictionary:
##   root, body, head, legs[], wings[], flex[], glows[], height, radius

static func build(plan: String, data: CreatureData) -> Dictionary:
	var c1: Color = data.color_primary
	var c2: Color = data.color_secondary
	var gl: Color = data.glow
	var p := {
		"root": Node3D.new(), "body": null, "head": null,
		"legs": [], "wings": [], "flex": [], "glows": [],
		"height": 1.4, "radius": 0.7,
	}
	match plan:
		"grazer_quad": _grazer(p, c1, c2, gl)
		"mite": _mite(p, c1, c2, gl)
		"beetle": _beetle(p, c1, c2, gl)
		"fungal": _fungal(p, c1, c2, gl)
		"bat": _bat(p, c1, c2, gl)
		"hopper": _hopper(p, c1, c2, gl)
		"eel": _eel(p, c1, c2, gl)
		"crawler": _crawler(p, c1, c2, gl)
		"toad": _toad(p, c1, c2, gl)
		"spider": _spider(p, c1, c2, gl)
		"sentinel": _sentinel(p, c1, c2, gl)
		_: _grazer(p, c1, c2, gl)
	var s: float = data.body_scale
	p.root.scale = Vector3.ONE * s
	p.height = float(p.height) * s
	p.radius = float(p.radius) * s
	return p

# --- helpers ------------------------------------------------------------------

static func _leg(parent: Node3D, hip: Vector3, length: float, thickness: float,
		color: Color, splay := 0.0, forward := 0.0) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = hip
	var seg := MeshLib.limb(length, thickness, color)
	seg.position = Vector3(0, -length * 0.5, 0)
	pivot.add_child(seg)
	pivot.rotation = Vector3(forward, 0, splay)
	parent.add_child(pivot)
	return pivot

## Two-segment arched leg: up and out, then down. Reads as arthropod.
static func _arch_leg(parent: Node3D, hip: Vector3, upper: float, lower: float,
		thickness: float, color: Color, out_angle: float, yaw: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = hip
	pivot.rotation = Vector3(0, yaw, 0)
	var up_node := Node3D.new()
	up_node.rotation = Vector3(0, 0, out_angle)
	var up_seg := MeshLib.limb(upper, thickness, color)
	up_seg.position = Vector3(0, -upper * 0.5, 0)
	up_node.add_child(up_seg)
	var knee := Node3D.new()
	knee.position = Vector3(0, -upper, 0)
	knee.rotation = Vector3(0, 0, -out_angle * 1.85)
	var low_seg := MeshLib.limb(lower, thickness * 0.8, color)
	low_seg.position = Vector3(0, -lower * 0.5, 0)
	knee.add_child(low_seg)
	up_node.add_child(knee)
	pivot.add_child(up_node)
	parent.add_child(pivot)
	return pivot

static func _eyes(parent: Node3D, glows: Array, pos: Vector3, spread: float,
		radius: float, color: Color) -> void:
	for side in [-1.0, 1.0]:
		var e := MeshLib.glow_dot(radius, color, pos + Vector3(spread * side, 0, 0))
		parent.add_child(e)
		glows.append(e)

static func _eye_color(gl: Color, fallback: Color) -> Color:
	if gl.a > 0.01:
		return Color(gl.r, gl.g, gl.b)
	return fallback

# --- body plans ---------------------------------------------------------------

static func _grazer(p: Dictionary, c1: Color, c2: Color, gl: Color) -> void:
	var r: Node3D = p.root
	var body := MeshLib.blob(Vector3(1.5, 0.95, 1.9), c1, Vector3(0, 0.78, 0))
	r.add_child(body)
	p.body = body
	# Moss growing on its back: the reason it is called a grazer and the reason
	# its trait is regenerative.
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 7:
		var tuft := MeshLib.blob(Vector3(0.36, 0.26, 0.36) * rng.randf_range(0.7, 1.3), c2,
			Vector3(rng.randf_range(-0.5, 0.5), 1.15 + rng.randf_range(-0.06, 0.1), rng.randf_range(-0.7, 0.6)),
			Color(gl.r, gl.g, gl.b, gl.a * 0.5))
		body.add_child(tuft)
	var head := MeshLib.blob(Vector3(0.78, 0.66, 0.8), c1, Vector3(0, 0.72, 1.12))
	r.add_child(head)
	p.head = head
	_eyes(head, p.glows, Vector3(0, 0.12, 0.3), 0.22, 0.09, _eye_color(gl, c2))
	var mouth := MeshLib.slab(Vector3(0.4, 0.07, 0.12), c2.darkened(0.4), Vector3(0, -0.18, 0.33))
	head.add_child(mouth)
	for x in [-0.55, 0.55]:
		for z in [-0.66, 0.7]:
			p.legs.append(_leg(r, Vector3(x, 0.52, z), 0.58, 0.3, c1.darkened(0.25)))
	p.height = 1.5
	p.radius = 0.82

static func _mite(p: Dictionary, c1: Color, c2: Color, gl: Color) -> void:
	var r: Node3D = p.root
	var body := MeshLib.blob(Vector3(0.6, 0.5, 0.8), c1, Vector3(0, 0.42, 0))
	r.add_child(body)
	p.body = body
	var abdomen := MeshLib.blob(Vector3(0.62, 0.56, 0.66), c2, Vector3(0, 0.44, -0.55),
		Color(gl.r, gl.g, gl.b, gl.a))
	r.add_child(abdomen)
	p.glows.append(abdomen)
	var head := MeshLib.blob(Vector3(0.42, 0.36, 0.42), c1.lightened(0.1), Vector3(0, 0.42, 0.48))
	r.add_child(head)
	p.head = head
	_eyes(head, p.glows, Vector3(0, 0.06, 0.16), 0.13, 0.055, _eye_color(gl, c2))
	for side in [-1.0, 1.0]:
		var m := MeshLib.spike(0.26, 0.09, c2, Vector3(0.1 * side, -0.08, 0.26))
		m.rotation_degrees = Vector3(95, 0, -12 * side)
		head.add_child(m)
		var ant := MeshLib.limb(0.34, 0.05, c2, Vector3(0.12 * side, 0.14, 0.14))
		ant.rotation_degrees = Vector3(-42, 0, 26 * side)
		head.add_child(ant)
	for i in 3:
		var z := 0.22 - i * 0.28
		for side in [-1.0, 1.0]:
			p.legs.append(_arch_leg(r, Vector3(0.22 * side, 0.42, z), 0.3, 0.32, 0.07,
				c1.darkened(0.1), 0.85 * side, 0.0))
	p.height = 0.8
	p.radius = 0.5

static func _beetle(p: Dictionary, c1: Color, c2: Color, gl: Color) -> void:
	var r: Node3D = p.root
	var shell := MeshLib.part(MeshLib.hemi_mesh(14, 6), Vector3(1.9, 2.0, 2.3), c2,
		Vector3(0, 0.55, -0.05))
	r.add_child(shell)
	p.body = shell
	# Seams glow, which is how you can tell it is alive under all that plate.
	for i in 3:
		var seam := MeshLib.slab(Vector3(1.75 - i * 0.28, 0.05, 0.09), c1.darkened(0.3),
			Vector3(0, 0.62 + i * 0.16, 0.42 - i * 0.42), Color(gl.r, gl.g, gl.b, gl.a))
		r.add_child(seam)
		p.glows.append(seam)
	var under := MeshLib.blob(Vector3(1.5, 0.5, 1.9), c1.darkened(0.35), Vector3(0, 0.42, 0))
	r.add_child(under)
	var head := MeshLib.blob(Vector3(0.8, 0.55, 0.65), c1, Vector3(0, 0.46, 1.02))
	r.add_child(head)
	p.head = head
	_eyes(head, p.glows, Vector3(0, 0.1, 0.22), 0.24, 0.07, _eye_color(gl, c2))
	for side in [-1.0, 1.0]:
		var m := MeshLib.spike(0.46, 0.14, c2, Vector3(0.22 * side, -0.06, 0.3))
		m.rotation_degrees = Vector3(84, 0, -22 * side)
		head.add_child(m)
	for i in 3:
		var z := 0.6 - i * 0.62
		for side in [-1.0, 1.0]:
			p.legs.append(_arch_leg(r, Vector3(0.62 * side, 0.46, z), 0.32, 0.34, 0.13,
				c1.darkened(0.2), 0.9 * side, 0.0))
	p.height = 1.6
	p.radius = 1.05

static func _fungal(p: Dictionary, c1: Color, c2: Color, gl: Color) -> void:
	var r: Node3D = p.root
	var stem := MeshLib.part(MeshLib.cylinder_mesh(10), Vector3(0.52, 1.05, 0.52), c1,
		Vector3(0, 0.52, 0))
	r.add_child(stem)
	p.body = stem
	var cap := MeshLib.part(MeshLib.hemi_mesh(14, 5), Vector3(1.6, 1.5, 1.6), c2,
		Vector3(0, 0.98, 0), Color(gl.r, gl.g, gl.b, gl.a * 0.55))
	r.add_child(cap)
	p.flex.append(cap)
	p.glows.append(cap)
	for i in 8:
		var a := TAU * float(i) / 8.0
		var gill := MeshLib.slab(Vector3(0.06, 0.16, 0.6), c1.lightened(0.15),
			Vector3(sin(a) * 0.38, 0.92, cos(a) * 0.38))
		gill.rotation.y = -a
		r.add_child(gill)
	# Loose spores drift near it; they are also the tell that it is about to burst.
	for i in 3:
		var a2 := TAU * float(i) / 3.0
		var spore := MeshLib.glow_dot(0.1, _eye_color(gl, c2),
			Vector3(sin(a2) * 0.9, 1.35 + i * 0.12, cos(a2) * 0.9))
		r.add_child(spore)
		p.glows.append(spore)
		p.flex.append(spore)
	_eyes(stem, p.glows, Vector3(0, 0.15, 0.24), 0.12, 0.055, _eye_color(gl, c2))
	p.height = 1.7
	p.radius = 0.7

static func _bat(p: Dictionary, c1: Color, c2: Color, gl: Color) -> void:
	var r: Node3D = p.root
	var body := MeshLib.blob(Vector3(0.48, 0.5, 0.86), c1, Vector3.ZERO)
	r.add_child(body)
	p.body = body
	var head := MeshLib.blob(Vector3(0.42, 0.4, 0.42), c1.lightened(0.08), Vector3(0, 0.06, 0.48))
	r.add_child(head)
	p.head = head
	_eyes(head, p.glows, Vector3(0, 0.04, 0.16), 0.13, 0.06, _eye_color(gl, c2))
	for side in [-1.0, 1.0]:
		var ear := MeshLib.spike(0.42, 0.2, c2, Vector3(0.14 * side, 0.22, 0.02))
		ear.rotation_degrees = Vector3(-12, 0, 16 * side)
		head.add_child(ear)
		# Wing: a pivot at the shoulder so the flap is a rotation, not a clip.
		var wing_pivot := Node3D.new()
		wing_pivot.position = Vector3(0.2 * side, 0.08, 0)
		var membrane := MeshLib.part(MeshLib.box_mesh(), Vector3(1.15, 0.04, 0.8), c2,
			Vector3(0.58 * side, 0, -0.05), Color(gl.r, gl.g, gl.b, gl.a * 0.4))
		wing_pivot.add_child(membrane)
		var bone := MeshLib.limb(1.1, 0.07, c1.lightened(0.2), Vector3(0.55 * side, 0.03, 0.22))
		bone.rotation_degrees = Vector3(0, 0, 90)
		wing_pivot.add_child(bone)
		r.add_child(wing_pivot)
		p.wings.append(wing_pivot)
	var tail := MeshLib.spike(0.5, 0.14, c1, Vector3(0, -0.02, -0.55))
	tail.rotation_degrees = Vector3(-96, 0, 0)
	r.add_child(tail)
	p.height = 0.7
	p.radius = 0.5

static func _hopper(p: Dictionary, c1: Color, c2: Color, gl: Color) -> void:
	var r: Node3D = p.root
	var body := MeshLib.blob(Vector3(0.86, 0.78, 1.25), c1, Vector3(0, 0.72, 0))
	r.add_child(body)
	p.body = body
	for i in 4:
		var sp := MeshLib.spike(0.4, 0.16, c2, Vector3(0, 1.06 + sin(i * 0.4) * 0.03, 0.4 - i * 0.3),
			Color(gl.r, gl.g, gl.b, gl.a * 0.6))
		sp.rotation_degrees = Vector3(-18, 0, 0)
		r.add_child(sp)
	var head := MeshLib.blob(Vector3(0.58, 0.5, 0.6), c1.lightened(0.05), Vector3(0, 0.84, 0.72))
	r.add_child(head)
	p.head = head
	_eyes(head, p.glows, Vector3(0, 0.1, 0.2), 0.19, 0.075, _eye_color(gl, c2))
	# The haunches are the whole creature: big, folded, and obviously loaded.
	for side in [-1.0, 1.0]:
		var haunch_pivot := Node3D.new()
		haunch_pivot.position = Vector3(0.44 * side, 0.74, -0.42)
		var haunch := MeshLib.blob(Vector3(0.52, 0.66, 0.72), c1.darkened(0.12), Vector3.ZERO)
		haunch_pivot.add_child(haunch)
		var shin := MeshLib.limb(0.72, 0.19, c1.darkened(0.3), Vector3(0.06 * side, -0.48, 0.12))
		shin.rotation_degrees = Vector3(28, 0, 0)
		haunch_pivot.add_child(shin)
		var foot := MeshLib.slab(Vector3(0.22, 0.1, 0.42), c2.darkened(0.2), Vector3(0.1 * side, -0.78, 0.4))
		haunch_pivot.add_child(foot)
		r.add_child(haunch_pivot)
		p.legs.append(haunch_pivot)
	for side2 in [-1.0, 1.0]:
		p.legs.append(_leg(r, Vector3(0.3 * side2, 0.6, 0.48), 0.5, 0.14, c1.darkened(0.2), 0.16 * side2, 0.3))
	p.height = 1.5
	p.radius = 0.68

static func _eel(p: Dictionary, c1: Color, c2: Color, gl: Color) -> void:
	var r: Node3D = p.root
	var head := MeshLib.blob(Vector3(0.6, 0.55, 0.8), c1.lightened(0.1), Vector3(0, 0, 0.35))
	r.add_child(head)
	p.head = head
	p.body = head
	_eyes(head, p.glows, Vector3(0, 0.08, 0.22), 0.17, 0.07, _eye_color(gl, c2))
	# The tail is a chain of nodes so the swim is a travelling wave down the body.
	var prev: Node3D = r
	for i in 6:
		var seg_node := Node3D.new()
		seg_node.position = Vector3(0, 0, -0.42) if i > 0 else Vector3(0, 0, -0.1)
		var t := float(i) / 6.0
		var seg := MeshLib.blob(Vector3(0.52 - t * 0.3, 0.48 - t * 0.28, 0.5 - t * 0.2), c1,
			Vector3.ZERO)
		seg_node.add_child(seg)
		var band := MeshLib.glow_dot(0.1 - t * 0.04, _eye_color(gl, c2), Vector3(0, 0.2 - t * 0.1, 0))
		seg_node.add_child(band)
		p.glows.append(band)
		prev.add_child(seg_node)
		p.flex.append(seg_node)
		prev = seg_node
	for side in [-1.0, 1.0]:
		var fin := MeshLib.part(MeshLib.box_mesh(), Vector3(0.5, 0.03, 0.5), c2,
			Vector3(0.32 * side, 0, 0.1), Color(gl.r, gl.g, gl.b, gl.a * 0.5))
		fin.rotation_degrees = Vector3(0, 0, 18 * side)
		r.add_child(fin)
		p.wings.append(fin)
	p.height = 0.7
	p.radius = 0.5

static func _crawler(p: Dictionary, c1: Color, c2: Color, gl: Color) -> void:
	var r: Node3D = p.root
	var body := MeshLib.blob(Vector3(1.1, 0.5, 1.6), c1, Vector3(0, 0.62, 0))
	r.add_child(body)
	p.body = body
	for i in 3:
		var plate := MeshLib.part(MeshLib.hemi_mesh(10, 3), Vector3(0.95 - i * 0.14, 0.5, 0.6),
			c1.darkened(0.25), Vector3(0, 0.74, 0.45 - i * 0.48))
		r.add_child(plate)
	var head := MeshLib.blob(Vector3(0.6, 0.38, 0.5), c1.lightened(0.1), Vector3(0, 0.6, 0.86))
	r.add_child(head)
	p.head = head
	# Four eyes in a cluster: harder to sneak past than two.
	for i in 4:
		var e := MeshLib.glow_dot(0.05, _eye_color(gl, c2),
			Vector3(-0.18 + i * 0.12, 0.06 + (0.05 if i % 2 == 0 else 0.0), 0.2))
		head.add_child(e)
		p.glows.append(e)
	for i in 3:
		var z := 0.5 - i * 0.55
		for side in [-1.0, 1.0]:
			p.legs.append(_arch_leg(r, Vector3(0.42 * side, 0.6, z), 0.55, 0.62, 0.08,
				c1.darkened(0.1), 1.05 * side, 0.0))
	p.height = 1.2
	p.radius = 0.8

static func _toad(p: Dictionary, c1: Color, c2: Color, gl: Color) -> void:
	var r: Node3D = p.root
	var body := MeshLib.blob(Vector3(1.5, 1.15, 1.5), c1, Vector3(0, 0.66, 0))
	r.add_child(body)
	p.body = body
	var head := MeshLib.blob(Vector3(1.1, 0.7, 0.85), c1.lightened(0.06), Vector3(0, 0.72, 0.62))
	r.add_child(head)
	p.head = head
	var mouth := MeshLib.slab(Vector3(0.9, 0.08, 0.1), c1.darkened(0.5), Vector3(0, -0.2, 0.36))
	head.add_child(mouth)
	for side in [-1.0, 1.0]:
		var e := MeshLib.glow_dot(0.13, _eye_color(gl, c2), Vector3(0.3 * side, 0.3, 0.22))
		head.add_child(e)
		p.glows.append(e)
	# The throat sac inflates before it spits. That inflation IS the telegraph.
	var sac := MeshLib.blob(Vector3(0.8, 0.62, 0.7), c2, Vector3(0, 0.36, 0.6),
		Color(gl.r, gl.g, gl.b, gl.a * 0.7))
	r.add_child(sac)
	p.flex.append(sac)
	p.glows.append(sac)
	for side2 in [-1.0, 1.0]:
		var haunch := MeshLib.blob(Vector3(0.6, 0.62, 0.78), c1.darkened(0.15),
			Vector3(0.66 * side2, 0.52, -0.3))
		r.add_child(haunch)
		p.legs.append(haunch)
		p.legs.append(_leg(r, Vector3(0.45 * side2, 0.46, 0.5), 0.42, 0.16, c1.darkened(0.25), 0.2 * side2))
	p.height = 1.5
	p.radius = 0.85

static func _spider(p: Dictionary, c1: Color, c2: Color, gl: Color) -> void:
	var r: Node3D = p.root
	var abdomen := MeshLib.blob(Vector3(1.05, 0.95, 1.15), c1, Vector3(0, 0.82, -0.45))
	r.add_child(abdomen)
	p.body = abdomen
	var pattern := MeshLib.blob(Vector3(0.5, 0.35, 0.7), c2, Vector3(0, 1.12, -0.5),
		Color(gl.r, gl.g, gl.b, gl.a * 0.6))
	r.add_child(pattern)
	p.glows.append(pattern)
	var thorax := MeshLib.blob(Vector3(0.72, 0.6, 0.8), c1.lightened(0.08), Vector3(0, 0.78, 0.32))
	r.add_child(thorax)
	p.head = thorax
	for i in 6:
		var col: float = -0.2 + float(i % 3) * 0.2
		var row: float = 0.02 + floorf(float(i) / 3.0) * 0.12
		var e := MeshLib.glow_dot(0.045, _eye_color(gl, c2), Vector3(col, row, 0.34))
		thorax.add_child(e)
		p.glows.append(e)
	var spinneret := MeshLib.glow_dot(0.12, c2, Vector3(0, 0.72, -1.0))
	r.add_child(spinneret)
	p.glows.append(spinneret)
	for i in 4:
		var yaw := -0.5 + float(i) * 0.36
		for side in [-1.0, 1.0]:
			p.legs.append(_arch_leg(r, Vector3(0.3 * side, 0.84, 0.36 - i * 0.28), 0.62, 0.74, 0.07,
				c1.darkened(0.1), 1.15 * side, yaw * side))
	p.height = 1.4
	p.radius = 0.85

static func _sentinel(p: Dictionary, c1: Color, c2: Color, gl: Color) -> void:
	var r: Node3D = p.root
	var trunk := MeshLib.part(MeshLib.cylinder_mesh(12), Vector3(1.5, 2.3, 1.4), c1,
		Vector3(0, 1.5, 0))
	r.add_child(trunk)
	p.body = trunk
	var chest := MeshLib.glow_dot(0.34, _eye_color(gl, c2), Vector3(0, 1.7, 0.6))
	r.add_child(chest)
	p.glows.append(chest)
	p.flex.append(chest)
	var head := MeshLib.blob(Vector3(0.95, 0.85, 0.95), c1.lightened(0.1), Vector3(0, 2.75, 0.08))
	r.add_child(head)
	p.head = head
	_eyes(head, p.glows, Vector3(0, 0.1, 0.36), 0.24, 0.1, _eye_color(gl, c2))
	# A crown of old growth. Nothing has pruned it in a long time.
	for i in 6:
		var a := TAU * float(i) / 6.0
		var horn := MeshLib.spike(1.1, 0.26, c2, Vector3(sin(a) * 0.5, 3.1, cos(a) * 0.5),
			Color(gl.r, gl.g, gl.b, gl.a * 0.4))
		horn.rotation_degrees = Vector3(cos(a) * 28.0, 0, -sin(a) * 28.0)
		r.add_child(horn)
	for side in [-1.0, 1.0]:
		var arm := _leg(r, Vector3(0.92 * side, 2.2, 0), 1.5, 0.36, c1.darkened(0.15), 0.28 * side)
		p.legs.append(arm)
		for z in [-0.5, 0.55]:
			p.legs.append(_leg(r, Vector3(0.6 * side, 0.9, z), 0.95, 0.32, c1.darkened(0.3), 0.1 * side))
	p.height = 3.6
	p.radius = 1.3
