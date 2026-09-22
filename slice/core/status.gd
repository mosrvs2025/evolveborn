extends RefCounted
class_name StatusSet
## Poison, burn, shock, root and mark, shared by the player and every creature.
## Statuses are stored as power-over-time, so "poisoned" is not a state flag
## with a hardcoded number attached; it is an amount and a duration.

var entries: Dictionary = {}      # name -> {"power": float, "time": float}

func apply(name: String, power: float, time: float) -> void:
	if name == "":
		return
	var cur: Dictionary = entries.get(name, {"power": 0.0, "time": 0.0})
	# Refreshing takes the stronger dose and the longer clock, never both stacked.
	entries[name] = {
		"power": maxf(float(cur.power), power),
		"time": maxf(float(cur.time), time),
	}

func has(name: String) -> bool:
	return entries.has(name)

func power(name: String) -> float:
	return float(entries.get(name, {}).get("power", 0.0))

func consume(name: String) -> bool:
	if entries.has(name):
		entries.erase(name)
		return true
	return false

func clear() -> void:
	entries.clear()

## Returns damage to apply this frame.
func tick(delta: float) -> float:
	var dmg := 0.0
	for name in entries.keys():
		var e: Dictionary = entries[name]
		e.time = float(e.time) - delta
		if name == "poison" or name == "burn":
			dmg += float(e.power) * delta
		elif name == "shock":
			dmg += float(e.power) * delta * 0.35
		if float(e.time) <= 0.0:
			entries.erase(name)
	return dmg

func speed_multiplier() -> float:
	var m := 1.0
	if has("root"):
		m = 0.0
	elif has("shock"):
		m *= 0.62
	elif has("burn"):
		m *= 0.94
	return m

func active_names() -> Array:
	return entries.keys()

func tint() -> Color:
	for n in ["root", "shock", "burn", "poison"]:
		if entries.has(n):
			return Palette.STATUS.get(n, Color.WHITE)
	return Color.WHITE
