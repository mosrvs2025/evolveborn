extends CharacterBody3D
class_name RootDevourer
## The Root Devourer. It got here the same way the player did: it ate things and
## kept what worked. Phase two is it doing that on camera, and phase three is it
## doing it to you.

const GRAVITY := 24.0

var data: CreatureData
var health := 900.0
var max_health := 900.0
var dead := false
var aggravated := true
var body_radius := 4.2
var arena_center := Vector3.ZERO
var arena_radius := 20.0

var phase := 1
var sys: AbilitySystem
var status := StatusSet.new()
var copied_traits: Array[String] = []
var _pool: Array[String] = ["root_slam", "limb_sweep", "seed_volley"]
var _cd := 3.0
var _windup := 0.0
var _pending := ""
var _telegraph_pos := Vector3.ZERO
var _charging := false
var _charge_dir := Vector3.ZERO
var _charge_time := 0.0
var _time := 0.0
var _core: MeshInstance3D
var _limbs: Array[Node3D] = []
var _maw: Node3D
var _growths: Node3D
var _busy := false
var _intro_done := false
var _stun := 0.0

func _ready() -> void:
	add_to_group("creature")
	add_to_group("boss")
	collision_layer = 4
	collision_mask = 1
	data = _make_data()
	sys = AbilitySystem.new(self, "creature")
	add_child(sys)
	add_child(MeshLib.collision_capsule(3.0, 7.0, Vector3(0, 3.5, 0)))
	_build_body()
	Sig.boss_phase_changed.emit(1)

func _make_data() -> CreatureData:
	var d := CreatureData.new()
	d.id = "root_devourer"
	d.display_name = "The Root Devourer"
	d.max_health = max_health
	d.damage = 22.0
	d.essence_reward = 300
	d.species_tags = PackedStringArray(["boss", "corrupt"])
	d.color_primary = Color(0.36, 0.24, 0.2)
	d.color_secondary = Color(0.85, 0.35, 0.45)
	return d

# --- body ---------------------------------------------------------------------

func _build_body() -> void:
	var bark := Color(0.32, 0.22, 0.18)
	var flesh := Color(0.55, 0.22, 0.3)
	var trunk := MeshLib.part(MeshLib.cylinder_mesh(14), Vector3(5.4, 6.6, 5.0), bark,
		Vector3(0, 3.3, 0))
	add_child(trunk)
	var crown := MeshLib.part(MeshLib.hemi_mesh(14, 5), Vector3(6.6, 4.4, 6.2), bark.darkened(0.2),
		Vector3(0, 6.0, 0))
	add_child(crown)
	_maw = Node3D.new()
	_maw.position = Vector3(0, 3.6, 2.2)
	add_child(_maw)
	var throat := MeshLib.blob(Vector3(3.0, 2.4, 1.6), Color(0.12, 0.06, 0.08), Vector3.ZERO,
		Color(0.9, 0.25, 0.35, 0.5))
	_maw.add_child(throat)
	for i in 7:
		var tooth := MeshLib.spike(1.0, 0.36, Color(0.86, 0.82, 0.72),
			Vector3(-1.2 + i * 0.4, 0.9 - absf(i - 3) * 0.1, 0.5))
		tooth.rotation_degrees = Vector3(160, 0, 0)
		_maw.add_child(tooth)
	_core = MeshLib.glow_dot(0.9, flesh, Vector3(0, 4.6, 1.6))
	add_child(_core)
	# Six roots: the limbs it sweeps with, and the anchors it slams through.
	for i in 6:
		var a := TAU * float(i) / 6.0
		var pivot := Node3D.new()
		pivot.position = Vector3(sin(a) * 2.2, 1.2, cos(a) * 2.2)
		pivot.rotation.y = -a
		var seg := MeshLib.limb(6.2, 0.95, bark.darkened(0.1))
		seg.rotation_degrees = Vector3(62, 0, 0)
		seg.position = Vector3(0, -0.4, 2.4)
		pivot.add_child(seg)
		var tip := MeshLib.spike(1.6, 0.5, bark.darkened(0.3), Vector3(0, -1.2, 5.0))
		tip.rotation_degrees = Vector3(120, 0, 0)
		pivot.add_child(tip)
		add_child(pivot)
		_limbs.append(pivot)
	_growths = Node3D.new()
	_growths.position = Vector3(0, 5.2, 0)
	add_child(_growths)
	var light := OmniLight3D.new()
	light.light_color = flesh
	light.light_energy = 2.4
	light.omni_range = 22.0
	light.position = Vector3(0, 5.0, 0)
	add_child(light)

