extends CharacterBody3D
class_name Creature
## One organism, driven entirely by its CreatureData row.
##
## Creatures do not exist to attack the player. They pick targets from the whole
## ecosystem: predators hunt whatever their diet lists, grazers run from
## whatever their fears list, and the player is simply another entry in both.

enum St { IDLE, WANDER, GRAZE, FLEE, CHASE, ATTACK, STUNNED, DEAD }

const GRAVITY := 24.0

var data: CreatureData
var health := 30.0
var max_health := 30.0
var dead := false
var aggravated := false            ## has a target and is acting on it
var body_radius := 0.7
var home := Vector3.ZERO
var leash := 16.0
var elite := false

var state: St = St.IDLE
var target: Node3D = null
var status := StatusSet.new()
var sys: AbilitySystem
var visuals: CreatureVisuals

var _think := 0.0
var _windup := 0.0
var _attack_cd := 0.0
var _state_timer := 0.0
var _wander_point := Vector3.ZERO
var _stun := 0.0
var _hover_phase := 0.0
var _lod := 0
var _reveal: MeshInstance3D = null
var _bar: Node3D = null
var _bar_fill: MeshInstance3D = null
var _bar_timer := 0.0
var _hidden := 0.0
var _leap_cd := 0.0
var _spawn_fade := 1.0

func setup(p_data: CreatureData) -> void:
	data = p_data

func _ready() -> void:
	add_to_group("creature")
	collision_layer = 4
	collision_mask = 1
	max_health = data.max_health
	health = max_health
	elite = bool(data.flags.get("elite", false))
	home = global_position
	_wander_point = home
	var parts := ProcCreature.build(data.body_plan, data)
	body_radius = float(parts.radius)
	var cs := MeshLib.collision_capsule(body_radius * 0.8, float(parts.height) * 0.9,
		Vector3(0, float(parts.height) * 0.45, 0))
	add_child(cs)
	visuals = CreatureVisuals.new()
	add_child(visuals)
	visuals.setup(parts, data)
	sys = AbilitySystem.new(self, "creature")
	add_child(sys)
	_build_health_bar(float(parts.height))
	if data.behavior == "ambusher":
		_hidden = 0.75
		visuals.set_hidden(_hidden)
	Game.note_species(data.id)
	_think = randf() * 0.4

func _build_health_bar(h: float) -> void:
	_bar = Node3D.new()
	_bar.position = Vector3(0, h + 0.55, 0)
	_bar.visible = false
	add_child(_bar)
	var back := MeshLib.part(MeshLib.quad_mesh(Vector2(1.1, 0.12)), Vector3.ONE,
		Color(0, 0, 0, 0.65), Vector3.ZERO, Color(0, 0, 0, 0))
	back.material_override.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	back.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	back.material_override.no_depth_test = false
	back.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bar.add_child(back)
	_bar_fill = MeshLib.part(MeshLib.quad_mesh(Vector2(1.04, 0.08)), Vector3.ONE,
		Palette.HEALTH, Vector3(0, 0, 0.01), Color(Palette.HEALTH.r, Palette.HEALTH.g, Palette.HEALTH.b, 0.8))
	var fm: StandardMaterial3D = _bar_fill.material_override.duplicate()
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_bar_fill.material_override = fm
	_bar_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bar.add_child(_bar_fill)

# --- frame --------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if dead:
		return
	_update_lod()
	if _lod >= 2:
		# Far away: keep it simple and cheap, but keep it alive.
		velocity = Vector3.ZERO
		if not data.flies:
			velocity.y -= GRAVITY * delta
			move_and_slide()
		return
	_tick_timers(delta)
	_tick_status(delta)
	if _stun > 0.0:
		state = St.STUNNED
	elif _think <= 0.0:
		_think = 0.22 + randf() * 0.14
		_decide()
	_act(delta)
	_move(delta)
	if _lod == 0:
		var speed_frac := Vector2(velocity.x, velocity.z).length() / maxf(data.move_speed, 0.1)
		visuals.animate(delta, clampf(speed_frac, 0.0, 1.4), is_on_floor())
	_update_bar(delta)
	_update_reveal()

func _update_lod() -> void:
	var p := Game.player
	if p == null or not is_instance_valid(p):
		_lod = 0
		return
	var d := global_position.distance_to(p.global_position)
	_lod = 0 if d < 26.0 else (1 if d < 48.0 else 2)

func _tick_timers(delta: float) -> void:
	_think -= delta
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_state_timer += delta
	_stun = maxf(0.0, _stun - delta)
	_leap_cd = maxf(0.0, _leap_cd - delta)
	_hover_phase += delta

func _tick_status(delta: float) -> void:
	var dmg := status.tick(delta)
	if dmg > 0.0:
		_damage(dmg, null)
		if randf() < 0.2:
			Fx.burst(global_position + Vector3.UP * body_radius, status.tint(), "venom", 3, 0.5)

