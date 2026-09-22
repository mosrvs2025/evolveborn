extends Node
class_name AbilitySystem
## Executes AbilityData by shape. The player and every creature share this, so a
## Spark Eel's discharge and the player's Arc Bolt are literally the same code
## reading different rows.

var actor: Node3D
var team: String = "player"
var power: float = 1.0             ## ability_power multiplier
var damage_mult: float = 1.0
var cooldown_mult: float = 1.0
var knockback_mult: float = 1.0
var on_hit_status: String = ""
var on_hit_power: float = 0.0
var on_hit_time: float = 0.0
var assist: float = 0.0            ## soft target assist strength, 0..1

var _cooldowns: Dictionary = {}

func _init(p_actor: Node3D, p_team: String) -> void:
	actor = p_actor
	team = p_team

func _process(delta: float) -> void:
	for k in _cooldowns.keys():
		_cooldowns[k] = maxf(0.0, float(_cooldowns[k]) - delta)

func ready_in(id: String) -> float:
	return float(_cooldowns.get(id, 0.0))

func is_ready(id: String) -> bool:
	return ready_in(id) <= 0.0

func cooldown_fraction(id: String) -> float:
	var a := DB.get_ability(id)
	if a == null or a.cooldown <= 0.0:
		return 0.0
	return clampf(ready_in(id) / (a.cooldown * cooldown_mult), 0.0, 1.0)

func start_cooldown(id: String) -> void:
	var a := DB.get_ability(id)
	if a != null:
		_cooldowns[id] = a.cooldown * cooldown_mult

# --- targets ------------------------------------------------------------------

func enemy_group() -> String:
	return "creature" if team == "player" else "player"

func enemies() -> Array:
	return actor.get_tree().get_nodes_in_group(enemy_group())

## Nudges a strike toward the nearest valid target inside a cone. It never turns
## the attack around; it only removes the pixel-hunting.
func apply_assist(origin: Vector3, dir: Vector3, reach: float) -> Vector3:
	if assist <= 0.01:
		return dir
	var best: Node3D = null
	var best_score := -1.0
	var max_turn := deg_to_rad(42.0 * assist)
	for e in enemies():
		if not is_instance_valid(e) or not e.has_method("take_hit"):
			continue
		if e.get("dead") == true:
			continue
		var to: Vector3 = e.global_position - origin
		to.y = 0.0
		var d := to.length()
		if d > reach * 1.45 or d < 0.05:
			continue
		var ang := dir.angle_to(to.normalized())
		if ang > max_turn:
			continue
		var score := (1.0 - ang / maxf(max_turn, 0.001)) * 0.7 + (1.0 - d / (reach * 1.45)) * 0.3
		if score > best_score:
			best_score = score
			best = e
	if best == null:
		return dir
	var want: Vector3 = (best.global_position - origin)
	want.y = 0.0
	return dir.slerp(want.normalized(), clampf(assist, 0.0, 1.0)).normalized()

# --- execution ----------------------------------------------------------------

## Returns a small dictionary the caller acts on for movement-shaped abilities
## (dash, lunge); everything else resolves here.
func execute(id: String, origin: Vector3, dir: Vector3) -> Dictionary:
	var a := DB.get_ability(id)
	if a == null or not is_ready(id):
		return {}
	start_cooldown(id)
	var aim := dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD
	if a.shape in ["melee_arc", "cone", "projectile", "web"]:
		aim = apply_assist(origin, aim, a.range)
	if a.sfx != "":
		Audio.play_varied(a.sfx, origin)
	var result := {"aim": aim}
	match a.shape:
		"melee_arc":
			_melee(a, origin, aim)
			if a.lunge > 0.0:
				result["lunge"] = {"dir": aim, "speed": a.lunge * 5.0, "time": 0.14}
		"cone":
			_cone(a, origin, aim)
		"aoe":
			_aoe(a, origin, a.radius)
		"projectile":
			_projectile(a, origin, aim)
		"web":
			_projectile(a, origin, aim)
		"dash":
			result["dash"] = {
				"dir": aim, "speed": a.speed, "time": a.duration,
				"iframes": a.iframes, "ability": a.id,
			}
		"beam":
			_cone(a, origin, aim)
	return result

func dmg(a: AbilityData) -> float:
	return a.damage * damage_mult * (power if a.shape != "melee_arc" else 1.0)

