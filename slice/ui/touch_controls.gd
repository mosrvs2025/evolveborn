extends Control
## The mobile layout. Not desktop buttons over the screen: a forgiving floating
## stick on the left, large action buttons on the right, camera drag on the
## empty space between them, and Devour appearing only when there is something
## to devour.
##
## Everything here goes through Input.action_press, so touch drives exactly the
## same code path as a key or a gamepad button.

const DEAD_ZONE := 0.14

var _stick_finger := -1
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _look_finger := -1
var _look_last := Vector2.ZERO
var _button_fingers := {}         # finger index -> button id
var _pressed := {}                # action -> bool
var _buttons: Array = []
var _devour_visible := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = _should_show()
	Sig.input_device_changed.connect(func(_d): visible = _should_show())
	Sig.settings_changed.connect(func(): queue_redraw())
	Sig.prompt_changed.connect(func(text, _a):
		_devour_visible = text != ""
		queue_redraw())
	set_process(true)

func _should_show() -> bool:
	if OS.has_feature("editor") and not DisplayServer.is_touchscreen_available():
		return false
	return DisplayServer.is_touchscreen_available() or InputMgr.device == "touch"

func _process(_delta: float) -> void:
	if visible != _should_show():
		visible = _should_show()
	if visible:
		queue_redraw()

# --- layout -------------------------------------------------------------------

func _scale() -> float:
	return float(Settings.get_value("touch_size"))

func _layout() -> Array:
	var s := _scale()
	var rect := get_viewport_rect().size
	var r := 52.0 * s
	var margin := 34.0 * s
	var bx := rect.x - margin - r
	var by := rect.y - margin - r
	return [
		{"id": "primary", "action": "act_primary", "label": "STRIKE",
			"pos": Vector2(bx - r * 0.4, by - r * 0.4), "r": r * 1.25, "color": Palette.UI_ACCENT},
		{"id": "secondary", "action": "act_secondary", "label": "ABILITY",
			"pos": Vector2(bx - r * 2.4, by - r * 1.1), "r": r * 0.85, "color": Color(0.7, 0.85, 1.0)},
		{"id": "mobility", "action": "act_mobility", "label": "BURST",
			"pos": Vector2(bx - r * 0.8, by - r * 2.5), "r": r * 0.85, "color": Color(0.6, 1.0, 0.9)},
		{"id": "devour", "action": "act_devour", "label": "DEVOUR",
			"pos": Vector2(bx - r * 3.1, by - r * 2.9), "r": r * 1.0, "color": Palette.CORE,
			"only_with_prompt": true},
		{"id": "body", "action": "menu_body", "label": "BODY",
			"pos": Vector2(rect.x - margin - r * 0.5, margin + r * 0.5), "r": r * 0.62,
			"color": Palette.UI_DIM},
		{"id": "pause", "action": "menu_pause", "label": "II",
			"pos": Vector2(margin + r * 0.5, margin + r * 0.5), "r": r * 0.5,
			"color": Palette.UI_DIM},
	]

func _visible_buttons() -> Array:
	var out: Array = []
	for b in _layout():
		if bool(b.get("only_with_prompt", false)) and not _devour_visible:
			continue
		if b.id == "secondary" and String(Game.loadout.abilities().get("secondary", "")) == "":
			continue
		out.append(b)
	return out

# --- input --------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_on_press(event.index, event.position)
		else:
			_on_release(event.index)
		accept_event()
	elif event is InputEventScreenDrag:
		_on_drag(event.index, event.position, event.relative)
		accept_event()

func _on_press(index: int, pos: Vector2) -> void:
	InputMgr.note_virtual_input()
	for b in _visible_buttons():
		if pos.distance_to(b.pos) <= float(b.r) * 1.15:
			_button_fingers[index] = b
			_press(String(b.action))
			return
	var half := get_viewport_rect().size.x * 0.5
	if pos.x < half and _stick_finger < 0:
		_stick_finger = index
		_stick_origin = pos if bool(Settings.get_value("touch_stick_floating")) \
			else Vector2(160.0 * _scale(), get_viewport_rect().size.y - 160.0 * _scale())
		_stick_pos = pos
	elif _look_finger < 0:
		_look_finger = index
		_look_last = pos

func _on_drag(index: int, pos: Vector2, relative: Vector2) -> void:
	if index == _stick_finger:
		_stick_pos = pos
		_apply_stick()
	elif index == _look_finger:
		var p := Game.player
		if p != null and is_instance_valid(p) and p.cam_rig != null:
			p.cam_rig.add_look(relative)
		_look_last = pos

func _on_release(index: int) -> void:
	if _button_fingers.has(index):
		_release(String(_button_fingers[index].action))
		_button_fingers.erase(index)
		return
	if index == _stick_finger:
		_stick_finger = -1
		_clear_movement()
	elif index == _look_finger:
		_look_finger = -1

## Generous radius: a thumb that drifts should still mean "forward".
func _apply_stick() -> void:
	var radius := 92.0 * _scale()
	var v := (_stick_pos - _stick_origin) / radius
	if v.length() > 1.0:
		v = v.normalized()
	if v.length() < DEAD_ZONE:
		_clear_movement()
		return
	_axis("move_right", "move_left", v.x)
	_axis("move_back", "move_forward", v.y)

func _axis(positive: String, negative: String, value: float) -> void:
	if value > 0.0:
		Input.action_release(negative)
		Input.action_press(positive, minf(value, 1.0))
	else:
		Input.action_release(positive)
		Input.action_press(negative, minf(-value, 1.0))

func _clear_movement() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right"]:
		Input.action_release(a)

func _press(action: String) -> void:
	if action == "":
		return
	_pressed[action] = true
	Input.action_press(action, 1.0)

func _release(action: String) -> void:
	_pressed.erase(action)
	Input.action_release(action)

func release_all() -> void:
	_clear_movement()
	for a in _pressed.keys():
		Input.action_release(a)
	_pressed.clear()
	_stick_finger = -1
	_look_finger = -1
	_button_fingers.clear()

# --- drawing ------------------------------------------------------------------

func _draw() -> void:
	var alpha := float(Settings.get_value("touch_opacity"))
	var font := ThemeDB.fallback_font
	for b in _visible_buttons():
		var col: Color = b.color
		var held := false
		for f in _button_fingers.keys():
			if _button_fingers[f].id == b.id:
				held = true
		draw_circle(b.pos, float(b.r), Color(col.r * 0.2, col.g * 0.2, col.b * 0.25,
			alpha * (0.85 if held else 0.5)))
		draw_arc(b.pos, float(b.r), 0.0, TAU, 28, Color(col.r, col.g, col.b, alpha), 2.5, true)
		var text := String(b.label)
		var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 14)
		draw_string(font, b.pos + Vector2(-size.x * 0.5, 5), text,
			HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color(1, 1, 1, alpha + 0.25))
	if _stick_finger >= 0:
		var radius := 92.0 * _scale()
		draw_arc(_stick_origin, radius, 0.0, TAU, 32, Color(0.7, 0.9, 1.0, alpha * 0.8), 2.5, true)
		var knob := _stick_origin + (_stick_pos - _stick_origin).limit_length(radius)
		draw_circle(knob, 34.0 * _scale(), Color(0.6, 0.85, 1.0, alpha * 0.75))
	elif not bool(Settings.get_value("touch_stick_floating")):
		var home := Vector2(160.0 * _scale(), get_viewport_rect().size.y - 160.0 * _scale())
		draw_arc(home, 92.0 * _scale(), 0.0, TAU, 32, Color(0.7, 0.9, 1.0, alpha * 0.4), 2.0, true)