## Everything it has eaten shows on the outside. In phase three this is where
## the player's own adaptations appear.
func _grow_trait(trait_id: String) -> void:
	var t := DB.get_trait(trait_id)
	if t == null or copied_traits.has(trait_id):
		return
	copied_traits.append(trait_id)
	var idx := copied_traits.size() - 1
	var a := TAU * float(idx) / 5.0
	var node := MeshLib.blob(Vector3(1.5, 1.5, 1.5), t.color,
		Vector3(sin(a) * 3.2, 0.6 + idx * 0.25, cos(a) * 3.2), Color(t.color.r, t.color.g, t.color.b, 0.8))
	_growths.add_child(node)
	for i in 3:
		var spur := MeshLib.spike(1.1, 0.3, t.color.lightened(0.2),
			Vector3(sin(a) * 3.2, 1.4 + i * 0.3, cos(a) * 3.2), Color(t.color.r, t.color.g, t.color.b, 0.6))
		spur.rotation_degrees = Vector3(randf_range(-30, 30), 0, randf_range(-30, 30))
		_growths.add_child(spur)
	if t.active_ability != "" and not _pool.has(t.active_ability):
		_pool.append(t.active_ability)
	Fx.burst(global_position + Vector3(0, 5.5, 0), t.color, "dissolve", 26, 2.0)
	Sig.toast.emit("IT HAS TAKEN " + t.display_name.to_upper(), t.color)

# --- frame --------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if dead:
		return
	_time += delta
	_stun = maxf(0.0, _stun - delta)
	var dmg := status.tick(delta)
	if dmg > 0.0:
		_damage(dmg, null)
	_animate(delta)
	if not _intro_done:
		_check_intro()
		velocity.y -= GRAVITY * delta
		move_and_slide()
		return
	if _charging:
		_do_charge(delta)
	elif _windup > 0.0:
		_windup -= delta
		_face_player(delta * 1.2)
		if _windup <= 0.0:
			_fire()
	elif _stun <= 0.0:
		_cd -= delta
		_face_player(delta)
		_reposition(delta)
		if _cd <= 0.0:
			_begin_attack()
	velocity.y -= GRAVITY * delta
	move_and_slide()

func _check_intro() -> void:
	var p := Game.player
	if p == null or not is_instance_valid(p):
		return
	if global_position.distance_to(p.global_position) < 26.0:
		_intro_done = true
		Game.echo("boss_intro")
		Audio.play_music("boss")
		Sig.toast.emit("THE ROOT DEVOURER", Color(0.9, 0.35, 0.45))
		Sig.boss_phase_changed.emit(1)
		if p.cam_rig != null:
			p.cam_rig.set_focus(self)

func _animate(delta: float) -> void:
	for i in _limbs.size():
		var l := _limbs[i]
		var idle := sin(_time * 0.8 + float(i)) * 0.09
		var tension: float = -_windup * 0.5 if _pending == "limb_sweep" else 0.0
		l.rotation.x = idle + tension
	if _core != null:
		var beat := 1.0 + sin(_time * 2.2) * 0.08 + (0.4 if _windup > 0.0 else 0.0)
		_core.scale = Vector3.ONE * 1.8 * beat
	if _maw != null:
		_maw.scale = Vector3.ONE * (1.0 + sin(_time * 1.4) * 0.05 + _windup * 0.3)
	_growths.rotation.y += delta * 0.3

func _face_player(weight: float) -> void:
	var p := Game.player
	if p == null or not is_instance_valid(p):
		return
	var to := p.global_position - global_position
	to.y = 0.0
	if to.length() < 0.1:
		return
	rotation.y = CameraRig._ease_angle(rotation.y, atan2(to.x, to.z), clampf(weight * 2.2, 0.0, 1.0))

