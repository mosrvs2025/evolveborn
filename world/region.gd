extends Node3D
## Assembles one region of the Hollow and everything living in it, then puts the
## player down in it. Only one region is ever in memory; the gate between them
## is what streams the next one in.

var region_id := "awakening_cavern"
var entry_point := "entry"

var terrain: Terrain
var layout: Dictionary
var colors: Dictionary
var rng := RandomNumberGenerator.new()
var pools: Dictionary = {}          # id -> node
var gate: Node3D = null
var boss: Node3D = null

func _ready() -> void:
	layout = Layouts.get_layout(region_id)
	colors = Palette.region(region_id)
	rng.seed = hash(region_id)
	_build_environment()
	terrain = Terrain.new()
	add_child(terrain)
	terrain.build(layout, colors, int(rng.seed) & 0x7fffffff)
	_build_props()
	_build_fixtures()
	_spawn_creatures()
	_spawn_player()
	if layout.has("boss"):
		_spawn_boss()
	Audio.play_music(String(layout.get("music", "explore_cave")))
	if layout.has("echo"):
		Game.echo(String(layout.echo))
	Sig.toast.emit(String(layout.get("name", region_id)).to_upper(), Palette.UI_ACCENT)

# --- look ---------------------------------------------------------------------

func _build_environment() -> void:
	var env := Environment.new()
	var open_sky := not bool(layout.get("roof", true))
	if open_sky:
		var sky := Sky.new()
		var sky_mat := ProceduralSkyMaterial.new()
		sky_mat.sky_top_color = Color(0.20, 0.30, 0.40)
		sky_mat.sky_horizon_color = Color(colors.fog).lightened(0.25)
		sky_mat.ground_bottom_color = Color(colors.ground).darkened(0.4)
		sky_mat.ground_horizon_color = Color(colors.fog).lightened(0.2)
		sky_mat.sun_angle_max = 40.0
		sky.sky_material = sky_mat
		env.background_mode = Environment.BG_SKY
		env.sky = sky
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_sky_contribution = 0.75
	else:
		env.background_mode = Environment.BG_COLOR
		env.background_color = colors.fog
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_sky_contribution = 0.0
	env.ambient_light_color = colors.ambient
	env.ambient_light_energy = 1.0 if open_sky else 1.35
	env.fog_enabled = true
	env.fog_light_color = colors.fog
	env.fog_density = float(colors.fog_density)
	env.fog_sky_affect = 0.4 if open_sky else 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var key := DirectionalLight3D.new()
	key.light_color = colors.key
	key.light_energy = 1.05 if open_sky else 0.8
	key.rotation_degrees = Vector3(-58, 38, 0)
	# Only the open basin gets shadows. Underground the sun is a fiction anyway,
	# and directional shadow maps are the single most expensive thing here.
	key.shadow_enabled = Settings.shadows_enabled() and open_sky
	key.directional_shadow_max_distance = Settings.view_distance() * 0.45
	add_child(key)

	var fill := DirectionalLight3D.new()
	fill.light_color = Color(colors.accent).darkened(0.3)
	fill.light_energy = 0.3
	fill.rotation_degrees = Vector3(-18, -140, 0)
	fill.shadow_enabled = false
	add_child(fill)

func _build_props() -> void:
	var density := Settings.prop_density()
	for p in layout.get("props", []):
		var count := int(float(p.count) * density)
		if count <= 0:
			continue
		for node in Props.scatter(String(p.kind), count, terrain, rng,
				colors.accent, colors.ground):
			add_child(node)

# --- fixtures -----------------------------------------------------------------

func _build_fixtures() -> void:
	for pool_def in layout.get("pools", []):
		var pool = load("res://world/memory_pool.gd").new()
		pool.pool_id = String(pool_def.id)
		add_child(pool)
		pool.global_position = terrain.point_in_zone(int(pool_def.zone), pool_def.offset)
		pools[pool.pool_id] = pool
	for s in layout.get("secrets", []):
		if Game.secrets_found.has(String(s.id)):
			continue
		var secret = load("res://world/secret.gd").new()
		secret.secret_id = String(s.id)
		add_child(secret)
		secret.global_position = terrain.point_in_zone(int(s.zone), s.offset)
	for hz in layout.get("hazards", []):
		var hazard = load("res://world/hazard.gd").new()
		hazard.kind = String(hz.kind)
		hazard.radius = float(hz.get("radius", 4.0))
		add_child(hazard)
		hazard.global_position = terrain.point_in_zone(int(hz.zone), hz.offset)
	var gate_def: Dictionary = layout.get("gate", {})
	if not gate_def.is_empty():
		gate = load("res://world/gate.gd").new()
		gate.to_region = String(gate_def.to)
		add_child(gate)
		gate.global_position = terrain.point_in_zone(int(gate_def.zone), gate_def.offset)
		var to_center := terrain.zone_center(int(gate_def.zone)) - gate.global_position
		gate.rotation.y = atan2(to_center.x, to_center.z)

func _spawn_creatures() -> void:
	var budget := 1.0 if Settings.quality_resolved != "low" else 0.65
	for s in layout.get("spawns", []):
		var data := DB.get_creature(String(s.species))
		if data == null:
			continue
		var count := maxi(1, int(round(float(s.count) * budget)))
		for i in count:
			var c := Creature.new()
			c.setup(data)
			add_child(c)
			var p := terrain.random_point(rng, int(s.get("zone", -1)))
			c.global_position = p + Vector3(0, data.hover_height if data.flies else 0.4, 0)
			c.home = c.global_position
			c.leash = 18.0

func _spawn_boss() -> void:
	var boss_def: Dictionary = layout.boss
	boss = load("res://boss/root_devourer.gd").new()
	add_child(boss)
	boss.global_position = terrain.point_in_zone(int(boss_def.zone), boss_def.offset)
	boss.arena_center = terrain.zone_center(int(boss_def.zone))
	boss.arena_radius = float(layout.zones[int(boss_def.zone)].r) - 3.0

# --- player -------------------------------------------------------------------

func _spawn_player() -> void:
	var player := Player.new()
	add_child(player)
	player.global_position = _entry_position() + Vector3(0, 1.2, 0)
	Game.player = player
	var rig := CameraRig.new()
	add_child(rig)
	rig.target = player
	rig.global_position = player.global_position + Vector3(0, 2.4, 0)
	player.cam_rig = rig
	# Start the camera behind the player rather than wherever the last one was.
	rig.yaw = 0.0
	if gate != null:
		var to_gate: Vector3 = gate.global_position - player.global_position
		rig.yaw = atan2(-to_gate.x, -to_gate.z)

func _entry_position() -> Vector3:
	if entry_point.begins_with("pool:"):
		var id := entry_point.substr(5)
		if pools.has(id):
			return pools[id].global_position + Vector3(0, 0.2, 7.0)
	if entry_point == "exit" and gate != null:
		return gate.global_position + Vector3(0, 0, -4.0)
	if not pools.is_empty():
		var first: Node3D = pools.values()[0]
		return first.global_position + Vector3(0, 0.2, 7.0)
	return terrain.zone_center(0)

func player_start() -> Vector3:
	return _entry_position()
