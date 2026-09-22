extends Node3D
## A travelling ability. Cheap on purpose: no physics body, a short ray against
## the world and a distance check against the other team each frame.

var sys: AbilitySystem
var data: AbilityData
var dir: Vector3 = Vector3.FORWARD
var travelled := 0.0
var _hit_ids: Array = []
var _chains_left := 0
var _mesh: MeshInstance3D

func setup(p_sys: AbilitySystem, p_data: AbilityData, pos: Vector3, p_dir: Vector3) -> void:
	sys = p_sys
	data = p_data
	dir = p_dir.normalized()
	position = pos
	_chains_left = int(p_data.flags.get("chain", 0.0))

func _ready() -> void:
	top_level = true
	_mesh = MeshLib.glow_dot(maxf(data.radius, 0.22), data.color)
	add_child(_mesh)
	if data.shape == "web":
		_mesh.scale *= 1.3
	var trail := MeshLib.glow_dot(maxf(data.radius, 0.2) * 0.6, data.color.lightened(0.3),
		-dir * 0.45)
	add_child(trail)

func _physics_process(delta: float) -> void:
	var step := data.speed * delta
	var from := global_position
	var to := from + dir * step
	travelled += step
	# World geometry stops it. Ability range is the other limit.
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 1
	var res := space.intersect_ray(q)
	if not res.is_empty():
		_impact(res.position)
		return
	global_position = to
	var target := _find_target()
	if target != null:
		_hit(target)
		return
	if travelled >= data.range:
		_impact(global_position)

func _find_target() -> Node3D:
	var reach: float = maxf(data.radius, 0.35) + 0.55
	for e in sys.enemies():
		if not is_instance_valid(e) or e.get("dead") == true or not e.has_method("take_hit"):
			continue
		if _hit_ids.has(e.get_instance_id()):
			continue
		var r: float = reach + float(e.get("body_radius") if e.get("body_radius") != null else 0.5)
		if global_position.distance_to(e.global_position + Vector3.UP * 0.5) <= r:
			return e
	return null

func _hit(target: Node3D) -> void:
	_hit_ids.append(target.get_instance_id())
	target.take_hit(sys._payload(data, target.global_position))
	Fx.burst(global_position, data.color, "spark", 10)
	if data.shape == "web":
		_spawn_web(target.global_position)
		queue_free()
		return
	if _chains_left > 0:
		var next := _nearest_unhit(float(data.flags.get("chain_range", 6.0)))
		if next != null:
			_chains_left -= 1
			_arc_to(next.global_position)
			dir = (next.global_position + Vector3.UP * 0.6 - global_position).normalized()
			travelled = maxf(0.0, travelled - float(data.flags.get("chain_range", 6.0)))
			return
	queue_free()

func _nearest_unhit(radius: float) -> Node3D:
	var best: Node3D = null
	var best_d := radius
	for e in sys.enemies():
		if not is_instance_valid(e) or e.get("dead") == true or not e.has_method("take_hit"):
			continue
		if _hit_ids.has(e.get_instance_id()):
			continue
		var d := global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best

## Draws the jump so a chain reads as one attack finding several bodies.
func _arc_to(target: Vector3) -> void:
	var steps := 5
	for i in steps:
		var t := float(i) / float(steps - 1)
		Fx.burst(global_position.lerp(target + Vector3.UP * 0.6, t), data.color, "spark", 3, 0.6)

func _impact(at: Vector3) -> void:
	global_position = at
	if data.shape == "web":
		_spawn_web(at)
	else:
		Fx.burst(at, data.color, "spark", 8)
		if data.radius > 0.8:
			sys._aoe(data, at, data.radius)
	queue_free()

func _spawn_web(at: Vector3) -> void:
	var web = load("res://abilities/web_field.gd").new()
	web.setup(sys, data, at)
	sys._world().add_child(web)
