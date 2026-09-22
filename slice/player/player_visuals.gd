extends Node3D
class_name PlayerVisuals
## The Wisp's body. Rebuilt from the loadout, so equipping a trait is the same
## action as growing the organ: there is no separate "show mutation" step.

const MUTATIONS := ["plates", "veins", "heat_core", "haunches", "antennae",
	"sacs", "arcs", "smoke", "bladder", "spinnerets"]

var body: MeshInstance3D
var core: MeshInstance3D
var lantern: OmniLight3D
var shell: Node3D              ## holds mutation geometry, cleared on rebuild
var _mat: ShaderMaterial
var _base_tint := Color(0.45, 0.85, 0.95)
var _rim := Color(0.6, 1.0, 1.0)
var _stretch := Vector3.ONE
var _stretch_target := Vector3.ONE
var _charge := 0.0
var _flash := 0.0
var _flash_color := Color.WHITE
var _time := 0.0
var _arc_timer := 0.0
var _has_arcs := false
var _has_smoke := false
var _motes: Array[MeshInstance3D] = []
var _scale_base := 1.0
var _cam_scale := 1.0

func _ready() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/wisp.gdshader")
	body = MeshInstance3D.new()
	body.mesh = MeshLib.sphere_mesh(16, 9)
	body.material_override = _mat
	body.scale = Vector3(1.05, 0.98, 1.05)
	body.position = Vector3(0, 0.6, 0)
	add_child(body)
	core = MeshLib.glow_dot(0.17, Palette.CORE, Vector3(0, 0.6, 0))
	add_child(core)
	shell = Node3D.new()
	add_child(shell)
	# It is a glowing organism in a dark cave, so it carries its own light.
	# This is most of what makes the Hollow readable without flooding it.
	lantern = OmniLight3D.new()
	lantern.light_energy = 2.4
	lantern.omni_range = 15.0
	lantern.omni_attenuation = 0.85
	lantern.shadow_enabled = false
	lantern.position = Vector3(0, 0.9, 0)
	add_child(lantern)
	_apply_shader()

# --- rebuild ------------------------------------------------------------------

func rebuild(mutations: Array, evolution: String) -> void:
	for c in shell.get_children():
		c.queue_free()
	_has_arcs = false
	_has_smoke = false
	_motes.clear()
	_apply_evolution(evolution)
	for m in mutations:
		_add_mutation(String(m))
	_apply_shader()
	body.scale = Vector3(1.05, 0.98, 1.05) * _scale_base
	core.scale = Vector3.ONE * 0.34 * _scale_base

func _apply_evolution(evolution: String) -> void:
	_scale_base = 1.0
	match evolution:
		"predator":
			_base_tint = Color(0.85, 0.35, 0.38)
			_rim = Color(1.0, 0.55, 0.45)
			_scale_base = 1.08
			for i in 5:
				var a := TAU * float(i) / 5.0
				var fin := MeshLib.spike(0.55, 0.18, Color(0.9, 0.4, 0.4),
					Vector3(sin(a) * 0.36, 0.95, cos(a) * 0.36), Color(1.0, 0.5, 0.4, 0.8))
				fin.rotation_degrees = Vector3(cos(a) * 26.0, 0, -sin(a) * 26.0)
				shell.add_child(fin)
		"arcane":
			_base_tint = Color(0.45, 0.58, 0.95)
			_rim = Color(0.7, 0.85, 1.0)
			_scale_base = 1.02
			for i in 4:
				var mote := MeshLib.glow_dot(0.07, Color(0.75, 0.9, 1.0))
				shell.add_child(mote)
				_motes.append(mote)
			core.scale = Vector3.ONE * 0.5
		"bulwark":
			_base_tint = Color(0.85, 0.72, 0.42)
			_rim = Color(1.0, 0.88, 0.55)
			_scale_base = 1.18
			for i in 6:
				var a2 := TAU * float(i) / 6.0
				var band := MeshLib.part(MeshLib.box_mesh(), Vector3(0.26, 0.08, 0.5),
					Color(0.72, 0.6, 0.35), Vector3(sin(a2) * 0.52, 0.6, cos(a2) * 0.52),
					Color(1.0, 0.85, 0.5, 0.35))
				band.rotation.y = -a2
				shell.add_child(band)
		_:
			_base_tint = Color(0.45, 0.85, 0.95)
			_rim = Color(0.6, 1.0, 1.0)

