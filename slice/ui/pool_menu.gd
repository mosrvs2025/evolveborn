extends Control
## What a Memory Pool offers. Evolution only appears here, which is what makes
## reaching the next pool worth something.

signal closed
signal open_body
signal open_evolution

var _evolve_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(Kit.dim(0.6))
	var box := Kit.vbox(10)
	box.custom_minimum_size = Vector2(420 * Kit.scale(), 0)
	box.add_child(Kit.title("MEMORY POOL", 30))
	box.add_child(Kit.label("Restored. This is where the Hollow will put you back.",
		14, Palette.UI_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(Kit.spacer(6))
	_evolve_button = Kit.button("EVOLVE", 19)
	_evolve_button.pressed.connect(func(): open_evolution.emit())
	box.add_child(_evolve_button)
	var body_b := Kit.button("BODY", 18)
	body_b.pressed.connect(func(): open_body.emit())
	box.add_child(body_b)
	var leave := Kit.button("CONTINUE", 18)
	leave.pressed.connect(func(): closed.emit())
	box.add_child(leave)
	add_child(Kit.center(box))
	refresh()
	body_b.call_deferred("grab_focus")

func refresh() -> void:
	var can_evolve: bool = Game.evolution_pending and Game.loadout.evolution == ""
	_evolve_button.visible = can_evolve
	if can_evolve:
		_evolve_button.add_theme_color_override("font_color", Palette.UI_ACCENT)
		_evolve_button.call_deferred("grab_focus")

func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu_pause")):
		accept_event()
		closed.emit()
