extends Node3D
class_name Corpse
## What a creature leaves behind, and the most polished five seconds in the game.
##
## The body persists, glows faintly, and can be analysed. Holding Devour pulls
## it apart into the player; the Echo reports what came out of it.

const LIFETIME := 50.0

var data: CreatureData
var body: Node3D
var progress := 0.0
var _life := LIFETIME
var _pulse := 0.0
var _consumed := false
var _base_scale := Vector3.ONE
var _glow: MeshInstance3D

func setup(p_data: CreatureData, p_visuals: Node3D) -> void:
	data = p_data
	# The corpse IS the creature's body, moved across rather than re-built.
	body = p_visuals
	if body.get_parent() != null:
		body.get_parent().remove_child(body)

func _ready() -> void:
	add_to_group("devourable")
	add_child(body)
	_base_scale = body.scale
	body.set_process(false)
	if body.has_method("set_hidden"):
		body.set_hidden(0.0)
	# It sags: a dead thing should not stand the way a live one did.
	var t := create_tween()
	t.tween_property(body, "scale", _base_scale * Vector3(1.08, 0.72, 1.08), 0.45).set_ease(Tween.EASE_OUT)
	t.tween_property(body, "rotation:x", 0.22, 0.35)
	_glow = MeshLib.glow_dot(0.22, data.color_secondary, Vector3(0, 0.75, 0))
	var m: StandardMaterial3D = _glow.material_override.duplicate()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_glow.material_override = m
	add_child(_glow)
	Game.echo("first_devour_prompt")

func _process(delta: float) -> void:
	_pulse += delta
	_life -= delta
	if _glow != null:
		var near := 1.0
		if Game.player != null and is_instance_valid(Game.player):
			near = clampf(1.6 - global_position.distance_to(Game.player.global_position) / 5.0, 0.35, 1.6)
		_glow.scale = Vector3.ONE * (0.44 + sin(_pulse * 2.6) * 0.06) * near
		_glow.position.y = 0.75 + sin(_pulse * 1.5) * 0.08
	if _life <= 0.0 and not _consumed:
		_fade_out()

func interact_prompt() -> String:
	return "DEVOUR"

## Called continuously while the player holds the action: the body comes apart
## in proportion to how far through the analysis they are.
func set_devour_progress(p: float) -> void:
	progress = clampf(p, 0.0, 1.0)
	if body == null or _consumed:
		return
	body.scale = _base_scale * Vector3(1.08 - progress * 0.55, 0.72 - progress * 0.35, 1.08 - progress * 0.55)
	body.position.y = progress * 0.7
	body.rotation.y += progress * 0.12
	if body.has_method("set_hidden"):
		body.set_hidden(progress * 0.7)
	if _glow != null:
		_glow.scale = Vector3.ONE * (0.44 + progress * 1.4)

func devour(player: Node) -> void:
	if _consumed:
		return
	_consumed = true
	remove_from_group("devourable")
	Game.stats["devoured"] = int(Game.stats["devoured"]) + 1
	Game.note_species(data.id)
	var essence := data.essence_reward
	var lines: Array = ["ANALYSING..."]
	var trait_id := data.trait_reward
	var t := DB.get_trait(trait_id) if trait_id != "" else null
	var is_new := t != null and not Game.loadout.discovered.has(trait_id)
	if is_new:
		Game.discover_trait(trait_id)
		essence += 12
		lines.append("BIOLOGICAL STRUCTURE IDENTIFIED")
		lines.append("TRAIT ACQUIRED: " + t.display_name.to_upper())
		for k in t.stat_modifiers.keys():
			lines.append(_describe_modifier(String(k), float(t.stat_modifiers[k])))
		if t.active_ability != "":
			var a := DB.get_ability(t.active_ability)
			if a != null:
				lines.append("%s ABILITY: %s" % [String(t.ability_slot).to_upper(), a.display_name.to_upper()])
		lines.append("CORE COST: %d" % t.core_cost)
		# Integrate it straight away when there is room. Having to open a menu
		# before feeling the new organ would waste the moment.
		if Game.loadout.can_equip(trait_id):
			Game.loadout.equip(trait_id)
			Sig.loadout_changed.emit()
			Game.check_synergies()
			lines.append("INTEGRATED.")
		else:
			lines.append("CORE CAPACITY INSUFFICIENT. STORED.")
			Game.echo("first_capacity_block")
	elif t != null:
		lines.append("STRUCTURE ALREADY CATALOGUED")
		lines.append("ESSENCE RECLAIMED")
	else:
		lines.append("NO VIABLE ADAPTATION")
		lines.append("ESSENCE RECLAIMED")
	Game.add_essence(essence)
	Sig.creature_devoured.emit(data.id, trait_id if is_new else "")
	Sig.echo_analysis.emit(lines)
	Game.echo("first_devour")
	_consume_effect(player, is_new)

