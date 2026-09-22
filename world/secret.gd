extends Node3D
## A hidden cache. Finding one is worth essence and a line from the Echo; the
## end screen counts them, which is most of the reason to come back.

var secret_id := ""
var interact_range := 3.4
var _time := 0.0
var _taken := false
var _core: MeshInstance3D

func _ready() -> void:
	add_to_group("interactable")
	var col := Color(1.0, 0.85, 0.45)
	_core = MeshLib.glow_dot(0.45, col, Vector3(0, 1.1, 0))
	add_child(_core)
	for i in 5:
		var a := TAU * float(i) / 5.0
		var shard := MeshLib.spike(0.9, 0.24, Color(0.4, 0.38, 0.32),
			Vector3(sin(a) * 0.85, 0.45, cos(a) * 0.85), Color(col.r, col.g, col.b, 0.4))
		shard.rotation = Vector3(cos(a) * 0.5, -a, -sin(a) * 0.5)
		add_child(shard)
	var light := OmniLight3D.new()
	light.light_color = col
	light.light_energy = 1.4
	light.omni_range = 9.0
	light.position = Vector3(0, 1.2, 0)
	light.shadow_enabled = false
	add_child(light)

func _process(delta: float) -> void:
	if _taken:
		return
	_time += delta
	_core.position.y = 1.1 + sin(_time * 1.6) * 0.14
	_core.rotation.y += delta * 0.8
	_core.scale = Vector3.ONE * (0.9 + sin(_time * 2.4) * 0.07)

func interact_prompt() -> String:
	return "TAKE"

func interact(_player: Node) -> void:
	if _taken:
		return
	_taken = true
	remove_from_group("interactable")
	Game.note_secret(secret_id)
	Audio.play("secret", -2.0)
	Fx.burst(global_position + Vector3.UP, Color(1.0, 0.85, 0.45), "dissolve", 22, 1.2)
	Fx.ring_flash(global_position, 4.0, Color(1.0, 0.85, 0.45), 0.5)
	Sig.echo_analysis.emit(["CACHE OPENED", "RESIDUAL ESSENCE RECOVERED"])
	Sig.toast.emit("HIDDEN CACHE FOUND", Color(1.0, 0.85, 0.45))
	var t := create_tween()
	t.tween_property(_core, "scale", Vector3.ONE * 0.01, 0.4)
	t.tween_callback(queue_free)
