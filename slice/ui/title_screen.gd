extends Control
## Title. Shows what a returning player has already done, because the statistics
## are the reason to come back.

signal new_run
signal continue_run
signal continue_exploring
signal open_settings
signal open_controls

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.035, 0.055)
	add_child(bg)
	var root := Kit.vbox(8)
	root.custom_minimum_size = Vector2(460 * Kit.scale(), 0)
	var name_label := Kit.label("EVOLVEBORN", 64, Palette.UI_ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	root.add_child(name_label)
	root.add_child(Kit.label("Begin as nothing. Eat until you are not.",
		15, Palette.UI_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	root.add_child(Kit.spacer(16))
	var first: Button = null
	if SaveMgr.has_run():
		var cont := Kit.button("CONTINUE", 19)
		cont.pressed.connect(func(): continue_run.emit())
		root.add_child(cont)
		first = cont
	var nb := Kit.button("NEW ORGANISM", 19)
	nb.pressed.connect(func(): new_run.emit())
	root.add_child(nb)
	if first == null:
		first = nb
	if bool(SaveMgr.data.get("completed", false)):
		var ce := Kit.button("CONTINUE EXPLORING", 17)
		ce.pressed.connect(func(): continue_exploring.emit())
		root.add_child(ce)
	var sb := Kit.button("SETTINGS", 17)
	sb.pressed.connect(func(): open_settings.emit())
	root.add_child(sb)
	var cb := Kit.button("CONTROLS", 17)
	cb.pressed.connect(func(): open_controls.emit())
	root.add_child(cb)
	root.add_child(Kit.spacer(10))
	if bool(SaveMgr.data.get("completed", false)):
		var best := float(SaveMgr.data.get("best_time", 0.0))
		root.add_child(Kit.label("BEST COMPLETION  %s" % Game.format_time(best),
			14, Palette.UI_ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	root.add_child(Kit.label("Keyboard, one-hand arrows, gamepad and touch all work. Change in Controls.",
		12, Palette.UI_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	add_child(Kit.center(root))
	first.call_deferred("grab_focus")
	# The title breathes so the screen never looks frozen while it waits.
	var t := create_tween().set_loops()
	t.tween_property(name_label, "modulate", Color(0.75, 1.0, 0.98), 2.4)
	t.tween_property(name_label, "modulate", Color(1, 1, 1), 2.4)
