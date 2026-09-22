extends CharacterBody3D
class_name Player
## The Wisp. Movement first, then everything the body can be made to do.
##
## Every input here is an InputMap action, and the three action slots resolve
## through the loadout, so the same three controls mean different things once
## the player has eaten something interesting.

const GRAVITY := 24.0
const TERMINAL := 42.0
const GROUND_ACCEL := 58.0
const AIR_ACCEL := 26.0
const GROUND_FRICTION := 62.0
const AIR_FRICTION := 2.5
const TURN_SPEED := 16.0
const COYOTE := 0.12
const BUFFER := 0.18

var health := 100.0
var max_health := 100.0
var dead := false
var body_radius := 0.55

var stats: Dictionary = {}
var slots: Dictionary = {"primary": "body_slam", "secondary": "", "mobility": "burst"}
var flags: Dictionary = {}
var status := StatusSet.new()
var sys: AbilitySystem

var visuals: PlayerVisuals
var cam_rig: Node3D = null

var _facing := Vector3.FORWARD
var _invuln := 0.0
var _hurt_cooldown := 0.0
var _lock := 0.0                  ## attack recovery, cannot re-act
var _dash_time := 0.0
var _dash_dir := Vector3.ZERO
var _dash_speed := 0.0
var _dash_ability := ""
var _air_dashes := 0
var _coyote := 0.0
var _buffer_mobility := 0.0
var _pounding := false
var _lunge_time := 0.0
var _lunge_dir := Vector3.ZERO
var _lunge_speed := 0.0
var _combat_timer := 0.0
var _devour_target: Node = null
var _devour_progress := 0.0
var _devour_held := false
var _prompt := ""
var _regen_carry := 0.0
var _spawn_grace := 0.35

func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	floor_max_angle = deg_to_rad(52.0)
	floor_snap_length = 0.4
	var cs := MeshLib.collision_capsule(0.45, 1.25, Vector3(0, 0.62, 0))
	add_child(cs)
	visuals = PlayerVisuals.new()
	add_child(visuals)
	sys = AbilitySystem.new(self, "player")
	add_child(sys)
	refresh_from_loadout()
	health = max_health
	Sig.loadout_changed.connect(refresh_from_loadout)
	Sig.player_health_changed.emit(health, max_health)
	Sig.player_spawned.emit(self)

## Single place the body is recomputed. Called on spawn and on every change to
## the loadout, which is why equipping a trait is instant in every system.
func refresh_from_loadout() -> void:
	var lo: Loadout = Game.loadout
	stats = lo.stats()
	slots = lo.abilities()
	flags = lo.flags()
	var old_max := max_health
	max_health = float(stats.max_health)
	if old_max > 0.0:
		health = clampf(health * (max_health / old_max), 1.0, max_health)
	else:
		health = max_health
	sys.power = float(stats.ability_power)
	sys.damage_mult = float(stats.damage_mult)
	sys.cooldown_mult = float(stats.cooldown_mult)
	sys.knockback_mult = float(stats.knockback)
	sys.assist = clampf(float(Settings.get_value("target_assist")) + float(stats.assist), 0.0, 1.0)
	sys.on_hit_status = String(flags.get("on_hit_status", ""))
	sys.on_hit_power = float(flags.get("on_hit_power", 0.0))
	sys.on_hit_time = float(flags.get("on_hit_time", 0.0))
	if visuals != null:
		visuals.rebuild(lo.mutations(), lo.evolution)
	Sig.player_health_changed.emit(health, max_health)
	Sig.capacity_changed.emit(lo.used_capacity(), lo.capacity())

# --- frame --------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if dead:
		velocity.y -= GRAVITY * delta
		move_and_slide()
		return
	_tick_timers(delta)
	_tick_status(delta)
	_tick_regen(delta)
	_handle_devour(delta)
	var wish := _wish_direction()
	if _dash_time > 0.0:
		_apply_dash(delta)
	elif _lunge_time > 0.0:
		_apply_lunge(delta)
	else:
		_apply_move(wish, delta)
	_apply_gravity(delta)
	var was_floor := is_on_floor()
	move_and_slide()
	if not was_floor and is_on_floor():
		_on_land()
	if is_on_floor():
		_coyote = COYOTE
		_air_dashes = 0
	_face(wish, delta)
	_read_actions()

func _tick_timers(delta: float) -> void:
	_invuln = maxf(0.0, _invuln - delta)
	_hurt_cooldown = maxf(0.0, _hurt_cooldown - delta)
	_lock = maxf(0.0, _lock - delta)
	_coyote = maxf(0.0, _coyote - delta)
	_buffer_mobility = maxf(0.0, _buffer_mobility - delta)
	_combat_timer = maxf(0.0, _combat_timer - delta)
	_spawn_grace = maxf(0.0, _spawn_grace - delta)