func _add_mutation(id: String) -> void:
	var t := DB.get_trait(_trait_for_mutation(id))
	var col: Color = t.color if t != null else Color.WHITE
	match id:
		"plates":
			# Overlapping shells. They visibly sit ON the membrane, not in it.
			for i in 5:
				var a := TAU * float(i) / 5.0 + 0.3
				var plate := MeshLib.part(MeshLib.hemi_mesh(10, 3), Vector3(0.62, 0.42, 0.62),
					col.darkened(0.15), Vector3(sin(a) * 0.36, 0.62 + cos(a * 2.0) * 0.1, cos(a) * 0.36))
				plate.rotation = Vector3(cos(a) * 0.9, -a, -sin(a) * 0.9)
				shell.add_child(plate)
			var cap := MeshLib.part(MeshLib.hemi_mesh(12, 4), Vector3(0.9, 0.5, 0.9),
				col, Vector3(0, 0.82, 0))
			shell.add_child(cap)
		"veins":
			for i in 7:
				var a2 := TAU * float(i) / 7.0
				var vein := MeshLib.part(MeshLib.box_mesh(), Vector3(0.05, 0.05, 0.95),
					col, Vector3(sin(a2) * 0.46, 0.6 + sin(a2 * 3.0) * 0.14, cos(a2) * 0.46),
					Color(col.r, col.g, col.b, 0.9))
				vein.rotation = Vector3(0.5, -a2, 0.4)
				shell.add_child(vein)
		"heat_core":
			var furnace := MeshLib.glow_dot(0.3, Color(1.0, 0.5, 0.15), Vector3(0, 0.58, 0))
			shell.add_child(furnace)
			_base_tint = _base_tint.lerp(Color(1.0, 0.6, 0.3), 0.3)
			_rim = _rim.lerp(Color(1.0, 0.55, 0.2), 0.4)
		"haunches":
			for side in [-1.0, 1.0]:
				var haunch := MeshLib.blob(Vector3(0.44, 0.56, 0.6), col.darkened(0.1),
					Vector3(0.38 * side, 0.52, -0.3))
				shell.add_child(haunch)
				var shin := MeshLib.limb(0.6, 0.16, col.darkened(0.3), Vector3(0.44 * side, 0.18, -0.12))
				shin.rotation_degrees = Vector3(34, 0, 0)
				shell.add_child(shin)
				var foot := MeshLib.slab(Vector3(0.2, 0.09, 0.36), col.darkened(0.35),
					Vector3(0.46 * side, -0.05, 0.12))
				shell.add_child(foot)
		"antennae":
			for side2 in [-1.0, 1.0]:
				var stalk := MeshLib.limb(0.56, 0.05, col, Vector3(0.16 * side2, 1.08, 0.08))
				stalk.rotation_degrees = Vector3(-24, 0, 22 * side2)
				shell.add_child(stalk)
				var tip := MeshLib.glow_dot(0.07, col, Vector3(0.32 * side2, 1.38, 0.18))
				shell.add_child(tip)
		"sacs":
			for i in 3:
				var a3 := TAU * float(i) / 3.0 + 0.6
				var sac := MeshLib.blob(Vector3(0.34, 0.38, 0.34), Color(col.r, col.g, col.b, 0.75),
					Vector3(sin(a3) * 0.46, 0.5, cos(a3) * 0.46), Color(col.r, col.g, col.b, 0.7))
				shell.add_child(sac)
		"arcs":
			_has_arcs = true
			for i in 4:
				var a4 := TAU * float(i) / 4.0
				var node := MeshLib.glow_dot(0.06, col, Vector3(sin(a4) * 0.52, 0.72, cos(a4) * 0.52))
				shell.add_child(node)
		"smoke":
			_has_smoke = true
			for i in 3:
				var wisp := MeshLib.blob(Vector3(0.5, 0.36, 0.5), Color(col.r, col.g, col.b, 0.3),
					Vector3(0, 0.34 - i * 0.06, -0.32 - i * 0.16), Color(col.r, col.g, col.b, 0.25))
				wisp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				shell.add_child(wisp)
		"bladder":
			var sac2 := MeshLib.blob(Vector3(0.78, 0.6, 0.72), Color(col.r, col.g, col.b, 0.8),
				Vector3(0, 0.32, 0.18), Color(col.r, col.g, col.b, 0.45))
			shell.add_child(sac2)
			var valve := MeshLib.glow_dot(0.08, col.lightened(0.3), Vector3(0, 0.28, 0.52))
			shell.add_child(valve)
		"spinnerets":
			for i in 3:
				var x := -0.16 + i * 0.16
				var sp := MeshLib.spike(0.2, 0.09, col, Vector3(x, 0.44, -0.52))
				sp.rotation_degrees = Vector3(108, 0, 0)
				shell.add_child(sp)

