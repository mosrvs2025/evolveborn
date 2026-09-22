extends Control
## Control scheme and rebinding. The presets are whole schemes; the list below
## rebinds one action at a time and survives across runs.

signal closed

var _listening := ""
var _rows := {}
var _list: VBoxContainer
var _hint: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(Kit.dim(0.85))
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, int(40 * Kit.scale()))
	add_child(margin)
	var root := Kit.vbox(10)
	margin.add_child(root)
	root.add_child(Kit.title("CONTROLS", 30))

	var preset_row := Kit.hbox(8)
	preset_row.add_child(Kit.label("SCHEME", 14, Palette.UI_DIM))
	for p in [["blended", "EVERYTHING"], ["standard", "STANDARD"], ["one_hand", "ONE HAND"],
			["controller", "CONTROLLER"]]:
		var b := Kit.button(String(p[1]), 13)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func():
			InputMgr.set_preset(String(p[0]))
			Audio.play("ui_select", -6.0)
			_refresh())
		preset_row.add_child(b)
	root.add_child(preset_row)
	root.add_child(Kit.label(
		"EVERYTHING keeps WASD, the arrow cluster and a gamepad live at the same time. " +
		"Arrows move; , and / turn the camera; 0 strikes; Enter is the secondary; " +
		"Space bursts; Ctrl devours; . recentres.", 12, Palette.UI_DIM))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list = Kit.vbox(4)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	root.add_child(scroll)

	_hint = Kit.label("", 14, Palette.UI_WARN, HORIZONTAL_ALIGNMENT_CENTER)
	root.add_child(_hint)

	var footer := Kit.hbox(10)
	var reset := Kit.button("RESET BINDINGS", 15)
	reset.pressed.connect(func():
		InputMgr.set_preset(InputMgr.preset)
		_refresh())
	footer.add_child(reset)
	var close := Kit.button("BACK", 16)
	close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close.pressed.connect(func(): closed.emit())
	footer.add_child(close)
	root.add_child(footer)
	_refresh()
	close.call_deferred("grab_focus")

func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	_rows.clear()
	for action in InputMgr.GAMEPLAY_ACTIONS:
		var row := Kit.hbox(10)
		var name_label := Kit.label(String(InputMgr.ACTION_LABELS.get(action, action)), 14, Palette.UI_TEXT)
		name_label.custom_minimum_size = Vector2(220 * Kit.scale(), 0)
		row.add_child(name_label)
		var current := Kit.label(InputMgr.bindings_text(action), 13, Palette.UI_DIM)
		current.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(current)
		var b := Kit.button("REBIND", 12)
		b.custom_minimum_size = Vector2(120 * Kit.scale(), 30 * Kit.scale())
		b.pressed.connect(func(): _begin_listen(action))
		row.add_child(b)
		_list.add_child(row)
		_rows[action] = current

func _begin_listen(action: String) -> void:
	_listening = action
	_hint.text = "PRESS A KEY, BUTTON OR STICK FOR: %s     (ESC TO CANCEL)" % \
		String(InputMgr.ACTION_LABELS.get(action, action)).to_upper()

func _input(event: InputEvent) -> void:
	if _listening == "":
		return
	var usable := event is InputEventKey or event is InputEventMouseButton \
		or event is InputEventJoypadButton or event is InputEventJoypadMotion
	if not usable or not event.is_pressed():
		return
	if event is InputEventJoypadMotion and absf(event.axis_value) < 0.65:
		return
	if event is InputEventKey and event.physical_keycode == KEY_ESCAPE:
		_listening = ""
		_hint.text = ""
		accept_event()
		return
	if InputMgr.rebind(_listening, event):
		Audio.play("ui_select", -6.0)
	_listening = ""
	_hint.text = ""
	accept_event()
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if _listening != "":
		return
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu_pause")):
		accept_event()
		closed.emit()
