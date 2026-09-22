extends Node3D
## Environmental damage. Same Hit payload as everything else, so resistances and
## retaliation behave exactly as they do against a creature.

var kind := "spore_vent"
var radius := 4.0
var _tick := 0.0
var _time := 0.0
var _disc: MeshInstance3D
var _config := {}

const KINDS := {
	"spore_vent": {"status": "poison", "power": 4.0, "time": 3.0, "damage": 2.0,
		"color": Color(0.55, 0.95, 0.4), "fx": "spore", "interval": 0.6},
	"charged_pool": {"status": "shock", "power": 3.0, "time": 2.0, "damage": 3.0,
		"color": Color(0.6, 0.88, 1.0), "fx": "spark", "interval": 0.5},
	"corrupt_pool": {"status": "poison", "power": 6.0, "time": 4.0, "damage": 5.0,
		"color": Color(0.8, 0.3, 0.55), "fx": "venom", "interval": 0.5},
}

func _ready() -> void:
	_config = KINDS.get(kind, KINDS.spore_vent)
	var col: Color = _config.color
	_disc = MeshLib.part(MeshLib.cylinder_mesh(14), Vector3(radius * 2.0, 0.12, radius * 2.0),
		Color(col.r, col.g, col.b, 0.42), Vector3(0, 0.1, 0), Color(col.r, col.g, col.b, 0.8))
	var m: StandardMaterial3D = _disc.material_override.duplicate()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_disc.material_override = m
	_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_disc)
	for i in 5:
		var a := TAU * float(i) / 5.0
		var vent := MeshLib.part(cone(), Vector3(0.7, 0.9, 0.7), col.darkened(0.45),
			Vector3(sin(a) * radius * 0.6, 0.35, cos(a) * radius * 0.6),
			Color(col.r, col.g, col.b, 0.5))
		add_child(vent)

func cone() -> Mesh:
	return MeshLib.cone_mesh(7)

func _physics_process(delta: float) -> void:
	_time += delta
	_tick -= delta
	if _disc != null:
		_disc.scale.y = 0.12 + sin(_time * 2.0) * 0.04
	if randf() < delta * 3.0:
		Fx.burst(global_position + Vector3(randf_range(-radius, radius), 0.2, randf_range(-radius, radius)),
			_config.color, String(_config.fx), 4, 0.7)
	if _tick > 0.0:
		return
	_tick = float(_config.interval)
	var victims: Array = []
	var p := Game.player
	if p != null and is_instance_valid(p):
		victims.append(p)
	for c in get_tree().get_nodes_in_group("creature"):
		victims.append(c)
	for v in victims:
		if not is_instance_valid(v) or v.get("dead") == true:
			continue
		var to: Vector3 = v.global_position - global_position
		to.y *= 0.4
		if to.length() > radius:
			continue
		var h := Hit.make(float(_config.damage), self, "hazard", global_position)
		h.color = _config.color
		h.with_status(String(_config.status), float(_config.power), float(_config.time))
		v.take_hit(h)