# --- decisions ----------------------------------------------------------------

func _decide() -> void:
	var threat := _nearest_threat()
	if threat != null:
		target = threat
		state = St.FLEE
		aggravated = true
		return
	var prey := _pick_target()
	if prey != null:
		target = prey
		aggravated = true
		var d := global_position.distance_to(prey.global_position)
		if data.behavior == "territorial" and home.distance_to(global_position) > leash and d > data.attack_range:
			state = St.WANDER
			_wander_point = home
			return
		state = St.ATTACK if d <= _preferred_range() else St.CHASE
		return
	aggravated = false
	target = null
	if data.behavior == "grazer" and randf() < 0.45:
		state = St.GRAZE
		return
	if state != St.WANDER or global_position.distance_to(_wander_point) < 1.6:
		state = St.WANDER
		_pick_wander_point()

func _preferred_range() -> float:
	if data.behavior == "ranged":
		return data.attack_range * 0.85
	return data.attack_range + body_radius * 0.5

## The player is a candidate like anything else; what differs is the range at
## which each species notices.
func _pick_target() -> Node3D:
	var range_mult := 1.0
	var p := Game.player
	var best: Node3D = null
	var best_d := INF
	if p != null and is_instance_valid(p) and p.get("dead") != true:
		var reduce := float(p.flags.get("aggro_reduce", 0.0)) if p.get("flags") != null else 0.0
		var r: float = data.aggro_range * (1.0 - reduce) * (1.6 if aggravated else 1.0)
		if data.behavior == "ambusher" and _hidden > 0.1:
			r *= 0.8
		var d := global_position.distance_to(p.global_position)
		if d < r and (data.behavior != "grazer" or aggravated):
			best = p
			best_d = d
	if data.diet.size() > 0:
		for c in get_tree().get_nodes_in_group("creature"):
			if c == self or not is_instance_valid(c) or c.get("dead") == true:
				continue
			var cd: CreatureData = c.data
			if not _tags_match(cd.species_tags, data.diet):
				continue
			var d2 := global_position.distance_to(c.global_position)
			if d2 < data.aggro_range * 1.1 and d2 < best_d:
				best = c
				best_d = d2
	return best

func _nearest_threat() -> Node3D:
	if data.fears.size() == 0 or health >= max_health * 0.999:
		if data.fears.size() == 0:
			return null
	for c in get_tree().get_nodes_in_group("creature"):
		if c == self or not is_instance_valid(c) or c.get("dead") == true:
			continue
		if not _tags_match(c.data.species_tags, data.fears):
			continue
		if global_position.distance_to(c.global_position) < data.aggro_range * 0.8:
			return c
	# A grazer that has been hit runs from the thing that hit it, too.
	if aggravated and health < max_health * 0.4 and data.behavior == "grazer":
		var p := Game.player
		if p != null and is_instance_valid(p) and global_position.distance_to(p.global_position) < 12.0:
			return p
	return null

static func _tags_match(tags: PackedStringArray, wanted: PackedStringArray) -> bool:
	for w in wanted:
		if tags.has(w):
			return true
	return false

func _pick_wander_point() -> void:
	var a := randf() * TAU
	var r := randf_range(3.0, 9.0)
	_wander_point = home + Vector3(sin(a) * r, 0, cos(a) * r)

# --- acting -------------------------------------------------------------------

func _act(delta: float) -> void:
	match state:
		St.ATTACK: _do_attack(delta)
		St.CHASE: _do_chase(delta)
		St.FLEE: _do_flee(delta)
		St.GRAZE: _do_graze(delta)
		St.WANDER: _do_wander(delta)
		St.STUNNED: _steer(Vector3.ZERO, 0.0, delta)
		_: _steer(Vector3.ZERO, 0.0, delta)
	if data.behavior == "ambusher":
		var want: float = 0.0 if aggravated else 0.75
		_hidden = lerpf(_hidden, want, clampf(delta * 3.0, 0.0, 1.0))
		visuals.set_hidden(_hidden)

func _do_wander(delta: float) -> void:
	var to := _wander_point - global_position
	to.y = 0.0
	if to.length() < 1.4:
		_steer(Vector3.ZERO, 0.0, delta)
		return
	_steer(to.normalized(), data.move_speed * 0.45, delta)

func _do_graze(delta: float) -> void:
	_steer(Vector3.ZERO, 0.0, delta)
	visuals.set_windup(0.12 + sin(_state_timer * 2.0) * 0.1)

