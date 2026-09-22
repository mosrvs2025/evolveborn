extends Node
## Feedback layer: particles, damage numbers, hit stop, camera trauma, flashes.
## Everything is pooled and everything respects the accessibility settings, so a
## player who turned motion down still gets the information, just quieter.

const PARTICLE_POOL := 22
const LABEL_POOL := 14
const DECAL_POOL := 10

var shake_trauma := 0.0          ## camera rig reads and decays this
var _particles: Array[CPUParticles3D] = []
var _labels: Array[Label3D] = []
var _decals: Array[MeshInstance3D] = []
var _hitstop_until := 0.0
var _world: Node = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in PARTICLE_POOL:
		var p := CPUParticles3D.new()
		p.emitting = false
		p.one_shot = true
		p.local_coords = false
		p.top_level = true
		add_child(p)
		_particles.append(p)
	for i in LABEL_POOL:
		var l := Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.fixed_size = true
		l.font_size = 48
		l.outline_size = 14
		l.outline_modulate = Color(0, 0, 0, 0.8)
		l.visible = false
		l.top_level = true
		add_child(l)
		_labels.append(l)
	for i in DECAL_POOL:
		var d := MeshLib.ring(1.0, Color.WHITE)
		var dm := StandardMaterial3D.new()
		dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		dm.cull_mode = BaseMaterial3D.CULL_DISABLED
		dm.emission_enabled = true
		dm.emission_energy_multiplier = 1.8
		d.material_override = dm
		d.visible = false
		d.top_level = true
		add_child(d)
		_decals.append(d)

func _process(_delta: float) -> void:
	if _hitstop_until > 0.0 and Time.get_ticks_msec() / 1000.0 >= _hitstop_until:
		_hitstop_until = 0.0
		Engine.time_scale = 1.0

# --- camera / time ------------------------------------------------------------

func shake(amount: float) -> void:
	var s := float(Settings.get_value("screen_shake"))
	shake_trauma = minf(shake_trauma + amount * s, 1.0)

func hit_stop(seconds := 0.06) -> void:
	if not bool(Settings.get_value("hit_stop")):
		return
	Engine.time_scale = 0.04
	_hitstop_until = Time.get_ticks_msec() / 1000.0 + seconds

# --- particles ----------------------------------------------------------------

func _take_particles() -> CPUParticles3D:
	for p in _particles:
		if not p.emitting:
			return p
	return _particles[0]

## kind: impact | ember | spark | venom | smoke | dissolve | heal | dust | quake
func burst(pos: Vector3, color: Color, kind := "impact", amount := 14, scale := 1.0) -> void:
	var q := Settings.fx_scale()
	var count := int(maxf(3.0, amount * q))
	var p := _take_particles()
	p.emitting = false
	p.global_position = pos
	p.amount = count
	p.lifetime = 0.55
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 45.0
	p.gravity = Vector3(0, -9.0, 0)
	p.initial_velocity_min = 3.0 * scale
	p.initial_velocity_max = 7.0 * scale
	p.scale_amount_min = 0.12 * scale
	p.scale_amount_max = 0.26 * scale
	p.damping_min = 1.0
	p.damping_max = 3.0
	p.mesh = MeshLib.sphere_mesh(6, 3)
	p.material_override = MeshLib.mat(color, Color(color.r, color.g, color.b, 1.0), 0.6, 0.0, true)
	match kind:
		"ember", "spark":
			p.gravity = Vector3(0, -2.0, 0)
			p.lifetime = 0.75
			p.initial_velocity_max = 10.0 * scale
			p.scale_amount_max = 0.16 * scale
		"venom", "spore":
			p.gravity = Vector3(0, -1.2, 0)
			p.lifetime = 1.3
			p.spread = 180.0
			p.initial_velocity_min = 1.0
			p.initial_velocity_max = 3.5 * scale
		"smoke":
			p.gravity = Vector3(0, 1.4, 0)
			p.lifetime = 1.1
			p.spread = 90.0
			p.initial_velocity_max = 2.5 * scale
			p.scale_amount_max = 0.5 * scale
		"dissolve":
			p.gravity = Vector3(0, 2.2, 0)
			p.lifetime = 0.9
			p.spread = 180.0
			p.initial_velocity_min = 0.5
			p.initial_velocity_max = 2.0
		"heal":
			p.gravity = Vector3(0, 3.0, 0)
			p.lifetime = 0.9
			p.spread = 30.0
			p.initial_velocity_max = 3.0
		"dust", "quake":
			p.gravity = Vector3(0, -3.0, 0)
			p.direction = Vector3.UP
			p.spread = 70.0
			p.lifetime = 0.9
			p.scale_amount_max = 0.42 * scale
	p.restart()
	p.emitting = true

