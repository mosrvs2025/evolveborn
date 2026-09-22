extends Control
## Pause. Everything the spec asks for, in the order a player reaches for it.

signal resume_requested
signal open_body
signal open_settings
signal open_controls
signal restart_checkpoint
signal quit_to_menu

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(Kit.dim(0.78))
	var box := Kit.vbox(10)
	box.custom_minimum_size = Vector2(360 * Kit.scale(), 0)
	box.add_child(Kit.title("PAUSED", 34))
	box.add_child(Kit.spacer(6))
	var entries := [
		["RESUME", func(): resume_requested.emit()],
		["BODY", func(): open_body.emit()],
		["SETTINGS", func(): open_settings.emit()],
		["CONTROLS", func(): open_controls.emit()],
		["RESTART AT CHECKPOINT", func(): restart_checkpoint.emit()],
		["QUIT TO MENU", func(): quit_to_menu.emit()],
	]
	var first: Button = null
	for e in entries:
		var b := Kit.button(String(e[0]), 18)
		b.pressed.connect(e[1])
		box.add_child(b)
		if first == null:
			first = b
	add_child(Kit.center(box))
	if first != null:
		first.call_deferred("grab_focus")

func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("menu_pause") or event.is_action_pressed("ui_cancel")):
		accept_event()
		resume_requested.emit()
