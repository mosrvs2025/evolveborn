extends Node3D
## A sustained cone that keeps pointing where its owner points. Flame Breath is
## this; the single-shot Flame Burst is the same ability row without `sustained`.

var sys: AbilitySystem
var data: AbilityData
var aim: Vector3
var life := 0.0
var _tick := 0.0
var _flame: Node3D

func setup(p_sys: AbilitySystem, p_data: AbilityData, p_aim: Vector3) -> void:
	sys = p_sys
	data = p_data
	aim = p_aim

func _ready() -> void:
	life = data.duration
	_flame = Node3D.new()
	add_child(_flame)
	Audio.play_at("flame_long", sys.actor.global_position, -3.0)

func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0 or not is_instance_valid(sys.actor):
		queue_free()
		return
	# Follow the owner's current facing, so the stream is aimed, not fired.
	if sys.actor.has_method("aim_direction"):
		aim = aim.slerp(sys.actor.aim_direction(), clampf(delta * 6.0, 0.0, 1.0)).normalized()
	var origin: Vector3 = sys.actor.global_position + Vector3.UP * 0.6
	_tick -= delta
	if _tick <= 0.0:
		_tick = float(data.flags.get("tick", 0.2))
		sys._cone_tick(data, origin, aim, 1.0)
		Fx.shake(0.06)
	for i in 2:
		var t := randf()
		Fx.burst(origin + aim * data.range * t + Vector3(randf_range(-0.4, 0.4), randf_range(-0.2, 0.4), randf_range(-0.4, 0.4)),
			data.color, "ember", 4, 0.7 + t * 1.2)