func _do_flee(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		state = St.WANDER
		return
	var away := global_position - target.global_position
	away.y = 0.0
	if away.length() > data.aggro_range * 1.5:
		aggravated = false
		state = St.WANDER
		return
	_steer(away.normalized(), data.move_speed * 1.15, delta)

func _do_chase(delta: float) -> void:
	if target == null or not is_instance_valid(target) or target.get("dead") == true:
		state = St.WANDER
		return
	var to := target.global_position - global_position
	var flat := Vector3(to.x, 0, to.z)
	if flat.length() <= _preferred_range():
		state = St.ATTACK
		_steer(Vector3.ZERO, 0.0, delta)
		return
	if data.behavior == "ranged" and flat.length() < data.attack_range * 0.55:
		_steer(-flat.normalized(), data.move_speed * 0.9, delta)
		return
	if data.behavior == "leaper" and _leap_cd <= 0.0 and is_on_floor() and flat.length() < 11.0:
		_leap_cd = 2.4
		velocity.y = 9.5
		velocity += flat.normalized() * data.move_speed * 1.6
		visuals.squash(0.5)
		Audio.play_at("leap", global_position, -8.0)
		return
	_steer(flat.normalized(), data.move_speed, delta)

func _do_attack(delta: float) -> void:
	if target == null or not is_instance_valid(target) or target.get("dead") == true:
		state = St.WANDER
		aggravated = false
		return
	var to := target.global_position - global_position
	var flat := Vector3(to.x, 0, to.z)
	if flat.length() > _preferred_range() * 1.35 and _windup <= 0.0:
		state = St.CHASE
		return
	_face_toward(flat, delta)
	if data.behavior == "ranged":
		_steer(Vector3.ZERO, 0.0, delta)
	else:
		_steer(flat.normalized() * 0.25, data.move_speed * 0.3, delta)
	if _windup > 0.0:
		_windup -= delta
		visuals.set_windup(1.0 - clampf(_windup / maxf(data.attack_windup, 0.01), 0.0, 1.0))
		if _windup <= 0.0:
			_strike()
		return
	if _attack_cd <= 0.0:
		_windup = data.attack_windup
		visuals.set_windup(0.0)
		if data.voice != "":
			Audio.play_varied("voice_" + data.voice, global_position, 0.18, -6.0)

func _strike() -> void:
	_attack_cd = data.attack_cooldown
	visuals.set_windup(0.0)
	visuals.squash(-0.35)
	if data.ranged_ability != "":
		var dir := Vector3.FORWARD
		if target != null and is_instance_valid(target):
			dir = (target.global_position + Vector3.UP * 0.5 - global_position - Vector3.UP * 0.8)
			dir.y *= 0.5
			dir = dir.normalized()
		sys.execute(data.ranged_ability, global_position, dir)
		return
	# Basic melee: a short arc in front, resolved directly so creature-on-creature
	# fights use exactly the same numbers as creature-on-player ones.
	var origin := global_position
	var aim := -global_transform.basis.z
	var reach := data.attack_range + body_radius
	Fx.burst(origin + aim * reach * 0.6 + Vector3.UP * body_radius, data.color_secondary, "impact", 7)
	for other in _melee_candidates():
		var to: Vector3 = other.global_position - origin
		to.y = 0.0
		var other_r: float = float(other.get("body_radius") if other.get("body_radius") != null else 0.5)
		if to.length() > reach + other_r or to.length() < 0.01:
			continue
		if aim.angle_to(to.normalized()) > deg_to_rad(65.0):
			continue
		var h := Hit.make(data.damage, self, "creature", other.global_position)
		h.knockback = 5.0 + data.damage * 0.25
		h.color = data.color_secondary
		other.take_hit(h)

func _melee_candidates() -> Array:
	var out: Array = []
	var p := Game.player
	if p != null and is_instance_valid(p):
		out.append(p)
	for c in get_tree().get_nodes_in_group("creature"):
		if c != self and is_instance_valid(c) and c.get("dead") != true:
			out.append(c)
	return out

# --- movement -----------------------------------------------------------------

func _steer(dir: Vector3, speed: float, delta: float) -> void:
	var mult := status.speed_multiplier()
	var flat := Vector3(velocity.x, 0, velocity.z)
	var want := dir * speed * mult
	flat = flat.move_toward(want, 26.0 * delta)
	velocity.x = flat.x
	velocity.z = flat.z
	if dir.length_squared() > 0.01 and speed > 0.1:
		_face_toward(dir, delta)

func _face_toward(dir: Vector3, delta: float) -> void:
	if dir.length_squared() < 0.01:
		return
	var want := atan2(dir.x, dir.z)
	rotation.y = CameraRig._ease_angle(rotation.y, want, delta * data.turn_speed)

func _move(delta: float) -> void:
	if data.flies:
		# Flyers hold an altitude over whatever is below them and bob on it.
		var ground := _ground_height()
		var want_y := ground + data.hover_height + sin(_hover_phase * 1.6) * 0.35
		velocity.y = lerpf(velocity.y, (want_y - global_position.y) * 3.2, clampf(delta * 5.0, 0.0, 1.0))
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()

func _ground_height() -> float:
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3.UP * 3.0
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 40.0)
	q.collision_mask = 1
	var r := space.intersect_ray(q)
	return float(r.position.y) if not r.is_empty() else global_position.y