func _consume_effect(player: Node, is_new: bool) -> void:
	var col: Color = data.color_secondary
	Audio.play_at("devour", global_position, 1.0)
	if is_new:
		Audio.play("trait_gain", -2.0)
	Fx.shake(0.28 if is_new else 0.16)
	Fx.hit_stop(0.05)
	var to: Vector3 = player.global_position + Vector3.UP * 0.6 if is_instance_valid(player) else global_position
	for i in 5:
		Fx.suck(global_position + Vector3(randf_range(-0.7, 0.7), randf_range(0.2, 1.2), randf_range(-0.7, 0.7)),
			to, Palette.ESSENCE if not is_new else col, 8)
	Fx.burst(global_position + Vector3.UP * 0.6, col, "dissolve", 26, 1.3)
	Fx.ring_flash(global_position, 2.6, col, 0.5)
	if _glow != null:
		_glow.visible = false
	var t := create_tween().set_parallel(true)
	t.tween_property(body, "scale", Vector3.ONE * 0.02, 0.32).set_ease(Tween.EASE_IN)
	t.tween_property(body, "position:y", 1.3, 0.32)
	t.chain().tween_callback(queue_free)

func _fade_out() -> void:
	_consumed = true
	remove_from_group("devourable")
	Fx.burst(global_position + Vector3.UP * 0.4, data.color_primary, "dissolve", 10)
	var t := create_tween()
	t.tween_property(body, "scale", Vector3.ONE * 0.02, 0.6)
	t.tween_callback(queue_free)

static func _describe_modifier(key: String, value: float) -> String:
	var pct := int(round(absf(value) * 100.0))
	var sign_s := "+" if value > 0.0 else "-"
	match key:
		"phys_resist": return "PHYSICAL RESISTANCE %s%d%%" % [sign_s, pct]
		"max_health": return "STRUCTURAL MASS %s%d%%" % [sign_s, pct]
		"move_speed": return "LOCOMOTION %s%d%%" % [sign_s, pct]
		"regen": return "TISSUE RECOVERY +%.1f/S" % value
		"knockback_resist": return "STABILITY %s%d%%" % [sign_s, pct]
		"ability_power": return "ABILITY YIELD %s%d%%" % [sign_s, pct]
		"air_control": return "AERIAL CONTROL %s%d%%" % [sign_s, pct]
		"dodge_iframes": return "EVASION WINDOW +%.2fS" % value
		"detect_range": return "SENSORY RANGE %s%d%%" % [sign_s, pct]
		"essence_mult": return "ESSENCE YIELD %s%d%%" % [sign_s, pct]
		"assist": return "STRIKE TRACKING %s%d%%" % [sign_s, pct]
		"knockback": return "IMPACT FORCE %s%d%%" % [sign_s, pct]
		"cooldown_mult": return "RECOVERY %s%d%%" % ["-" if value < 0.0 else "+", pct]
		_: return "%s %s%d%%" % [key.to_upper().replace("_", " "), sign_s, pct]