func _trait_for_mutation(mutation: String) -> String:
	for id in DB.traits.keys():
		if DB.traits[id].visual_mutation == mutation:
			return id
	return ""

func _apply_shader() -> void:
	_mat.set_shader_parameter("tint", _base_tint)
	_mat.set_shader_parameter("rim", _rim)
	_mat.set_shader_parameter("alpha", 0.8)
	_mat.set_shader_parameter("smoke", 0.45 if _has_smoke else 0.0)
	core.material_override = MeshLib.mat(_rim, Color(_rim.r, _rim.g, _rim.b, 1.0), 0.4, 0.0, true)
	if lantern != null:
		lantern.light_color = _rim.lerp(Color.WHITE, 0.25)

# --- live feel ----------------------------------------------------------------

func set_charge(v: float) -> void:
	_charge = clampf(v, 0.0, 1.0)

## When the camera is forced right up against the body - a wall behind, a
## corner, a low ceiling - the body would otherwise swallow the screen or
## vanish through the near plane. Shrinking it keeps the player looking at
## their own creature instead of the inside of it.
func set_camera_proximity(arm_length: float) -> void:
	var near := clampf(inverse_lerp(0.6, 2.2, arm_length), 0.0, 1.0)
	_cam_scale = lerpf(0.34, 1.0, near)
	if lantern != null:
		lantern.light_energy = lerpf(3.4, 2.4, near)

func flash(color: Color) -> void:
	_flash = 1.0
	_flash_color = color

## Squash on landing, stretch on launch: the body is liquid, so it should read
## as one that is being thrown around.
func impulse_stretch(vertical: float, horizontal: float) -> void:
	var m := float(Settings.get_value("motion_intensity"))
	_stretch_target = Vector3(
		1.0 - vertical * 0.22 * m + horizontal * 0.08 * m,
		1.0 + vertical * 0.3 * m,
		1.0 - vertical * 0.22 * m + horizontal * 0.08 * m)

func _process(delta: float) -> void:
	_time += delta
	_stretch_target = _stretch_target.lerp(Vector3.ONE, clampf(delta * 6.0, 0.0, 1.0))
	_stretch = _stretch.lerp(_stretch_target, clampf(delta * 14.0, 0.0, 1.0))
	var breathe := 1.0 + sin(_time * 2.4) * 0.018
	body.scale = Vector3(1.05, 0.98, 1.05) * _scale_base * _cam_scale * _stretch * breathe
	shell.scale = _stretch * _cam_scale
	core.position.y = 0.6 + sin(_time * 1.7) * 0.03
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 4.0)
		_mat.set_shader_parameter("tint", _base_tint.lerp(_flash_color, _flash))
		_mat.set_shader_parameter("charge", maxf(_charge, _flash))
	else:
		_mat.set_shader_parameter("tint", _base_tint)
		_mat.set_shader_parameter("charge", _charge)
	for i in _motes.size():
		var a := _time * 1.6 + TAU * float(i) / float(_motes.size())
		_motes[i].position = Vector3(sin(a) * 0.72, 0.6 + sin(a * 2.2) * 0.22, cos(a) * 0.72)
	if lantern != null:
		lantern.light_energy = 2.3 + sin(_time * 1.9) * 0.22 + _charge * 1.6 + _flash * 2.5
	if _has_arcs:
		_arc_timer -= delta
		if _arc_timer <= 0.0:
			_arc_timer = randf_range(0.35, 1.1)
			Fx.burst(global_position + Vector3(randf_range(-0.4, 0.4), 0.7, randf_range(-0.4, 0.4)),
				Color(0.65, 0.9, 1.0), "spark", 4, 0.5)
