extends RefCounted
class_name Loadout
## The player's body, as data. What is discovered, what is currently integrated,
## what that costs, which abilities it grafts onto which control, and which
## synergies fall out of the combination.
##
## Nothing here knows about nodes. The player, the HUD and the body menu all
## read the same three functions, which is why equipping a trait changes stats,
## controls and appearance in one step.

const BASE := {
	"max_health": 100.0,
	"move_speed": 6.2,
	"air_control": 0.38,
	"jump_power": 7.6,
	"devour_time": 1.15,
}

var discovered: Array[String] = []
var equipped: Array[String] = []
var builds: Array = [{}, {}, {}]
var evolution: String = ""
var extra_capacity: int = 0          ## from the Primordial Core, post-boss

# --- capacity -----------------------------------------------------------------

func capacity() -> int:
	var cap := DB.BASE_CAPACITY + extra_capacity
	var evo := DB.evolution(evolution)
	if not evo.is_empty():
		cap += int(evo.modifiers.get("core_capacity", 0.0))
	return cap

func used_capacity() -> int:
	var used := 0
	for id in equipped:
		var t := DB.get_trait(id)
		if t != null:
			used += t.core_cost
	return used

func free_capacity() -> int:
	return capacity() - used_capacity()

func can_equip(id: String) -> bool:
	if equipped.has(id) or not discovered.has(id):
		return false
	var t := DB.get_trait(id)
	return t != null and t.core_cost <= free_capacity()

# --- mutation -----------------------------------------------------------------

func discover(id: String) -> bool:
	if discovered.has(id) or DB.get_trait(id) == null:
		return false
	discovered.append(id)
	return true

func equip(id: String) -> bool:
	if not can_equip(id):
		return false
	equipped.append(id)
	return true

func unequip(id: String) -> bool:
	var i := equipped.find(id)
	if i < 0:
		return false
	equipped.remove_at(i)
	return true

func toggle(id: String) -> bool:
	if equipped.has(id):
		return unequip(id)
	return equip(id)

func clear_equipped() -> void:
	equipped.clear()

# --- derived numbers ----------------------------------------------------------

## Summed modifiers from every equipped trait plus the chosen evolution.
func modifiers() -> Dictionary:
	var mods := {}
	for id in equipped:
		var t := DB.get_trait(id)
		if t == null:
			continue
		for k in t.stat_modifiers.keys():
			mods[k] = float(mods.get(k, 0.0)) + float(t.stat_modifiers[k])
	var evo := DB.evolution(evolution)
	if not evo.is_empty():
		for k in evo.modifiers.keys():
			mods[k] = float(mods.get(k, 0.0)) + float(evo.modifiers[k])
	return mods

func stats() -> Dictionary:
	var m := modifiers()
	return {
		"max_health": BASE.max_health * (1.0 + float(m.get("max_health", 0.0))),
		"move_speed": BASE.move_speed * (1.0 + float(m.get("move_speed", 0.0))),
		"damage_mult": 1.0 + float(m.get("damage_mult", 0.0)),
		"ability_power": 1.0 + float(m.get("ability_power", 0.0)),
		"cooldown_mult": clampf(1.0 + float(m.get("cooldown_mult", 0.0)), 0.35, 2.0),
		"phys_resist": clampf(float(m.get("phys_resist", 0.0)), 0.0, 0.8),
		"knockback_resist": clampf(float(m.get("knockback_resist", 0.0)), 0.0, 0.92),
		"regen": float(m.get("regen", 0.0)),
		"air_control": BASE.air_control + float(m.get("air_control", 0.0)),
		"jump_power": BASE.jump_power * (1.0 + float(m.get("jump_power", 0.0))),
		"dodge_iframes": float(m.get("dodge_iframes", 0.0)),
		"devour_time": BASE.devour_time / (1.0 + float(m.get("devour_speed", 0.0))),
		"essence_mult": 1.0 + float(m.get("essence_mult", 0.0)),
		"detect_range": float(m.get("detect_range", 0.0)),
		"assist": float(m.get("assist", 0.0)),
		"knockback": 1.0 + float(m.get("knockback", 0.0)),
	}

## Which ability sits on each control right now. Later entries win, and a
## synergy always wins over the traits that produced it.
func abilities() -> Dictionary:
	var slots := {"primary": "body_slam", "secondary": "", "mobility": "burst"}
	for id in equipped:
		var t := DB.get_trait(id)
		if t == null or t.active_ability == "":
			continue
		slots[t.ability_slot] = t.active_ability
	for s in active_synergies():
		if String(s.get("grants", "")) != "":
			slots[String(s.slot)] = String(s.grants)
	return slots

func active_synergies() -> Array:
	return DB.synergies_for(equipped)

## Behavioural switches (on-hit status, retaliation, reveal) merged from traits
## and synergies. Systems ask for a key instead of checking trait ids.
func flags() -> Dictionary:
	var f := {}
	for id in equipped:
		var t := DB.get_trait(id)
		if t == null:
			continue
		for k in t.flags.keys():
			f[k] = t.flags[k]
	for s in active_synergies():
		for k in s.get("flags", {}).keys():
			f[k] = s.flags[k]
	return f

func mutations() -> Array[String]:
	var out: Array[String] = []
	for id in equipped:
		var t := DB.get_trait(id)
		if t != null and t.visual_mutation != "":
			out.append(t.visual_mutation)
	return out

# --- quick-swap builds --------------------------------------------------------

func save_build(slot: int, label := "") -> void:
	if slot < 0 or slot >= builds.size():
		return
	builds[slot] = {"label": label, "traits": equipped.duplicate()}

## Only applies if every trait in the build is still discovered and it fits.
func load_build(slot: int) -> bool:
	if slot < 0 or slot >= builds.size():
		return false
	var b: Dictionary = builds[slot]
	var want: Array = b.get("traits", [])
	if want.is_empty():
		return false
	var before := equipped.duplicate()
	equipped.clear()
	for id in want:
		if not equip(String(id)):
			equipped = before
			return false
	return true

func build_label(slot: int) -> String:
	if slot < 0 or slot >= builds.size():
		return ""
	return String(builds[slot].get("label", ""))

func build_is_empty(slot: int) -> bool:
	return builds[slot].get("traits", []).is_empty()

# --- persistence --------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"discovered": discovered.duplicate(),
		"equipped": equipped.duplicate(),
		"builds": builds.duplicate(true),
		"evolution": evolution,
		"extra_capacity": extra_capacity,
	}

func from_dict(d: Dictionary) -> void:
	discovered.clear()
	for v in d.get("discovered", []):
		discovered.append(String(v))
	equipped.clear()
	for v in d.get("equipped", []):
		equipped.append(String(v))
	var b = d.get("builds", [{}, {}, {}])
	if typeof(b) == TYPE_ARRAY and b.size() == 3:
		builds = b
	evolution = String(d.get("evolution", ""))
	extra_capacity = int(d.get("extra_capacity", 0))
