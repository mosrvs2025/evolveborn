extends Node
## Local save. Browser builds get this for free: Godot maps `user://` onto
## IndexedDB, so nothing here needs an account, a server or a network call.

const PATH := "user://evolveborn_save.json"
const VERSION := 1

var data: Dictionary = {}

func _ready() -> void:
	data = default_data()
	load_game()

func default_data() -> Dictionary:
	return {
		"version": VERSION,
		"has_run": false,
		"checkpoint": "",             # memory pool id
		"region": "awakening_cavern",
		"discovered_traits": [],
		"equipped": [],
		"builds": [{}, {}, {}],       # three quick-swap configurations
		"evolution": "",
		"essence": 0,
		"species_seen": [],
		"synergies": [],
		"secrets": [],
		"stats": {},
		"best_time": 0.0,
		"completed": false,
		"echo_seen": [],
		"endless": false,
	}

func load_game() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	if int(parsed.get("version", 0)) != VERSION:
		# Nothing to migrate yet; keep the records that survive any shape change.
		var fresh := default_data()
		fresh["best_time"] = float(parsed.get("best_time", 0.0))
		fresh["completed"] = bool(parsed.get("completed", false))
		data = fresh
		return
	var base := default_data()
	for k in parsed.keys():
		base[k] = parsed[k]
	data = base

func save_game() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		push_warning("EVOLVEBORN: could not open save for writing")
		return
	f.store_string(JSON.stringify(data))
	f.close()

func has_run() -> bool:
	return bool(data.get("has_run", false))

func clear() -> void:
	data = default_data()
	save_game()

func record_best_time(seconds: float) -> bool:
	var best := float(data.get("best_time", 0.0))
	if best <= 0.0 or seconds < best:
		data["best_time"] = seconds
		save_game()
		return true
	return false

## The Echo only says each authored line once per save unless it is marked
## repeatable, which is what keeps the tutorial from nagging on replays.
func echo_was_seen(key: String) -> bool:
	return data.get("echo_seen", []).has(key)

func mark_echo_seen(key: String) -> void:
	var seen: Array = data.get("echo_seen", [])
	if not seen.has(key):
		seen.append(key)
		data["echo_seen"] = seen
