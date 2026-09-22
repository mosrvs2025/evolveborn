extends Node3D
## Silk on the ground. It holds whatever stands in it, and if the body that
## produced it also carries a charge, the strands carry the charge too.

var sys: AbilitySystem
var data: AbilityData
var life := 0.0
var _tick := 0.0
var _strands: Node3D

func setup(p_sys: AbilitySystem, p_data: AbilityData, pos: Vector3) -> void:
	sys = p_sys
	data = p_data
	position = pos

func _ready() -> void:
	top_level = true
	life = data.duration
	_strands = Node3D.new()
	add_child(_strands)
	var electrified := bool(data.flags.get("electrified", false))
	var col: Color = data.color
	var pad := MeshLib.ring(data.radius, col, 0.06)
	_strands.add_child(pad)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(position.x * 31.0) + int(position.z * 17.0)
	for i in 9:
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.2, 1.0) * data.radius
		var strand := MeshLib.part(MeshLib.box_mesh(),
			Vector3(0.03, 0.03, data.radius * rng.randf_range(0.8, 1.6)), col,
			Vector3(sin(a) * r * 0.4, 0.12, cos(a) * r * 0.4),
			Color(col.r, col.g, col.b, 0.9 if electrified else 0.35))
		strand.rotation.y = rng.randf() * TAU
		strand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_strands.add_child(strand)
	Audio.play_at("web", position, -4.0)

func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	_tick -= delta
	var interval := float(data.flags.get("tick", 0.45))
	var electrified := bool(data.flags.get("electrified", false))
	for e in sys.enemies():
		if not is_instance_valid(e) or e.get("dead") == true or not e.has_method("take_hit"):
			continue
		var to: Vector3 = e.global_position - global_position
		to.y *= 0.4
		if to.length() > data.radius:
			continue
		if e.has_method("apply_status"):
			e.apply_status("root", 1.0, 0.25)
		if _tick <= 0.0:
			var h := sys._payload(data, e.global_position, sys.dmg(data) * (1.0 if electrified else 0.4))
			h.knockback = 0.0
			e.take_hit(h)
	if _tick <= 0.0:
		_tick = interval
		if electrified:
			Fx.burst(global_position + Vector3.UP * 0.3, data.color, "spark", 6, 1.2)
