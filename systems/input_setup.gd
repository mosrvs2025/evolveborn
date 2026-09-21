extends RefCounted

const KEYS = {
	"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
	"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN],
	"action_primary": [KEY_0, KEY_KP_0], "action_secondary": [KEY_ENTER, KEY_KP_ENTER],
	"mobility": [KEY_SPACE, KEY_SHIFT], "devour": [KEY_E, KEY_CTRL],
	"interact": [KEY_F], "target": [KEY_PERIOD], "body": [KEY_TAB], "pause": [KEY_ESCAPE]
}

static func setup():
	for action in KEYS:
		if not InputMap.has_action(action): InputMap.add_action(action, 0.2)
		for key in KEYS[action]:
			var event = InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
	for pair in [["action_primary", MOUSE_BUTTON_LEFT], ["action_secondary", MOUSE_BUTTON_RIGHT]]:
		var event = InputEventMouseButton.new()
		event.button_index = pair[1]
		InputMap.action_add_event(pair[0], event)
	for pair in [["action_primary",JOY_BUTTON_X],["action_secondary",JOY_BUTTON_Y],["mobility",JOY_BUTTON_A],["devour",JOY_BUTTON_B],["pause",JOY_BUTTON_START],["body",JOY_BUTTON_BACK],["target",JOY_BUTTON_LEFT_SHOULDER]]:
		var event = InputEventJoypadButton.new()
		event.button_index = pair[1]
		InputMap.action_add_event(pair[0], event)
	for pair in [["move_left",JOY_AXIS_LEFT_X,-1.0],["move_right",JOY_AXIS_LEFT_X,1.0],["move_forward",JOY_AXIS_LEFT_Y,-1.0],["move_back",JOY_AXIS_LEFT_Y,1.0]]:
		var event = InputEventJoypadMotion.new()
		event.axis = pair[1]
		event.axis_value = pair[2]
		InputMap.action_add_event(pair[0], event)

static func prompt(action: String, device: String) -> String:
	if device == "touch": return "HOLD" if action == "devour" else "TAP"
	if device == "controller":
		return {"devour":"B", "action_primary":"X", "action_secondary":"Y", "mobility":"A", "body":"VIEW", "pause":"MENU"}.get(action,"LB")
	for event in InputMap.action_get_events(action):
		if event is InputEventKey: return OS.get_keycode_string(event.physical_keycode)
	return "?"
