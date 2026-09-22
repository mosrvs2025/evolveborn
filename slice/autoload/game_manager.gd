extends Node
## Run state and flow. Owns the loadout, the essence economy, the statistics the
## end screen reports, and which region is currently in memory.

enum State { BOOT, TITLE, PLAYING, PAUSED, MENU, DEAD, CUTSCENE, RESULTS }

const REGION_ORDER := ["awakening_cavern", "fungal_grotto", "sunken_ruins",
	"verdant_basin", "ancient_nest"]

var state: State = State.BOOT
var loadout: Loadout = Loadout.new()
var essence: int = 0
var run_time: float = 0.0
var current_region: String = ""
var checkpoint_region: String = "awakening_cavern"
var checkpoint_pool: String = ""
var endless: bool = false            ## set after the ending, for Continue Exploring
var evolution_pending: bool = false  ## essence threshold met, not yet spent

var world: Node3D = null             ## where regions are added
var player: Node3D = null
var region_node: Node = null

var species_seen: Array[String] = []
var synergies_found: Array[String] = []
var secrets_found: Array[String] = []
var stats := {
	"kills": 0, "devoured": 0, "deaths": 0, "damage_dealt": 0.0,
	"damage_taken": 0.0, "essence_total": 0, "distance": 0.0,
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	if state == State.PLAYING:
		run_time += delta

# --- run lifecycle ------------------------------------------------------------

func new_run() -> void:
	loadout = Loadout.new()
	essence = 0
	run_time = 0.0
	endless = false
	evolution_pending = false
	checkpoint_region = "awakening_cavern"
	checkpoint_pool = ""
	species_seen.clear()
	synergies_found.clear()
	secrets_found.clear()
	stats = {"kills": 0, "devoured": 0, "deaths": 0, "damage_dealt": 0.0,
		"damage_taken": 0.0, "essence_total": 0, "distance": 0.0}
	SaveMgr.data["has_run"] = true
	write_save()
	load_region("awakening_cavern", "entry")
	set_state(State.PLAYING)
	DebugTools.apply_run_overrides()

func continue_run() -> void:
	read_save()
	load_region(checkpoint_region, "pool:" + checkpoint_pool if checkpoint_pool != "" else "entry")
	set_state(State.PLAYING)

func quit_to_title() -> void:
	write_save()
	unload_region()
	set_state(State.TITLE)

func set_state(s: State) -> void:
	state = s
	var paused := s in [State.PAUSED, State.MENU, State.RESULTS, State.TITLE]
	get_tree().paused = paused
	Sig.request_state.emit(State.keys()[s].to_lower(), {})

func is_playing() -> bool:
	return state == State.PLAYING

# --- regions ------------------------------------------------------------------

func load_region(id: String, entry := "entry") -> void:
	if world == null:
		push_warning("EVOLVEBORN: no world node registered")
		return
	unload_region()
	current_region = id
	var region = load("res://world/region.gd").new()
	region.region_id = id
	region.entry_point = entry
	world.add_child(region)
	region_node = region
	Sig.region_entered.emit(id)

func unload_region() -> void:
	if region_node != null and is_instance_valid(region_node):
		region_node.queue_free()
	region_node = null
	player = null

func next_region() -> String:
	var i := REGION_ORDER.find(current_region)
	if i < 0 or i + 1 >= REGION_ORDER.size():
		return ""
	return REGION_ORDER[i + 1]

func region_index() -> int:
	return maxi(0, REGION_ORDER.find(current_region))

func travel(to_region: String, entry := "entry") -> void:
	if to_region == "":
		return
	write_save()
	load_region(to_region, entry)

# --- economy ------------------------------------------------------------------

func add_essence(amount: int) -> void:
	var gained := int(round(amount * float(loadout.stats()["essence_mult"])))
	essence += gained
	stats["essence_total"] = int(stats["essence_total"]) + gained
	Sig.essence_changed.emit(essence, DB.ESSENCE_TO_EVOLVE)
	if not evolution_pending and loadout.evolution == "" and essence >= DB.ESSENCE_TO_EVOLVE:
		evolution_pending = true
		Sig.evolution_available.emit()
		echo("evolution_ready")

func spend_evolution(form_id: String) -> void:
	loadout.evolution = form_id
	essence = maxi(0, essence - DB.ESSENCE_TO_EVOLVE)
	evolution_pending = false
	Sig.essence_changed.emit(essence, DB.ESSENCE_TO_EVOLVE)
	Sig.evolved.emit(form_id)
	write_save()

# --- discovery ----------------------------------------------------------------

func note_species(id: String) -> void:
	if not species_seen.has(id):
		species_seen.append(id)

func discover_trait(id: String) -> bool:
	if loadout.discover(id):
		Sig.trait_discovered.emit(id)
		return true
	return false

## Checks after every loadout change; the reveal is the reward for experimenting.
func check_synergies() -> void:
	for s in loadout.active_synergies():
		if not synergies_found.has(s.id):
			synergies_found.append(s.id)
			Sig.synergy_discovered.emit(s.id)

func note_secret(id: String) -> void:
	if secrets_found.has(id):
		return
	secrets_found.append(id)
	Sig.secret_found.emit(id)
	add_essence(25)

# --- checkpoints & death ------------------------------------------------------

func set_checkpoint(pool_id: String) -> void:
	checkpoint_region = current_region
	checkpoint_pool = pool_id
	write_save()
	Sig.memory_pool_reached.emit(pool_id)

func on_player_died() -> void:
	stats["deaths"] = int(stats["deaths"]) + 1
	set_state(State.DEAD)
	Sig.player_died.emit()
	echo("death")

func respawn() -> void:
	# Death costs time and position, never progression.
	var entry := "pool:" + checkpoint_pool if checkpoint_pool != "" else "entry"
	load_region(checkpoint_region, entry)
	set_state(State.PLAYING)
	Sig.player_respawned.emit()

# --- the Echo -----------------------------------------------------------------

## `once` lines are recorded in the save, so a replay is not a second tutorial.
func echo(key: String, once := true) -> void:
	if once and SaveMgr.echo_was_seen(key):
		return
	var lines := DB.echo(key)
	if lines.is_empty():
		return
	if once:
		SaveMgr.mark_echo_seen(key)
	Sig.echo_analysis.emit(lines)

# --- persistence --------------------------------------------------------------

func write_save() -> void:
	var d := SaveMgr.data
	var lo := loadout.to_dict()
	d["has_run"] = true
	d["region"] = current_region
	d["checkpoint"] = checkpoint_pool
	d["checkpoint_region"] = checkpoint_region
	d["discovered_traits"] = lo.discovered
	d["equipped"] = lo.equipped
	d["builds"] = lo.builds
	d["evolution"] = lo.evolution
	d["extra_capacity"] = lo.extra_capacity
	d["essence"] = essence
	d["species_seen"] = species_seen
	d["synergies"] = synergies_found
	d["secrets"] = secrets_found
	d["stats"] = stats
	d["run_time"] = run_time
	d["endless"] = endless
	SaveMgr.save_game()

func read_save() -> void:
	var d := SaveMgr.data
	loadout = Loadout.new()
	loadout.from_dict({
		"discovered": d.get("discovered_traits", []),
		"equipped": d.get("equipped", []),
		"builds": d.get("builds", [{}, {}, {}]),
		"evolution": d.get("evolution", ""),
		"extra_capacity": d.get("extra_capacity", 0),
	})
	essence = int(d.get("essence", 0))
	run_time = float(d.get("run_time", 0.0))
	checkpoint_region = String(d.get("checkpoint_region", d.get("region", "awakening_cavern")))
	checkpoint_pool = String(d.get("checkpoint", ""))
	endless = bool(d.get("endless", false))
	species_seen.assign(d.get("species_seen", []))
	synergies_found.assign(d.get("synergies", []))
	secrets_found.assign(d.get("secrets", []))
	var st = d.get("stats", {})
	if typeof(st) == TYPE_DICTIONARY:
		for k in st.keys():
			stats[k] = st[k]
	evolution_pending = loadout.evolution == "" and essence >= DB.ESSENCE_TO_EVOLVE

# --- ending -------------------------------------------------------------------

func finish_run() -> void:
	SaveMgr.data["completed"] = true
	var improved := SaveMgr.record_best_time(run_time)
	endless = true
	write_save()
	set_state(State.RESULTS)
	Sig.request_state.emit("results", {"best": improved})

func results_summary() -> Dictionary:
	return {
		"time": run_time,
		"best_time": float(SaveMgr.data.get("best_time", 0.0)),
		"kills": stats["kills"],
		"devoured": stats["devoured"],
		"species": species_seen.size(),
		"species_total": DB.creatures.size(),
		"traits": loadout.discovered.size(),
		"traits_total": DB.traits.size(),
		"synergies": synergies_found.size(),
		"synergies_total": DB.SYNERGIES.size(),
		"evolution": loadout.evolution,
		"deaths": stats["deaths"],
		"secrets": secrets_found.size(),
	}

static func format_time(seconds: float) -> String:
	var m := int(seconds) / 60
	var s := int(seconds) % 60
	return "%d:%02d" % [m, s]
