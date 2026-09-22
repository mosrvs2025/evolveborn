extends Node3D
## Checkpoint, infirmary, workshop and the only place the body can be rebuilt
## mid-region. Recognisable on sight: a lit pool inside a ring of crystal.

var pool_id := ""
var interact_range := 4.0
var _time := 0.0
var _surface: MeshInstance3D
var _light: OmniLight3D
var _activated := false

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("memory_pool")
	var col := Palette.CORE
	var basin := MeshLib.part(MeshLib.cylinder_mesh(16), Vector3(6.4, 0.45, 6.4),
		Color(0.16, 0.2, 0.24), Vector3(0, 0.05, 0))
	add_child(basin)
	_surface = MeshLib.part(MeshLib.cylinder_mesh(16), Vector3(5.6, 0.16, 5.6),
		Color(col.r, col.g, col.b, 0.5), Vector3(0, 0.3, 0), Color(col.r * 0.5, col.g * 0.5, col.b * 0.5, 1.0))
	var sm: StandardMaterial3D = _surface.material_override.duplicate()
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_surface.material_override = sm
	_surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_surface)
	for i in 7:
		var a := TAU * float(i) / 7.0
		var shard := MeshLib.spike(1.6 + sin(a * 3.0) * 0.5, 0.42, Color(0.55, 0.75, 0.85),
			Vector3(sin(a) * 3.3, 0.7, cos(a) * 3.3), Color(col.r, col.g, col.b, 0.5))
		shard.rotation = Vector3(cos(a) * 0.22, -a, -sin(a) * 0.22)
		add_child(shard)
	_light = OmniLight3D.new()
	_light.light_color = col
	_light.light_energy = 1.6
	_light.omni_range = 16.0
	_light.position = Vector3(0, 2.0, 0)
	_light.shadow_enabled = false
	add_child(_light)

func _process(delta: float) -> void:
	_time += delta
	if _surface != null:
		_surface.position.y = 0.3 + sin(_time * 1.2) * 0.05
		_surface.scale = Vector3(5.6 + sin(_time * 0.8) * 0.08, 0.16, 5.6 + cos(_time * 0.9) * 0.08)
	if _light != null:
		_light.light_energy = 1.5 + sin(_time * 1.7) * 0.3
	if randf() < delta * 2.0:
		Fx.burst(global_position + Vector3(randf_range(-2.2, 2.2), 0.4, randf_range(-2.2, 2.2)),
			Palette.CORE, "heal", 3, 0.5)

func interact_prompt() -> String:
	return "MEMORY POOL"

func interact(player: Node) -> void:
	if player.has_method("full_heal"):
		player.full_heal()
	Game.set_checkpoint(pool_id)
	Game.echo("first_pool")
	Audio.play("pool", -3.0)
	Fx.ring_flash(global_position, 6.0, Palette.CORE, 0.7)
	Fx.burst(global_position + Vector3.UP * 0.6, Palette.CORE, "heal", 24, 1.2)
	_activated = true
	Sig.request_state.emit("pool", {"pool": pool_id})