## It shuffles, slowly. The arena is the real constraint, not its speed.
func _reposition(delta: float) -> void:
	var p := Game.player
	if p == null or not is_instance_valid(p):
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
		return
	var to := p.global_position - global_position
	to.y = 0.0
	var want := Vector3.ZERO
	if to.length() > 13.0:
		want = to.normalized() * (2.6 + float(phase) * 0.5)
	if global_position.distance_to(arena_center) > arena_radius:
		want = (arena_center - global_position).normalized() * 4.0
	velocity.x = move_toward(velocity.x, want.x, 14.0 * delta)
	velocity.z = move_toward(velocity.z, want.z, 14.0 * delta)

# --- attacks ------------------------------------------------------------------

func _begin_attack() -> void:
	var p := Game.player
	if p == null or not is_instance_valid(p) or p.get("dead") == true:
		_cd = 2.0
		return
	var choices := _pool.duplicate()
	var dist := global_position.distance_to(p.global_position)
	if dist > 16.0:
		choices = choices.filter(func(id): return id != "limb_sweep")
	if dist < 8.0:
		choices = choices.filter(func(id): return id != "devourer_charge")
	if choices.is_empty():
		choices = ["root_slam"]
	_pending = choices[randi() % choices.size()]
	var a := DB.get_ability(_pending)
	if a == null:
		_cd = 1.5
		return
	_windup = a.windup
	_telegraph_pos = p.global_position if a.shape == "aoe" else global_position
	if bool(a.flags.get("telegraph", false)):
		var radius := a.radius if a.shape != "melee_arc" else a.range
		Fx.telegraph(_telegraph_pos if a.shape == "aoe" else global_position,
			radius, Color(0.95, 0.35, 0.4), a.windup)
	Audio.play_at("boss_windup", global_position, -2.0)

func _fire() -> void:
	var a := DB.get_ability(_pending)
	if a == null:
		return
	var p := Game.player
	var aim := -global_transform.basis.z
	if p != null and is_instance_valid(p):
		var to: Vector3 = p.global_position - global_position
		to.y = 0.0
		if to.length() > 0.1:
			aim = to.normalized()
	_cd = a.cooldown / (1.0 + float(phase - 1) * 0.22)
	match _pending:
		"root_slam":
			sys._aoe(a, _telegraph_pos, a.radius)
			Fx.shake(0.6)
			Fx.burst(_telegraph_pos, Color(0.6, 0.4, 0.28), "quake", 26, 2.2)
			Audio.play_at("quake", _telegraph_pos)
		"devourer_charge":
			_charging = true
			_charge_dir = aim
			_charge_time = a.duration
			Audio.play_at("charge", global_position)
		_:
			sys.execute(_pending, global_position + Vector3.UP * 2.4, aim)
			Fx.shake(0.25)
	_pending = ""

func _do_charge(delta: float) -> void:
	_charge_time -= delta
	velocity.x = _charge_dir.x * 22.0
	velocity.z = _charge_dir.z * 22.0
	Fx.burst(global_position + Vector3.UP * 0.4, Color(0.7, 0.3, 0.35), "dust", 5, 1.4)
	var p := Game.player
	if p != null and is_instance_valid(p) and global_position.distance_to(p.global_position) < 5.0:
		var h := Hit.make(26.0, self, "creature", global_position)
		h.knockback = 18.0
		h.color = Color(0.8, 0.3, 0.4)
		p.take_hit(h)
		_charge_time = minf(_charge_time, 0.1)
	if _charge_time <= 0.0 or global_position.distance_to(arena_center) > arena_radius:
		_charging = false
		_stun = 1.4                # the punish window
		velocity.x = 0.0
		velocity.z = 0.0
		Fx.shake(0.5)
		Fx.ring_flash(global_position, 6.0, Color(0.8, 0.35, 0.4), 0.5)

# --- phases -------------------------------------------------------------------

func _check_phase() -> void:
	var f := health / max_health
	if phase == 1 and f <= 0.66:
		_enter_phase_2()
	elif phase == 2 and f <= 0.33:
		_enter_phase_3()

func _enter_phase_2() -> void:
	phase = 2
	_stun = 1.2
	_pool.append("devourer_charge")
	_pool.append("corrupt_wave")
	Game.echo("boss_phase2")
	Sig.boss_phase_changed.emit(2)
	Fx.shake(0.7)
	Fx.ring_flash(global_position, 14.0, Color(0.9, 0.35, 0.45), 0.8)
	Audio.play("boss_phase", -1.0)
	# It calls things in and eats them, which is where its new organ comes from.
	var fodder := ["ember_mite", "spark_eel", "sporeling"]
	var pick: String = fodder[randi() % fodder.size()]
	var d := DB.get_creature(pick)
	if d == null:
		return
	for i in 2:
		var c := Creature.new()
		c.setup(d)
		get_parent().add_child(c)
		var a := TAU * randf()
		c.global_position = global_position + Vector3(sin(a) * 9.0, 1.0, cos(a) * 9.0)
		c.home = c.global_position
	await get_tree().create_timer(2.2).timeout
	if dead:
		return
	_consume_nearest()

