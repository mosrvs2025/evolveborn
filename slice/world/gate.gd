extends Node3D
## The way on. A deliberate step rather than a trigger volume, so nobody falls
## into the next region by accident while fighting next to it.

var to_region := ""
var interact_range := 4.5
var _time := 0.0
var _veil: MeshInstance3D

func _ready() -> void:
	add_to_group("interactable")
	var col := Color(0.6, 0.85, 1.0)
	for side in [-1.0, 1.0]:
		var post := MeshLib.part(MeshLib.cylinder_mesh(9), Vector3(0.9, 6.0, 0.9),
			Color(0.3, 0.32, 0.36), Vector3(2.6 * side, 3.0, 0))
		add_child(post)
		for i in 3:
			var glyph := MeshLib.glow_dot(0.18, col, Vector3(2.6 * side, 1.5 + i * 1.6, 0.5))
			add_child(glyph)
	var lintel := MeshLib.part(MeshLib.box_mesh(), Vector3(6.6, 0.8, 1.2),
		Color(0.32, 0.34, 0.38), Vector3(0, 6.2, 0))
	add_child(lintel)
	_veil = MeshLib.part(MeshLib.quad_mesh(Vector2(5.0, 5.8)), Vector3.ONE,
		Color(col.r, col.g, col.b, 0.22), Vector3(0, 3.0, 0), Color(col.r, col.g, col.b, 0.6))
	var m: StandardMaterial3D = _veil.material_override.duplicate()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_veil.material_override = m
	_veil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_veil)
	var light := OmniLight3D.new()
	light.light_color = col
	light.light_energy = 1.6
	light.omni_range = 14.0
	light.position = Vector3(0, 3.0, 0)
	add_child(light)

func _process(delta: float) -> void:
	_time += delta
	if _veil != null:
		_veil.scale = Vector3(1.0 + sin(_time * 1.4) * 0.02, 1.0 + cos(_time * 1.1) * 0.02, 1.0)

func interact_prompt() -> String:
	return "ENTER " + Layouts.display_name(to_region).to_upper()

func interact(_player: Node) -> void:
	Audio.play("gate", -2.0)
	Sig.request_state.emit("travel", {"to": to_region})