func _tick_status(delta: float) -> void:
	var dmg := status.tick(delta)
	if dmg > 0.0:
		_raw_damage(dmg, false)
	visuals.set_charge(0.35 if status.entries.size() > 0 else 0.0)

func _tick_regen(delta: float) -> void:
	var r := float(stats.regen)
	if r <= 0.0 or health >= max_health:
		return
	# Regeneration is worth its Core cost because it keeps working in a fight,
	# just slower than it does between them.
	var rate: float = r * (0.45 if _combat_timer > 0.0 else 1.0)
	_regen_carry += rate * delta
	if _regen_carry >= 1.0:
		var gained := floorf(_regen_carry)
		_regen_carry -= gained
		health = minf(max_health, health + gained)
		Sig.player_health_changed.emit(health, max_health)

# --- movement -----------------------------------------------------------------

func _wish_direction() -> Vector3:
	var iv := InputMgr.move_vector()
	if iv.length_squared() < 0.02:
		return Vector3.ZERO
	var basis_yaw: float = 0.0
	if cam_rig != null and cam_rig.has_method("camera_yaw"):
		basis_yaw = cam_rig.camera_yaw()
	var forward := Vector3(sin(basis_yaw), 0, cos(basis_yaw))
	var right := Vector3(forward.z, 0, -forward.x)
	return (right * iv.x + forward * iv.y).normalized()

func _apply_move(wish: Vector3, delta: float) -> void:
	var speed := float(stats.move_speed) * status.speed_multiplier()
	if _lock > 0.0:
		speed *= 0.35
	var grounded := is_on_floor()
	var accel: float = GROUND_ACCEL if grounded else AIR_ACCEL * (float(stats.air_control) / 0.38)
	var friction: float = GROUND_FRICTION if grounded else AIR_FRICTION
	var flat := Vector3(velocity.x, 0, velocity.z)
	if wish.length_squared() > 0.01:
		var target := wish * speed
		flat = flat.move_toward(target, accel * delta)
	else:
		flat = flat.move_toward(Vector3.ZERO, friction * delta)
	velocity.x = flat.x
	velocity.z = flat.z

func _apply_gravity(delta: float) -> void:
	if _dash_time > 0.0 and not _pounding:
		return
	velocity.y = maxf(velocity.y - GRAVITY * delta, -TERMINAL)

func _apply_dash(delta: float) -> void:
	_dash_time -= delta
	if _pounding:
		velocity.y = -34.0
		velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)
		if is_on_floor():
			_finish_pound()
		return
	velocity.x = _dash_dir.x * _dash_speed
	velocity.z = _dash_dir.z * _dash_speed
	if _dash_time <= 0.0:
		velocity.x *= 0.45
		velocity.z *= 0.45

func _apply_lunge(delta: float) -> void:
	_lunge_time -= delta
	velocity.x = _lunge_dir.x * _lunge_speed
	velocity.z = _lunge_dir.z * _lunge_speed

func _face(wish: Vector3, delta: float) -> void:
	var want := _facing
	if wish.length_squared() > 0.01:
		want = wish
	elif _dash_dir.length_squared() > 0.01 and _dash_time > 0.0:
		want = _dash_dir
	if want.length_squared() > 0.01:
		_facing = _facing.slerp(want, clampf(delta * TURN_SPEED, 0.0, 1.0)).normalized()
	visuals.rotation.y = atan2(_facing.x, _facing.z)
	var horiz := Vector2(velocity.x, velocity.z).length() / maxf(float(stats.move_speed), 0.1)
	visuals.impulse_stretch(clampf(velocity.y / 14.0, -0.5, 0.5), clampf(horiz * 0.35, 0.0, 0.5))

func _on_land() -> void:
	var impact := clampf(-velocity.y / 22.0, 0.0, 1.0)
	visuals.impulse_stretch(-0.55 * impact - 0.12, 0.0)
	if impact > 0.25:
		Audio.play_at("land", global_position, -10.0 + impact * 6.0)
		Fx.burst(global_position, Color(0.7, 0.8, 0.9, 0.6), "dust", int(6 * impact + 2), 0.7)

func aim_direction() -> Vector3:
	return _facing

# --- actions ------------------------------------------------------------------

func _read_actions() -> void:
	if not Game.is_playing():
		return
	if Input.is_action_just_pressed("act_mobility"):
		_buffer_mobility = BUFFER
	if _buffer_mobility > 0.0 and _try_mobility():
		_buffer_mobility = 0.0
	if _lock > 0.0 or _devour_progress > 0.0:
		return
	if Input.is_action_just_pressed("act_primary"):
		_use(slots.primary)
	elif Input.is_action_just_pressed("act_secondary") and String(slots.secondary) != "":
		_use(slots.secondary)

