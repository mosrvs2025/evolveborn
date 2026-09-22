extends Node
## Every gameplay input goes through an InputMap action defined here, so the
## same code path serves WASD+mouse, the arrow-cluster one-hand layout, a
## gamepad and the touch HUD. Nothing in the game reads a physical key.
##
## By default ALL schemes are live at once (blended preset): a player can put a
## hand on the arrows mid-fight without visiting a menu. The single-scheme
## presets exist for people who want a clean map to rebind from.

const PATH := "user://evolveborn_bindings.json"

const GAMEPLAY_ACTIONS := [
	"move_forward", "move_back", "move_left", "move_right",
	"look_left", "look_right", "look_up", "look_down",
	"act_primary", "act_secondary", "act_mobility",
	"act_devour", "act_target", "menu_body", "menu_pause",
]

const ACTION_LABELS := {
	"move_forward": "Move forward", "move_back": "Move back",
	"move_left": "Move left", "move_right": "Move right",
	"look_left": "Camera left", "look_right": "Camera right",
	"look_up": "Camera up", "look_down": "Camera down",
	"act_primary": "Primary action", "act_secondary": "Secondary ability",
	"act_mobility": "Mobility", "act_devour": "Devour / interact",
	"act_target": "Recenter / focus", "menu_body": "Body menu",
	"menu_pause": "Pause",
}

# Binding shorthand: "k:KEY_W"  "m:1"  "jb:0"  "ja:4+"
const PRESETS := {
	"standard": {
		"move_forward": ["k:W"], "move_back": ["k:S"],
		"move_left": ["k:A"], "move_right": ["k:D"],
		"look_left": [], "look_right": [],
		"look_up": [], "look_down": [],
		"act_primary": ["m:1"], "act_secondary": ["m:2"],
		"act_mobility": ["k:Space"], "act_devour": ["k:E"],
		"act_target": ["k:Q"], "menu_body": ["k:Tab"], "menu_pause": ["k:Escape"],
	},
	"one_hand": {
		"move_forward": ["k:Up"], "move_back": ["k:Down"],
		"move_left": ["k:Left"], "move_right": ["k:Right"],
		"look_left": ["k:Comma"], "look_right": ["k:Slash"],
		"look_up": [], "look_down": [],
		"act_primary": ["k:0", "k:Kp 0"], "act_secondary": ["k:Enter", "k:Kp Enter"],
		"act_mobility": ["k:Space", "k:Shift"], "act_devour": ["k:Ctrl", "k:Backslash"],
		"act_target": ["k:Period", "k:Kp Period"],
		"menu_body": ["k:Minus"], "menu_pause": ["k:Escape"],
	},
	"controller": {
		"move_forward": ["ja:1-"], "move_back": ["ja:1+"],
		"move_left": ["ja:0-"], "move_right": ["ja:0+"],
		"look_left": ["ja:2-"], "look_right": ["ja:2+"],
		"look_up": ["ja:3-"], "look_down": ["ja:3+"],
		"act_primary": ["jb:2"], "act_secondary": ["jb:3"],
		"act_mobility": ["jb:0"], "act_devour": ["jb:1"],
		"act_target": ["ja:4+", "jb:9"], "menu_body": ["jb:10"], "menu_pause": ["jb:6"],
	},
}

## Shown in prompts when the player is on a gamepad.
const PAD_GLYPHS := {
	0: "A", 1: "B", 2: "X", 3: "Y", 4: "Back", 6: "Menu",
	9: "LB", 10: "RB", 11: "D-Up", 12: "D-Down", 13: "D-Left", 14: "D-Right",
}

var preset: String = "blended"
var custom: Dictionary = {}          # action -> Array[String] of shorthand
var device: String = "keyboard"      # keyboard / mouse / gamepad / touch
var _last_pad_check := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_bindings()
	rebuild()
	_extend_ui_actions()

# --- building the map ---------------------------------------------------------

func rebuild() -> void:
	for a in GAMEPLAY_ACTIONS:
		if not InputMap.has_action(a):
			InputMap.add_action(a, 0.22)
		InputMap.action_erase_events(a)
	var sources: Array = []
	match preset:
		"blended": sources = ["standard", "one_hand", "controller"]
		"touch": sources = ["standard", "one_hand", "controller"]
		_: sources = [preset]
	for src in sources:
		var table: Dictionary = PRESETS.get(src, {})
		for action in table.keys():
			for short in table[action]:
				_add(action, short)
	# Custom rebinds replace whatever the preset gave that action.
	for action in custom.keys():
		if not InputMap.has_action(action):
			continue
		InputMap.action_erase_events(action)
		for short in custom[action]:
			_add(action, short)

func _add(action: String, short: String) -> void:
	var ev := shorthand_to_event(short)
	if ev == null:
		return
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.22)
	if not InputMap.action_has_event(action, ev):
		InputMap.action_add_event(action, ev)

func _extend_ui_actions() -> void:
	# Menus must take WASD, arrows, gamepad and the one-hand cluster alike.
	var extra := {
		"ui_up": ["k:W", "ja:1-", "jb:11"],
		"ui_down": ["k:S", "ja:1+", "jb:12"],
		"ui_left": ["k:A", "ja:0-", "jb:13"],
		"ui_right": ["k:D", "ja:0+", "jb:14"],
		"ui_accept": ["k:E", "k:Kp 0", "k:0", "jb:0"],
		"ui_cancel": ["jb:1", "k:Backspace"],
	}
	for action in extra.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for short in extra[action]:
			_add(action, short)

# --- shorthand <-> event ------------------------------------------------------

