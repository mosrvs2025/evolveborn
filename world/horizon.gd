extends Node3D
## The last shot. A cliff at the edge of the Hollow and the whole rest of the
## world behind it, built out of the same primitives as everything else and
## deliberately too far away to analyse.

var wisp: Node3D
var cam: Camera3D
var _time := 0.0
var _flyers: Array[Node3D] = []
var _smoke_points: Array[Vector3] = []

func _ready() -> void:
	_build_sky()
	_build_cliff()
	_build_distance()
	_build_player()
	_build_camera()
	Audio.play_music("ending", 2.5)

func _build_sky() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var mat := ProceduralSkyMaterial.new()
	mat.sky_top_color = Color(0.22, 0.34, 0.56)
	mat.sky_horizon_color = Color(0.86, 0.72, 0.58)
	mat.ground_horizon_color = Color(0.72, 0.64, 0.56)
	mat.ground_bottom_color = Color(0.3, 0.32, 0.3)
	mat.sun_angle_max = 22.0
	mat.sun_curve = 0.12
	sky.sky_material = mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.1
	env.fog_enabled = true
	env.fog_light_color = Color(0.68, 0.72, 0.82)
	env.fog_density = 0.0035
	env.fog_sky_affect = 0.2
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.86, 0.68)
	sun.light_energy = 1.5
	sun.rotation_degrees = Vector3(-14, 152, 0)
	sun.shadow_enabled = Settings.shadows_enabled()
	add_child(sun)

func _build_cliff() -> void:
	var rock := Color(0.28, 0.27, 0.26)
	var ledge := MeshLib.part(MeshLib.cylinder_mesh(12), Vector3(22.0, 3.0, 18.0), rock,
		Vector3(0, -1.5, 4.0))
	add_child(ledge)
	var grass := MeshLib.part(MeshLib.cylinder_mesh(12), Vector3(21.4, 0.5, 17.4),
		Color(0.32, 0.42, 0.28), Vector3(0, 0.05, 4.0))
	add_child(grass)
	# The mouth of the Hollow, behind: where the player just came from.
	var arch := MeshLib.part(MeshLib.hemi_mesh(14, 5), Vector3(14.0, 9.0, 10.0),
		rock.darkened(0.45), Vector3(0, 0.0, 14.0))
	add_child(arch)
	var dark := MeshLib.part(MeshLib.sphere_mesh(12, 6), Vector3(8.0, 6.0, 6.0),
		Color(0.03, 0.04, 0.05), Vector3(0, 1.4, 13.0))
	add_child(dark)
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	for i in 26:
		var a := rng.randf() * TAU
		var r := rng.randf_range(3.0, 9.5)
		var stone := MeshLib.part(MeshLib.sphere_mesh(6, 3),
			Vector3.ONE * rng.randf_range(0.4, 1.4), rock.lightened(rng.randf_range(-0.1, 0.1)),
			Vector3(sin(a) * r, 0.1, 4.0 + cos(a) * r * 0.8))
		add_child(stone)
	for i in 40:
		var a2 := rng.randf() * TAU
		var r2 := rng.randf_range(2.0, 10.0)
		var blade := MeshLib.part(MeshLib.box_mesh(), Vector3(0.5, 0.6, 0.03),
			Color(0.42, 0.56, 0.3), Vector3(sin(a2) * r2, 0.35, 4.0 + cos(a2) * r2 * 0.8))
		blade.rotation.y = rng.randf() * TAU
		add_child(blade)

