extends Node3D
class_name CreatureVisuals
## Procedural animation for whatever ProcCreature built. There are no clips:
## legs swing from speed, wings flap from a phase, throats inflate from windup,
## and a hit is a squash plus a flash.

var parts: Dictionary
var data: CreatureData
var phase := 0.0
var _flash := 0.0
var _flash_color := Color.WHITE
var _squash := Vector3.ONE
var _squash_target := Vector3.ONE
var _windup := 0.0
var _base_y := 0.0
var _mats: Dictionary = {}       ## per-instance materials, for flashing

func setup(p_parts: Dictionary, p_data: CreatureData) -> void:
	parts = p_parts
	data = p_data
	add_child(parts.root)
	phase = randf() * TAU
	_collect_materials(parts.root)

func _collect_materials(n: Node) -> void:
	if n is MeshInstance3D and n.material_override != null:
		# Materials are shared and cached, so flashing needs a private copy.
		var m: StandardMaterial3D = n.material_override.duplicate()
		n.material_override = m
		_mats[n] = {"mat": m, "albedo": m.albedo_color, "emission": m.emission,
			"energy": m.emission_energy_multiplier}
	for c in n.get_children():
		_collect_materials(c)

func flash(color: Color, strength := 1.0) -> void:
	_flash = strength
	_flash_color = color

func squash(vertical: float) -> void:
	_squash_target = Vector3(1.0 - vertical * 0.25, 1.0 + vertical * 0.3, 1.0 - vertical * 0.25)

## Drives the tell for an incoming attack: the body coils, and on creatures with
## an inflatable part (the toad's throat) that part swells instead.
func set_windup(v: float) -> void:
	_windup = clampf(v, 0.0, 1.0)

func animate(delta: float, speed_frac: float, grounded: bool) -> void:
	phase += delta * (3.0 + speed_frac * 9.0)
	var moving := speed_frac > 0.06
	var legs: Array = parts.legs
	for i in legs.size():
		var leg: Node3D = legs[i]
		if not is_instance_valid(leg):
			continue
		var off := float(i) * 1.7
		var swing: float = sin(phase + off) * (0.42 * speed_frac + 0.04)
		leg.rotation.x = swing
		if not moving:
			leg.rotation.x = lerpf(leg.rotation.x, sin(phase * 0.4 + off) * 0.05, 0.4)
	for i in parts.wings.size():
		var w: Node3D = parts.wings[i]
		if not is_instance_valid(w):
			continue
		var flap := sin(phase * 2.4 + float(i) * PI) * (0.5 if data.flies else 0.18)
		w.rotation.z = flap * (1.0 if i == 0 else -1.0)
	for i in parts.flex.size():
		var f: Node3D = parts.flex[i]
		if not is_instance_valid(f):
			continue
		if data.body_plan == "eel":
			f.rotation.y = sin(phase * 1.1 - float(i) * 0.7) * 0.28
		elif data.body_plan == "toad" and i == 0:
			f.scale = Vector3.ONE * (1.0 + _windup * 0.7)
		else:
			f.position.y += sin(phase * 0.9 + float(i)) * delta * 0.15
			f.scale = Vector3.ONE * (1.0 + sin(phase * 1.4 + float(i)) * 0.06 + _windup * 0.25)
	var body: Node3D = parts.body
	if is_instance_valid(body):
		var bob := sin(phase * 1.0) * (0.035 + speed_frac * 0.05)
		body.position.y = lerpf(body.position.y, body.position.y, 0.0)
		body.rotation.z = sin(phase * 0.5) * 0.03 * speed_frac
		body.rotation.x = -_windup * 0.28 + bob * 0.2
	_squash_target = _squash_target.lerp(Vector3.ONE, clampf(delta * 5.0, 0.0, 1.0))
	_squash = _squash.lerp(_squash_target, clampf(delta * 13.0, 0.0, 1.0))
	var coil := Vector3(1.0 + _windup * 0.12, 1.0 - _windup * 0.16, 1.0 + _windup * 0.12)
	parts.root.scale = Vector3.ONE * data.body_scale * _squash * coil
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 5.0)
		_apply_flash()

func _apply_flash() -> void:
	for n in _mats.keys():
		if not is_instance_valid(n):
			continue
		var e: Dictionary = _mats[n]
		var m: StandardMaterial3D = e.mat
		m.albedo_color = Color(e.albedo).lerp(_flash_color, _flash * 0.85)
		m.emission_enabled = true
		m.emission = Color(e.emission).lerp(_flash_color, _flash)
		m.emission_energy_multiplier = float(e.energy) + _flash * 3.0

## Ambushers fade until they commit, which is the only warning you get.
func set_hidden(amount: float) -> void:
	for n in _mats.keys():
		if not is_instance_valid(n):
			continue
		n.transparency = clampf(amount, 0.0, 0.92)