func shorthand_to_event(short: String) -> InputEvent:
	var parts := short.split(":", true, 1)
	if parts.size() != 2:
		return null
	match parts[0]:
		"k":
			var code := OS.find_keycode_from_string(parts[1])
			if code == 0:
				return null
			var ev := InputEventKey.new()
			ev.physical_keycode = code
			return ev
		"m":
			var ev2 := InputEventMouseButton.new()
			ev2.button_index = int(parts[1])
			return ev2
		"jb":
			var ev3 := InputEventJoypadButton.new()
			ev3.button_index = int(parts[1])
			return ev3
		"ja":
			var body := parts[1]
			var sign_char := body.substr(body.length() - 1, 1)
			var ev4 := InputEventJoypadMotion.new()
			ev4.axis = int(body.substr(0, body.length() - 1))
			ev4.axis_value = 1.0 if sign_char == "+" else -1.0
			return ev4
	return null

func event_to_shorthand(ev: InputEvent) -> String:
	if ev is InputEventKey:
		var code: int = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
		return "k:" + OS.get_keycode_string(code)
	if ev is InputEventMouseButton:
		return "m:%d" % ev.button_index
	if ev is InputEventJoypadButton:
		return "jb:%d" % ev.button_index
	if ev is InputEventJoypadMotion:
		return "ja:%d%s" % [ev.axis, "+" if ev.axis_value > 0.0 else "-"]
	return ""

# --- prompts ------------------------------------------------------------------

## Short label for the action on whatever the player last touched.
func prompt_for(action: String) -> String:
	if device == "touch":
		return ""
	var events := InputMap.action_get_events(action)
	# Every gameplay action carries several bindings at once in the blended
	# preset, so the prompt shows the one belonging to the device in the
	# player's hands right now, and falls back to any other only if that device
	# has no binding for this action.
	var exact := _glyph(events, device)
	if exact != "":
		return exact
	for fallback in ["keyboard", "mouse", "gamepad"]:
		if fallback == device:
			continue
		var g := _glyph(events, fallback)
		if g != "":
			return g
	return ""

func _glyph(events: Array, want: String) -> String:
	for ev in events:
		match want:
			"gamepad":
				if ev is InputEventJoypadButton:
					return PAD_GLYPHS.get(ev.button_index, "Pad %d" % ev.button_index)
				if ev is InputEventJoypadMotion:
					return "LT" if ev.axis == 4 else "Stick"
			"mouse":
				if ev is InputEventMouseButton:
					return "LMB" if ev.button_index == 1 else "RMB"
			"keyboard":
				if ev is InputEventKey:
					return _pretty_key(OS.get_keycode_string(ev.physical_keycode))
	return ""

func _pretty_key(s: String) -> String:
	match s:
		"Escape": return "Esc"
		"Kp 0": return "Num 0"
		"Kp Enter": return "Num Enter"
		"Kp Period": return "Num ."
		"Period": return "."
		"Comma": return ","
		"Slash": return "/"
		"Backslash": return "\\"
		"Minus": return "-"
		"Ctrl": return "Ctrl"
		"Shift": return "Shift"
		"Space": return "Space"
		_: return s

# --- device tracking ----------------------------------------------------------

func _input(ev: InputEvent) -> void:
	var d := device
	if ev is InputEventKey:
		d = "keyboard"
	elif ev is InputEventMouseButton or (ev is InputEventMouseMotion and ev.relative.length() > 1.0):
		d = "mouse"
	elif ev is InputEventJoypadButton:
		d = "gamepad"
	elif ev is InputEventJoypadMotion and absf(ev.axis_value) > 0.4:
		d = "gamepad"
	elif ev is InputEventScreenTouch or ev is InputEventScreenDrag:
		d = "touch"
	if d != device:
		device = d
		Sig.input_device_changed.emit(device)

func note_virtual_input() -> void:
	if device != "touch":
		device = "touch"
		Sig.input_device_changed.emit(device)

# --- remapping / persistence --------------------------------------------------

func set_preset(name: String) -> void:
	preset = name
	custom.clear()
	rebuild()
	save_bindings()

func rebind(action: String, ev: InputEvent) -> bool:
	var short := event_to_shorthand(ev)
	if short == "":
		return false
	custom[action] = [short]
	rebuild()
	save_bindings()
	return true

func clear_custom(action: String) -> void:
	custom.erase(action)
	rebuild()
	save_bindings()

func bindings_text(action: String) -> String:
	var out: Array[String] = []
	for ev in InputMap.action_get_events(action):
		var s := ""
		if ev is InputEventKey:
			s = _pretty_key(OS.get_keycode_string(ev.physical_keycode))
		elif ev is InputEventMouseButton:
			s = "LMB" if ev.button_index == 1 else "RMB"
		elif ev is InputEventJoypadButton:
			s = PAD_GLYPHS.get(ev.button_index, "Pad %d" % ev.button_index)
		elif ev is InputEventJoypadMotion:
			s = "Stick"
		if s != "" and not out.has(s):
			out.append(s)
	return ", ".join(out)

func save_bindings() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"preset": preset, "custom": custom}))
	f.close()

func _load_bindings() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(d) != TYPE_DICTIONARY:
		return
	preset = String(d.get("preset", "blended"))
	var c = d.get("custom", {})
	if typeof(c) == TYPE_DICTIONARY:
		custom = c

# --- convenience --------------------------------------------------------------

func move_vector() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back")

func look_vector() -> Vector2:
	return Input.get_vector("look_left", "look_right", "look_up", "look_down")