## Distance is built in layers: ridges, then a river, then settlements with
## smoke, then things flying that are plainly much larger than the player.
func _build_distance() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var layers := [
		{"dist": 170.0, "color": Color(0.36, 0.40, 0.44), "h": 46.0, "count": 12},
		{"dist": 280.0, "color": Color(0.44, 0.48, 0.54), "h": 72.0, "count": 12},
		{"dist": 420.0, "color": Color(0.55, 0.59, 0.66), "h": 104.0, "count": 11},
	]
	for layer in layers:
		for i in int(layer.count):
			var t := float(i) / float(int(layer.count) - 1) - 0.5
			var x := t * float(layer.dist) * 2.1 + rng.randf_range(-18.0, 18.0)
			var h := float(layer.h) * rng.randf_range(0.55, 1.25)
			var peak := MeshLib.part(MeshLib.cone_mesh(6),
				Vector3(h * rng.randf_range(1.1, 1.9), h, h * 1.2), layer.color,
				Vector3(x, h * 0.48 - 14.0, -float(layer.dist)))
			peak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(peak)
	var river := MeshLib.part(MeshLib.box_mesh(), Vector3(420.0, 0.6, 26.0),
		Color(0.48, 0.62, 0.76), Vector3(-30.0, -17.0, -150.0))
	river.rotation.y = 0.24
	add_child(river)
	var river2 := MeshLib.part(MeshLib.box_mesh(), Vector3(300.0, 0.6, 16.0),
		Color(0.5, 0.64, 0.78), Vector3(90.0, -20.0, -220.0))
	river2.rotation.y = -0.5
	add_child(river2)
	var basin := MeshLib.part(MeshLib.box_mesh(), Vector3(900.0, 2.0, 540.0),
		Color(0.34, 0.40, 0.32), Vector3(0, -19.0, -240.0))
	basin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(basin)
	# Settlements: too small to make out, which is exactly the point.
	for spot in [Vector3(-62, -16, -168), Vector3(48, -16, -196), Vector3(-10, -15, -132),
			Vector3(104, -16, -240)]:
		for i in 7:
			var hut := MeshLib.part(MeshLib.box_mesh(), Vector3(3.2, 2.4, 3.2),
				Color(0.5, 0.42, 0.34),
				spot + Vector3(rng.randf_range(-9, 9), 1.2, rng.randf_range(-7, 7)))
			hut.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(hut)
		var tower := MeshLib.part(MeshLib.cylinder_mesh(7), Vector3(3.0, 14.0, 3.0),
			Color(0.55, 0.47, 0.4), spot + Vector3(0, 7.0, 0))
		add_child(tower)
		_smoke_points.append(spot + Vector3(0, 4.0, 0))
	for i in 5:
		var ruin := MeshLib.part(MeshLib.cylinder_mesh(7), Vector3(5.0, 26.0, 5.0),
			Color(0.46, 0.45, 0.46),
			Vector3(rng.randf_range(-150, 150), -6.0, rng.randf_range(-260, -150)))
		ruin.rotation.z = rng.randf_range(-0.18, 0.18)
		add_child(ruin)
	# Something enormous, circling, a long way off.
	for i in 3:
		var flyer := Node3D.new()
		var bodyc := Color(0.24, 0.22, 0.3)
		flyer.add_child(MeshLib.part(MeshLib.sphere_mesh(8, 4), Vector3(10.0, 6.0, 20.0), bodyc))
		for side in [-1.0, 1.0]:
			var wing := MeshLib.part(MeshLib.box_mesh(), Vector3(34.0, 0.7, 14.0), bodyc,
				Vector3(19.0 * side, 1.0, -1.0))
			wing.rotation.z = -0.22 * side
			flyer.add_child(wing)
		add_child(flyer)
		_flyers.append(flyer)

func _build_player() -> void:
	wisp = PlayerVisuals.new()
	add_child(wisp)
	wisp.position = Vector3(0, 0.5, -3.2)
	wisp.rebuild(Game.loadout.mutations(), Game.loadout.evolution)

func _build_camera() -> void:
	cam = Camera3D.new()
	cam.fov = 62.0
	cam.far = 1400.0
	cam.position = Vector3(2.2, 2.4, 2.0)
	cam.look_at(Vector3(0, 1.0, -6.0), Vector3.UP)
	add_child(cam)
	cam.current = true
	# One slow pull-back: the reveal is the world getting bigger, not a cut.
	var t := create_tween().set_parallel(true)
	t.tween_property(cam, "position", Vector3(0.0, 9.5, 20.0), 17.0).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(cam, "fov", 74.0, 17.0)

func _process(delta: float) -> void:
	_time += delta
	if cam != null:
		cam.look_at(Vector3(0, 1.6 + _time * 0.08, -14.0), Vector3.UP)
	for i in _flyers.size():
		var f := _flyers[i]
		var a := _time * 0.045 + TAU * float(i) / 3.0
		var r := 190.0 + float(i) * 55.0
		f.position = Vector3(sin(a) * r, 24.0 + sin(_time * 0.3 + i) * 7.0, -210.0 + cos(a) * r * 0.5)
		f.rotation.y = -a + PI * 0.5
		f.rotation.z = sin(_time * 0.6 + i) * 0.16
	if randf() < delta * 4.0:
		for p in _smoke_points:
			if randf() < 0.4:
				Fx.burst(p, Color(0.72, 0.72, 0.7, 0.5), "smoke", 2, 3.0)
	if wisp != null:
		wisp.position.y = 0.5 + sin(_time * 1.2) * 0.06