func _use(ability_id: String) -> void:
	if ability_id == "" or not sys.is_ready(ability_id):
		return
	var a := DB.get_ability(ability_id)
	if a == null:
		return
	var res := sys.execute(ability_id, global_position, _facing)
	if res.is_empty():
		return
	_facing = res.get("aim", _facing)
	_lock = a.recovery
	_combat_timer = 4.0
	visuals.set_charge(0.8)
	visuals.impulse_stretch(0.25, 0.4)
	Fx.shake(0.1)
	if res.has("lunge"):
		var l: Dictionary = res.lunge
		_lunge_dir = l.dir
		_lunge_speed = l.speed
		_lunge_time = l.time
	if res.has("dash"):
		_begin_dash(res.dash, a)

func _try_mobility() -> bool:
	var id := String(slots.mobility)
	if id == "" or not sys.is_ready(id) or _lock > 0.0:
		return false
	var a := DB.get_ability(id)
	if a == null:
		return false
	var vertical := float(a.flags.get("vertical", 0.0))
	var grounded := is_on_floor() or _coyote > 0.0
	var air_uses := int(a.flags.get("air_uses", 0.0))
	if not grounded and _air_dashes >= maxi(air_uses, 1):
		return false
	var dir := _wish_direction()
	if dir.length_squared() < 0.01:
		dir = _facing
	var res := sys.execute(id, global_position, dir)
	if res.is_empty():
		return false
	if not grounded:
		_air_dashes += 1
	_combat_timer = maxf(_combat_timer, 2.0)
	if res.has("dash"):
		_begin_dash(res.dash, a)
	return true

func _begin_dash(d: Dictionary, a: AbilityData) -> void:
	_dash_dir = d.dir
	_dash_speed = d.speed
	_dash_time = maxf(d.time, 0.05)
	_dash_ability = a.id
	_invuln = maxf(_invuln, float(d.iframes) + float(stats.dodge_iframes))
	_pounding = false
	var vertical := float(a.flags.get("vertical", 0.0))
	if bool(a.flags.get("ground_pound", false)) and not is_on_floor():
		# Meteor Slam in the air becomes the slam; on the ground it is the leap
		# that sets it up. One control, two halves of the same move.
		_pounding = true
		_dash_time = 1.2
		visuals.set_charge(1.0)
		Audio.play_at("leap", global_position)
		return
	if vertical > 0.0:
		velocity.y = vertical * (float(stats.jump_power) / 7.6)
		_dash_speed *= 0.75
		visuals.impulse_stretch(0.75, 0.0)
	else:
		velocity.y = maxf(velocity.y, 1.6)
		visuals.impulse_stretch(0.2, 0.7)
	if bool(flags.get("mark_crit", false)) or float(a.flags.get("mark", 0.0)) > 0.0:
		_mark_passed_creatures()
	Fx.burst(global_position + Vector3.UP * 0.5, a.color, "smoke" if a.id == "phase_slip" else "dust", 10)

func _finish_pound() -> void:
	_pounding = false
	_dash_time = 0.0
	var a := DB.get_ability(_dash_ability)
	if a != null:
		sys._aoe(a, global_position, a.radius)
		Fx.shake(0.55)
		Fx.hit_stop(0.07)
		Audio.play_at("meteor", global_position)
	visuals.impulse_stretch(-0.8, 0.0)

## Void Stalk: slipping through a creature leaves it marked for the next strike.
func _mark_passed_creatures() -> void:
	if not bool(flags.get("mark_crit", false)):
		return
	for c in get_tree().get_nodes_in_group("creature"):
		if is_instance_valid(c) and c.has_method("apply_status"):
			if global_position.distance_to(c.global_position) < 3.2:
				c.apply_status("mark", float(flags.get("mark_crit", 2.5)), 5.0)

# --- devour & interaction -----------------------------------------------------

func _handle_devour(delta: float) -> void:
	var target := _find_devour_target()
	var hold := bool(Settings.get_value("hold_to_devour"))
	var pressed := Input.is_action_pressed("act_devour") if hold else _devour_held
	if not hold and Input.is_action_just_pressed("act_devour"):
		_devour_held = not _devour_held
		pressed = _devour_held
	if target == null:
		_set_prompt("", "")
		_devour_progress = 0.0
		_devour_held = false
		_devour_target = null
		return
	if target != _devour_target:
		_devour_target = target
		_devour_progress = 0.0
	if target.has_method("interact"):
		_set_prompt(target.interact_prompt(), "act_devour")
		if Input.is_action_just_pressed("act_devour"):
			target.interact(self)
		return
	_set_prompt("DEVOUR", "act_devour")
	if pressed:
		if _devour_progress == 0.0:
			Audio.play_at("devour_start", global_position, -4.0)
		_devour_progress += delta / maxf(float(stats.devour_time), 0.15)
		visuals.set_charge(clampf(_devour_progress, 0.0, 1.0))
		Fx.suck(target.global_position + Vector3(randf_range(-0.5, 0.5), 0.4, randf_range(-0.5, 0.5)),
			global_position + Vector3.UP * 0.6, Palette.ESSENCE, 2)
		if target.has_method("set_devour_progress"):
			target.set_devour_progress(_devour_progress)
		if _devour_progress >= 1.0:
			_devour_progress = 0.0
			_devour_held = false
			target.devour(self)
	else:
		_devour_progress = maxf(0.0, _devour_progress - delta * 2.0)
		if target.has_method("set_devour_progress"):
			target.set_devour_progress(_devour_progress)