func _payload(a: AbilityData, pos: Vector3, amount := -1.0) -> Hit:
	var h := Hit.make(amount if amount >= 0.0 else dmg(a), actor, team, pos)
	h.knockback = a.knockback * knockback_mult
	h.color = a.color
	h.armor_pierce = float(a.flags.get("armor_pierce", 0.0))
	if a.status != "":
		h.with_status(a.status, a.status_power, a.status_time)
	elif on_hit_status != "":
		h.with_status(on_hit_status, on_hit_power, on_hit_time)
	return h

func _melee(a: AbilityData, origin: Vector3, aim: Vector3) -> void:
	var half := deg_to_rad(a.angle_deg) * 0.5
	var hit_any := false
	for e in enemies():
		if not _valid(e):
			continue
		var to: Vector3 = e.global_position - origin
		var reach: float = a.range + float(e.get("body_radius") if e.get("body_radius") != null else 0.5)
		to.y = 0.0
		if to.length() > reach or to.length() < 0.01:
			continue
		if aim.angle_to(to.normalized()) > half:
			continue
		e.take_hit(_payload(a, e.global_position))
		hit_any = true
	Fx.burst(origin + aim * a.range * 0.55 + Vector3.UP * 0.6, a.color, "impact", 10 if hit_any else 5)
	if bool(a.flags.get("shockwave", false)):
		_aoe(a, origin, a.radius, 0.45)
		Fx.ring_flash(origin, a.radius, a.color, 0.3)

func _cone(a: AbilityData, origin: Vector3, aim: Vector3) -> void:
	if a.duration > 0.0 and bool(a.flags.get("sustained", false)):
		var beam = load("res://abilities/cone_beam.gd").new()
		beam.setup(self, a, aim)
		actor.add_child(beam)
		return
	_cone_tick(a, origin, aim, 1.0)
	_cone_vfx(a, origin, aim)

func _cone_tick(a: AbilityData, origin: Vector3, aim: Vector3, scale := 1.0) -> void:
	var half := deg_to_rad(a.angle_deg) * 0.5
	for e in enemies():
		if not _valid(e):
			continue
		var to: Vector3 = e.global_position - origin
		to.y *= 0.5
		if to.length() > a.range or to.length() < 0.01:
			continue
		if aim.angle_to(to.normalized()) > half:
			continue
		e.take_hit(_payload(a, e.global_position, dmg(a) * scale))

func _cone_vfx(a: AbilityData, origin: Vector3, aim: Vector3) -> void:
	var steps := 4
	for i in steps:
		var t := float(i + 1) / float(steps)
		Fx.burst(origin + Vector3.UP * 0.7 + aim * a.range * t, a.color,
			"ember" if a.status == "burn" else "spark", 7, 0.8 + t)

func _aoe(a: AbilityData, origin: Vector3, radius: float, scale := 1.0) -> void:
	for e in enemies():
		if not _valid(e):
			continue
		var to: Vector3 = e.global_position - origin
		to.y *= 0.6
		if to.length() > radius:
			continue
		if bool(a.flags.get("ring", false)) and to.length() < radius * 0.45:
			continue
		e.take_hit(_payload(a, e.global_position, dmg(a) * scale))
	Fx.ring_flash(origin, radius, a.color, 0.34)
	Fx.burst(origin + Vector3.UP * 0.4, a.color, "quake", 18, 1.4)

func _projectile(a: AbilityData, origin: Vector3, aim: Vector3) -> void:
	var count := int(a.flags.get("volley", 1.0))
	var spread := deg_to_rad(float(a.flags.get("spread", 0.0)))
	for i in count:
		var d := aim
		if count > 1:
			var f := (float(i) / float(count - 1)) * 2.0 - 1.0
			d = aim.rotated(Vector3.UP, f * spread)
		var proj = load("res://abilities/projectile.gd").new()
		proj.setup(self, a, origin + Vector3.UP * 0.8 + d * 0.7, d)
		_world().add_child(proj)

func _world() -> Node:
	if Game.region_node != null and is_instance_valid(Game.region_node):
		return Game.region_node
	return actor.get_tree().current_scene

func _valid(e) -> bool:
	return is_instance_valid(e) and e.has_method("take_hit") and e.get("dead") != true