## Energy being pulled toward a point. The Devour effect is built from this.
func suck(from: Vector3, toward: Vector3, color: Color, amount := 10) -> void:
	var p := _take_particles()
	var dir := (toward - from)
	var dist := maxf(dir.length(), 0.5)
	p.emitting = false
	p.global_position = from
	p.amount = int(maxf(3.0, amount * Settings.fx_scale()))
	p.lifetime = clampf(dist / 9.0, 0.22, 0.7)
	p.explosiveness = 0.75
	p.direction = dir.normalized()
	p.spread = 22.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = dist / p.lifetime * 0.8
	p.initial_velocity_max = dist / p.lifetime * 1.2
	p.scale_amount_min = 0.09
	p.scale_amount_max = 0.2
	p.damping_min = 0.0
	p.damping_max = 0.0
	p.mesh = MeshLib.sphere_mesh(6, 3)
	p.material_override = MeshLib.mat(color, Color(color.r, color.g, color.b, 1.0), 0.6, 0.0, true)
	p.restart()
	p.emitting = true

# --- ground decals / telegraphs ----------------------------------------------

func _take_decal() -> MeshInstance3D:
	for d in _decals:
		if not d.visible:
			return d
	return _decals[0]

## A ring that expands and fades; the readable half of every impact.
func ring_flash(pos: Vector3, radius: float, color: Color, seconds := 0.35) -> void:
	var d := _take_decal()
	var m: StandardMaterial3D = d.material_override
	d.visible = true
	d.global_position = pos + Vector3(0, 0.08, 0)
	d.scale = Vector3.ONE * radius * 0.7
	m.albedo_color = Color(color.r, color.g, color.b, 0.85)
	m.emission = Color(color.r, color.g, color.b)
	var t := create_tween().set_parallel(true)
	t.tween_property(d, "scale", Vector3.ONE * radius * 2.0, seconds).set_ease(Tween.EASE_OUT)
	t.tween_property(m, "albedo_color:a", 0.0, seconds)
	t.chain().tween_callback(func(): d.visible = false)

## A telegraph that grows to full size over its windup, so the danger is the
## same shape as the attack that follows it.
func telegraph(pos: Vector3, radius: float, color: Color, windup: float) -> MeshInstance3D:
	var d := _take_decal()
	var m: StandardMaterial3D = d.material_override
	d.visible = true
	d.global_position = pos + Vector3(0, 0.06, 0)
	d.scale = Vector3.ONE * radius * 1.98
	m.albedo_color = Color(color.r, color.g, color.b, 0.25)
	m.emission = Color(color.r, color.g, color.b)
	var t := create_tween()
	t.tween_property(m, "albedo_color:a", 0.85, maxf(windup, 0.05))
	t.tween_callback(func(): d.visible = false)
	return d

# --- damage numbers -----------------------------------------------------------

func damage_number(pos: Vector3, amount: float, color: Color, big := false) -> void:
	if not bool(Settings.get_value("damage_numbers")):
		return
	for l in _labels:
		if l.visible:
			continue
		l.text = str(int(round(amount)))
		l.modulate = color
		l.font_size = 64 if big else 42
		l.outline_size = 18 if big else 12
		l.global_position = pos + Vector3(randf_range(-0.3, 0.3), 0.4, randf_range(-0.3, 0.3))
		l.visible = true
		var motion := float(Settings.get_value("motion_intensity"))
		var t := create_tween().set_parallel(true)
		t.tween_property(l, "global_position", l.global_position + Vector3(0, 1.4 * motion + 0.4, 0), 0.75)
		t.tween_property(l, "modulate:a", 0.0, 0.75).set_delay(0.2)
		t.chain().tween_callback(func(): l.visible = false)
		return

func floating_text(pos: Vector3, text: String, color: Color) -> void:
	for l in _labels:
		if l.visible:
			continue
		l.text = text
		l.modulate = color
		l.font_size = 38
		l.outline_size = 12
		l.global_position = pos + Vector3(0, 0.6, 0)
		l.visible = true
		var t := create_tween().set_parallel(true)
		t.tween_property(l, "global_position", l.global_position + Vector3(0, 1.1, 0), 1.1)
		t.tween_property(l, "modulate:a", 0.0, 1.1).set_delay(0.45)
		t.chain().tween_callback(func(): l.visible = false)
		return