func _consume_nearest() -> void:
	var best: Node3D = null
	var best_d := 22.0
	for c in get_tree().get_nodes_in_group("creature"):
		if c == self or not is_instance_valid(c) or c.get("dead") == true:
			continue
		var d := global_position.distance_to(c.global_position)
		if d < best_d:
			best_d = d
			best = c
	if best == null:
		_grow_trait("toxin_gland")
		return
	var species: CreatureData = best.data
	Fx.suck(best.global_position, global_position + Vector3(0, 4.0, 1.6), species.color_secondary, 22)
	Audio.play_at("devour", global_position, 2.0)
	health = minf(max_health, health + 60.0)
	Sig.boss_phase_changed.emit(phase)
	best.die(self)
	if species.trait_reward != "":
		_grow_trait(species.trait_reward)

func _enter_phase_3() -> void:
	phase = 3
	_stun = 1.6
	Game.echo("boss_phase3")
	Sig.boss_phase_changed.emit(3)
	Fx.shake(0.9)
	Audio.play("boss_phase", 0.0)
	Sig.echo_analysis.emit(["IT IS ANALYSING YOU.", "IT HAS COPIED YOUR ADAPTATIONS."])
	# The mirror: it takes what you are currently wearing.
	var mine: Array = Game.loadout.equipped.duplicate()
	mine.shuffle()
	var taken := 0
	for id in mine:
		if taken >= 2:
			break
		var t := DB.get_trait(String(id))
		if t == null or t.active_ability == "":
			continue
		_grow_trait(String(id))
		taken += 1
	if taken == 0:
		_grow_trait("heat_gland")
	Fx.ring_flash(global_position, 16.0, Color(0.9, 0.4, 0.5), 0.9)

# --- damage -------------------------------------------------------------------

func take_hit(hit: Hit) -> void:
	if dead or hit.source == self or hit.team == "creature":
		return
	var amount := hit.damage
	if status.consume("mark"):
		amount *= maxf(status.power("mark"), 2.5)
	_damage(amount, hit.source, hit.color)
	if hit.status != "":
		status.apply(hit.status, hit.status_power * 0.5, hit.status_time)

func _damage(amount: float, source: Node, color := Color.WHITE) -> void:
	if dead:
		return
	health -= amount
	if source == Game.player:
		Game.stats["damage_dealt"] = float(Game.stats["damage_dealt"]) + amount
		Fx.hit_stop(0.04)
		Fx.shake(0.1)
	Fx.damage_number(global_position + Vector3(randf_range(-2, 2), 5.0, randf_range(-1, 1)),
		amount, Palette.UI_WARN)
	Fx.burst(global_position + Vector3(randf_range(-2, 2), 3.5, randf_range(0, 2)), color, "impact", 8)
	Sig.boss_phase_changed.emit(phase)
	if health <= 0.0:
		die()
	else:
		_check_phase()

func apply_status(name: String, power: float, time: float) -> void:
	status.apply(name, power * 0.5, time)

func health_fraction() -> float:
	return clampf(health / max_health, 0.0, 1.0)

func die(_killer: Node = null) -> void:
	if dead:
		return
	dead = true
	health = 0.0
	remove_from_group("creature")
	Sig.boss_defeated.emit()
	Audio.play_music("evolution", 1.0)
	Fx.shake(1.0)
	for i in 10:
		Fx.burst(global_position + Vector3(randf_range(-4, 4), randf_range(1, 7), randf_range(-4, 4)),
			Color(0.9, 0.4, 0.45), "dissolve", 22, 2.0)
	var t := create_tween()
	t.tween_property(self, "scale", Vector3(1.1, 0.25, 1.1), 1.4).set_ease(Tween.EASE_IN)
	t.tween_callback(func(): Sig.request_state.emit("boss_devour", {}))
