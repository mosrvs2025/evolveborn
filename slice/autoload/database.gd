extends Node
## Loads every content Resource once and answers lookups. Also holds the tables
## that are relationships rather than rows: synergies, evolution forms, and the
## Echo's authored lines.

var traits: Dictionary = {}       # id -> TraitData
var abilities: Dictionary = {}    # id -> AbilityData
var creatures: Dictionary = {}    # id -> CreatureData

const BASE_CAPACITY := 8
const ESSENCE_TO_EVOLVE := 120

## A synergy is two traits that produce a third thing. The pair is the recipe;
## nothing is unlocked, bought or crafted.
const SYNERGIES := [
	{
		"id": "conductive_web", "display_name": "Conductive Web",
		"requires": ["electrical_organ", "web_gland"],
		"grants": "conductive_web", "slot": "secondary",
		"description": "Silk holds them in place and the charge travels the strands.",
		"color": Color(0.7, 0.95, 1.0),
	},
	{
		"id": "flame_breath", "display_name": "Flame Breath",
		"requires": ["heat_gland", "pressurized_sac"],
		"grants": "flame_breath", "slot": "secondary",
		"description": "Pressure behind the gland turns a burst into a sustained stream.",
		"color": Color(1.0, 0.5, 0.15),
	},
	{
		"id": "meteor_slam", "display_name": "Meteor Slam",
		"requires": ["chitin_armor", "power_legs"],
		"grants": "meteor_slam", "slot": "mobility",
		"description": "Leap, then bring every plate down at once.",
		"color": Color(1.0, 0.75, 0.35),
	},
	{
		"id": "plasma_arc", "display_name": "Plasma Arc",
		"requires": ["heat_gland", "electrical_organ"],
		"grants": "plasma_arc", "slot": "secondary",
		"description": "Heat rides the charge and stays behind in whatever it touched.",
		"color": Color(1.0, 0.7, 0.95),
	},
	{
		"id": "toxic_blood", "display_name": "Toxic Blood",
		"requires": ["regenerative_tissue", "toxin_gland"],
		"grants": "", "slot": "",
		"flags": {"retaliate_poison": 5.0},
		"description": "What keeps refilling you is not safe to spill. Attackers are poisoned.",
		"color": Color(0.6, 1.0, 0.5),
	},
	{
		"id": "void_stalk", "display_name": "Void Stalk",
		"requires": ["echo_sense", "shadow_membrane"],
		"grants": "", "slot": "",
		"flags": {"mark_crit": 2.5},
		"description": "Slip through a creature and it is marked. Your next strike opens it.",
		"color": Color(0.6, 0.5, 0.95),
	},
]

const EVOLUTIONS := [
	{
		"id": "predator", "display_name": "Predator Form",
		"tagline": "Faster, hungrier, and much worse to be near.",
		"modifiers": {"move_speed": 0.16, "damage_mult": 0.25, "devour_speed": 0.7,
			"max_health": 0.12, "core_capacity": 3.0},
		"color": Color(1.0, 0.45, 0.4),
		"lines": ["MUSCULATURE REORGANISING", "PREDATORY CONFIGURATION STABLE"],
	},
	{
		"id": "arcane", "display_name": "Arcane Form",
		"tagline": "The Core grows. Abilities land harder and return sooner.",
		"modifiers": {"ability_power": 0.45, "cooldown_mult": -0.3, "core_capacity": 5.0,
			"max_health": 0.05},
		"color": Color(0.6, 0.7, 1.0),
		"lines": ["CORE LATTICE EXPANDING", "CAPACITY EXCEEDS PREVIOUS ESTIMATE"],
	},
	{
		"id": "bulwark", "display_name": "Bulwark Form",
		"tagline": "Mass, plate and stubbornness. Very little moves you.",
		"modifiers": {"max_health": 0.55, "phys_resist": 0.15, "knockback_resist": 0.9,
			"core_capacity": 3.0, "move_speed": -0.05},
		"color": Color(0.95, 0.8, 0.45),
		"lines": ["DENSITY INCREASING", "STRUCTURAL CONFIGURATION STABLE"],
	},
]