# --- damage -------------------------------------------------------------------

func take_hit(hit: Hit) -> void:
	if dead or hit.source == self:
		return
	var armor := maxf(0.0, data.armor - hit.armor_pierce)
	var amount := maxf(hit.damage * 0.15, hit.damage - armor)
	var crit := false
	if status.consume("mark"):
		amount *= status.power("mark") if status.power("mark") > 0.0 else 2.5
		crit = true
	if status.has("mark"):
		crit = true
	_damage(amount, hit.source, hit.color, crit)
	if hit.status != "":
		apply_status(hit.status, hit.status_power, hit.status_time)
	if hit.knockback > 0.0:
		var push := global_position - hit.position
		push.y = 0.0
		if push.length() < 0.01:
			push = Vector3.BACK
		var resist := 1.0 / (1.0 + max_health / 90.0)
		velocity += push.normalized() * hit.knockback * resist
		if not data.flies:
			velocity.y = maxf(velocity.y, hit.knockback * 0.22 * resist)
		_stun = maxf(_stun, 0.12)
	# Being hit is how anything makes an enemy, including one creature of another.
	aggravated = true
	if hit.source != null and is_instance_valid(hit.source) and hit.source != self:
		target = hit.source
		state = St.CHASE if data.behavior != "grazer" else St.FLEE

func _damage(amount: float, source: Node, color := Color.WHITE, crit := false) -> void:
	if dead:
		return
	health -= amount
	_bar_timer = 4.0
	if _bar != null:
		_bar.visible = true
	visuals.flash(Color.WHITE if not crit else Palette.STATUS.mark, 1.0)
	visuals.squash(-0.3 if not crit else -0.5)
	var at := global_position + Vector3.UP * (body_radius + 0.5)
	Fx.damage_number(at, amount, Palette.UI_WARN if not crit else Palette.STATUS.mark, crit)
	Fx.burst(at, color, "impact", 8 if not crit else 16)
	if source != null and source == Game.player:
		Game.stats["damage_dealt"] = float(Game.stats["damage_dealt"]) + amount
		Fx.hit_stop(0.05 if not crit else 0.09)
		Fx.shake(0.12 if not crit else 0.3)
		Audio.play_varied("hit", at, 0.15, -3.0)
	if health <= 0.0:
		die(source)

func apply_status(name: String, power: float, time: float) -> void:
	status.apply(name, power, time)
	if name != "mark":
		visuals.flash(Palette.STATUS.get(name, Color.WHITE), 0.6)

func die(killer: Node = null) -> void:
	if dead:
		return
	dead = true
	state = St.DEAD
	remove_from_group("creature")
	if killer == Game.player:
		Game.stats["kills"] = int(Game.stats["kills"]) + 1
		Game.add_essence(int(round(data.essence_reward * 0.35)))
		Game.echo("first_kill")
	Sig.creature_died.emit(self)
	Audio.play_at("creature_die", global_position, -3.0)
	Fx.burst(global_position + Vector3.UP * body_radius * 0.6, data.color_secondary, "dissolve", 16)
	# The body stays. That is the whole point.
	var corpse = load("res://creatures/corpse.gd").new()
	corpse.setup(data, visuals)
	get_parent().add_child(corpse)
	corpse.global_position = global_position
	corpse.rotation.y = rotation.y
	queue_free()

# --- presentation -------------------------------------------------------------

func _update_bar(delta: float) -> void:
	if _bar == null or not _bar.visible:
		return
	_bar_timer -= delta
	if _bar_timer <= 0.0 and health >= max_health:
		_bar.visible = false
		return
	var f := clampf(health / maxf(max_health, 0.01), 0.0, 1.0)
	_bar_fill.scale.x = maxf(f, 0.001)
	_bar_fill.position.x = -(1.0 - f) * 0.52

## Echo Sense marks creatures through terrain. It is a dot, not an outline,
## because a dot costs one draw call and still answers "what is behind me".
func _update_reveal() -> void:
	var p := Game.player
	var want: bool = p != null and is_instance_valid(p) and p.get("flags") != null and p.flags.has("reveal")
	if want and _reveal == null:
		_reveal = MeshLib.glow_dot(0.16, data.color_secondary, Vector3(0, body_radius * 2.0 + 1.1, 0))
		var m: StandardMaterial3D = _reveal.material_override.duplicate()
		m.no_depth_test = true
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		_reveal.material_override = m
		add_child(_reveal)
	elif _reveal != null:
		_reveal.visible = want