func _find_devour_target() -> Node:
	var best: Node = null
	var best_d := 3.4
	for n in get_tree().get_nodes_in_group("devourable"):
		if not is_instance_valid(n):
			continue
		var d := global_position.distance_to(n.global_position)
		if d < best_d:
			best_d = d
			best = n
	if best != null:
		return best
	for n in get_tree().get_nodes_in_group("interactable"):
		if not is_instance_valid(n):
			continue
		var d2 := global_position.distance_to(n.global_position)
		var reach: float = float(n.get("interact_range") if n.get("interact_range") != null else 3.2)
		if d2 < reach and d2 < best_d:
			best_d = d2
			best = n
	return best

func devour_progress() -> float:
	return _devour_progress

func _set_prompt(text: String, action: String) -> void:
	if text == _prompt:
		return
	_prompt = text
	Sig.prompt_changed.emit(text, action)

# --- damage -------------------------------------------------------------------

func take_hit(hit: Hit) -> void:
	if dead or _invuln > 0.0 or _spawn_grace > 0.0 or hit.team == "player" or DebugTools.god:
		return
	var amount := hit.damage * (1.0 - float(stats.phys_resist))
	_raw_damage(amount, true)
	if hit.status != "":
		apply_status(hit.status, hit.status_power, hit.status_time)
	var push := (global_position - hit.position)
	push.y = 0.0
	if push.length() < 0.01:
		push = -_facing
	var kb := hit.knockback * (1.0 - float(stats.knockback_resist))
	velocity += push.normalized() * kb
	velocity.y = maxf(velocity.y, kb * 0.25)
	_hurt_cooldown = 0.35
	_invuln = maxf(_invuln, 0.35)
	_combat_timer = 5.0
	# Toxic Blood: what keeps refilling you is not safe to spill.
	if flags.has("retaliate_poison") and is_instance_valid(hit.source) and hit.source.has_method("apply_status"):
		hit.source.apply_status("poison", float(flags.retaliate_poison), 4.0)
		Fx.burst(hit.source.global_position + Vector3.UP * 0.6, Palette.STATUS.poison, "venom", 8)

func _raw_damage(amount: float, reactive: bool) -> void:
	if dead or amount <= 0.0:
		return
	health -= amount
	Game.stats["damage_taken"] = float(Game.stats["damage_taken"]) + amount
	Sig.player_health_changed.emit(health, max_health)
	if reactive:
		visuals.flash(Palette.HEALTH)
		Fx.shake(0.22)
		Fx.hit_stop(0.045)
		Audio.play_at("hurt", global_position, -2.0)
		Fx.damage_number(global_position + Vector3.UP * 1.2, amount, Palette.HEALTH)
	if health <= max_health * 0.25 and health > 0.0:
		Game.echo("low_health")
	if health <= 0.0:
		die()

func apply_status(name: String, power: float, time: float) -> void:
	status.apply(name, power, time)
	visuals.flash(Palette.STATUS.get(name, Color.WHITE))

func heal(amount: float) -> void:
	health = minf(max_health, health + amount)
	Sig.player_health_changed.emit(health, max_health)
	Fx.burst(global_position + Vector3.UP * 0.6, Palette.UI_GOOD, "heal", 12)

func on_camera_proximity(arm_length: float) -> void:
	if visuals != null:
		visuals.set_camera_proximity(arm_length)

func full_heal() -> void:
	health = max_health
	status.clear()
	Sig.player_health_changed.emit(health, max_health)

func die() -> void:
	if dead:
		return
	dead = true
	health = 0.0
	status.clear()
	Sig.player_health_changed.emit(0.0, max_health)
	Fx.burst(global_position + Vector3.UP * 0.6, Palette.CORE, "dissolve", 30, 1.5)
	Fx.shake(0.6)
	Audio.play_at("death", global_position)
	visuals.set_charge(1.0)
	var t := create_tween()
	t.tween_property(visuals, "scale", Vector3.ONE * 0.05, 0.5).set_ease(Tween.EASE_IN)
	t.tween_callback(Game.on_player_died)