## Authored Echo dialogue. Keys are fired by systems; `once` lines are recorded
## in the save so a second playthrough is not a second tutorial.
const ECHO_LINES := {
	"boot": ["YOU ARE AWAKE.", "I AM THE ECHO. I ANALYSE WHAT YOU CONSUME."],
	"first_move": ["LOCOMOTION FUNCTIONAL."],
	"first_creature": ["UNKNOWN ORGANISM DETECTED.", "IT IS LARGER THAN YOU. THIS IS NOT UNUSUAL."],
	"first_kill": ["THE ORGANISM HAS STOPPED.", "ITS STRUCTURE IS STILL INTACT."],
	"first_devour_prompt": ["BIOLOGICAL STRUCTURE AVAILABLE FOR ANALYSIS."],
	"first_devour": ["ANALYSING...", "TRAIT EXTRACTED.", "IT IS YOURS TO CARRY, IF YOU HAVE ROOM."],
	"first_capacity_block": ["CORE CAPACITY INSUFFICIENT.", "REMOVE SOMETHING, OR STAY AS YOU ARE."],
	"first_pool": ["MEMORY POOL. THE HOLLOW REMEMBERS YOU HERE.", "RECONFIGURE FREELY."],
	"grotto": ["ATMOSPHERIC TOXIN LEVELS RISING.", "SOMETHING HERE EATS WHAT THE SPORES KILL."],
	"ruins": ["THESE STRUCTURES WERE BUILT.", "NOT BY ANYTHING STILL LIVING HERE."],
	"basin": ["MULTIPLE SPECIES. ACTIVE PREDATION.", "THEY ARE NOT WAITING FOR YOU. CHOOSE."],
	"nest": ["THE ECOSYSTEM ENDS HERE.", "SOMETHING HAS BEEN CONSUMING IT."],
	"boss_intro": ["IT HAS TRAITS FROM EVERY SPECIES IN THE HOLLOW.", "IT DID WHAT YOU ARE DOING. FOR LONGER."],
	"boss_phase2": ["IT IS FEEDING MID-COMBAT.", "NEW STRUCTURE FORMING."],
	"boss_phase3": ["IT IS ANALYSING YOU.", "IT HAS COPIED YOUR ADAPTATIONS."],
	"boss_done": ["CONSUMING FRAGMENT.", "PRIMORDIAL CORE ACQUIRED."],
	"boss_stall": ["CORE CAPACITY INSUFFICIENT.", "EVOLUTION PATH UNKNOWN."],
	"ending_1": ["MULTIPLE UNKNOWN LIFE FORMS DETECTED."],
	"ending_2": ["INTELLIGENT CIVILIZATION DETECTED."],
	"ending_3": ["ANALYSIS IMPOSSIBLE AT CURRENT RANGE."],
	"evolution_ready": ["SUFFICIENT ESSENCE.", "AT THE NEXT MEMORY POOL YOU MAY RESTRUCTURE."],
	"low_health": ["STRUCTURAL INTEGRITY CRITICAL."],
	"death": ["COHESION LOST.", "THE POOL REMEMBERS. BEGIN AGAIN."],
}

func _ready() -> void:
	traits = _load_dir("res://data/traits/")
	abilities = _load_dir("res://data/abilities/")
	creatures = _load_dir("res://data/creatures/")

func _load_dir(path: String) -> Dictionary:
	var out := {}
	var d := DirAccess.open(path)
	if d == null:
		push_error("EVOLVEBORN: missing data directory " + path)
		return out
	d.list_dir_begin()
	var fn := d.get_next()
	while fn != "":
		if not d.current_is_dir():
			var clean := fn.replace(".remap", "")
			if clean.get_extension() == "tres":
				var res = load(path + clean)
				if res != null and res.get("id") != null:
					out[res.id] = res
		fn = d.get_next()
	d.list_dir_end()
	return out

# --- lookups ------------------------------------------------------------------

func get_trait(id: String) -> TraitData:
	return traits.get(id)

func get_ability(id: String) -> AbilityData:
	return abilities.get(id)

func get_creature(id: String) -> CreatureData:
	return creatures.get(id)

func trait_ids() -> Array:
	var keys := traits.keys()
	keys.sort()
	return keys

func synergy(id: String) -> Dictionary:
	for s in SYNERGIES:
		if s.id == id:
			return s
	return {}

func evolution(id: String) -> Dictionary:
	for e in EVOLUTIONS:
		if e.id == id:
			return e
	return {}

## Which synergies a given set of equipped trait ids satisfies.
func synergies_for(equipped: Array) -> Array:
	var out: Array = []
	for s in SYNERGIES:
		var ok := true
		for req in s.requires:
			if not equipped.has(req):
				ok = false
				break
		if ok:
			out.append(s)
	return out

func echo(key: String) -> Array:
	return ECHO_LINES.get(key, [])
