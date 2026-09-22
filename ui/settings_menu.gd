extends Control
## Accessibility and comfort. Every one of these is read live by the systems
## that use it, so a change takes effect without leaving the menu.

signal closed

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(Kit.dim(0.85))
	_build()

func _scale_value() -> float:
	return minf(Settings.render_scale(), 1.0)

func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, int(40 * Kit.scale()))
	add_child(margin)
	var root := Kit.vbox(10)
	margin.add_child(root)
	root.add_child(Kit.title("SETTINGS", 30))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var body := Kit.vbox(6)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	root.add_child(scroll)

	body.add_child(Kit.label("CAMERA", 14, Palette.UI_ACCENT))
	body.add_child(Kit.slider_row("Sensitivity", Settings.get_value("camera_sensitivity"), 0.2, 2.5, 0.05,
		func(v): Settings.set_value("camera_sensitivity", v),
		func(v: float) -> String: return "%.2fx" % v))
	body.add_child(Kit.slider_row("Distance", Settings.get_value("camera_distance"), 0.7, 1.6, 0.05,
		func(v): Settings.set_value("camera_distance", v),
		func(v: float) -> String: return "%.2fx" % v))
	body.add_child(Kit.toggle_row("Invert horizontal", Settings.get_value("camera_invert_x"),
		func(v): Settings.set_value("camera_invert_x", v)))
	body.add_child(Kit.toggle_row("Invert vertical", Settings.get_value("camera_invert_y"),
		func(v): Settings.set_value("camera_invert_y", v)))
	body.add_child(Kit.toggle_row("Smart Camera", Settings.get_value("smart_camera"),
		func(v): Settings.set_value("smart_camera", v)))

	body.add_child(Kit.spacer(6))
	body.add_child(Kit.label("ASSISTANCE", 14, Palette.UI_ACCENT))
	body.add_child(Kit.slider_row("Target assist", Settings.get_value("target_assist"), 0.0, 1.0, 0.05,
		func(v): Settings.set_value("target_assist", v)))
	body.add_child(Kit.toggle_row("Hold to Devour", Settings.get_value("hold_to_devour"),
		func(v): Settings.set_value("hold_to_devour", v)))

	body.add_child(Kit.spacer(6))
	body.add_child(Kit.label("MOTION AND READABILITY", 14, Palette.UI_ACCENT))
	body.add_child(Kit.slider_row("Screen shake", Settings.get_value("screen_shake"), 0.0, 1.5, 0.05,
		func(v): Settings.set_value("screen_shake", v)))
	body.add_child(Kit.slider_row("Motion intensity", Settings.get_value("motion_intensity"), 0.0, 1.5, 0.05,
		func(v): Settings.set_value("motion_intensity", v)))
	body.add_child(Kit.toggle_row("Hit stop", Settings.get_value("hit_stop"),
		func(v): Settings.set_value("hit_stop", v)))
	body.add_child(Kit.toggle_row("Damage numbers", Settings.get_value("damage_numbers"),
		func(v): Settings.set_value("damage_numbers", v)))
	body.add_child(Kit.toggle_row("Echo subtitles", Settings.get_value("subtitles"),
		func(v): Settings.set_value("subtitles", v)))
	body.add_child(Kit.slider_row("UI scale", Settings.get_value("ui_scale"), 0.8, 1.6, 0.05,
		func(v): Settings.set_value("ui_scale", v),
		func(v: float) -> String: return "%.2fx" % v))

	body.add_child(Kit.spacer(6))
	body.add_child(Kit.label("AUDIO", 14, Palette.UI_ACCENT))
	body.add_child(Kit.slider_row("Master", Settings.get_value("volume_master"), 0.0, 1.0, 0.05,
		func(v): Settings.set_value("volume_master", v)))
	body.add_child(Kit.slider_row("Music", Settings.get_value("volume_music"), 0.0, 1.0, 0.05,
		func(v): Settings.set_value("volume_music", v)))
	body.add_child(Kit.slider_row("Effects", Settings.get_value("volume_sfx"), 0.0, 1.0, 0.05,
		func(v): Settings.set_value("volume_sfx", v)))

	body.add_child(Kit.spacer(6))
	body.add_child(Kit.label("PERFORMANCE", 14, Palette.UI_ACCENT))
	body.add_child(Kit.option_row("Quality", ["auto", "low", "medium", "high"],
		String(Settings.get_value("quality")),
		func(v): Settings.set_value("quality", v)))
	body.add_child(Kit.slider_row("Render scale", _scale_value(), 0.5, 1.0, 0.05,
		func(v): Settings.set_value("render_scale", v),
		func(v: float) -> String: return "%d%%" % int(round(v * 100.0))))
	body.add_child(Kit.label("Lower the render scale first if the frame rate drags; the interface stays sharp.", 12, Palette.UI_DIM))
	body.add_child(Kit.label("Quality applies to regions loaded from here on.", 12, Palette.UI_DIM))

	body.add_child(Kit.spacer(6))
	body.add_child(Kit.label("TOUCH", 14, Palette.UI_ACCENT))
	body.add_child(Kit.slider_row("Control size", Settings.get_value("touch_size"), 0.7, 1.6, 0.05,
		func(v): Settings.set_value("touch_size", v),
		func(v: float) -> String: return "%.2fx" % v))
	body.add_child(Kit.slider_row("Control opacity", Settings.get_value("touch_opacity"), 0.15, 1.0, 0.05,
		func(v): Settings.set_value("touch_opacity", v)))
	body.add_child(Kit.toggle_row("Floating joystick", Settings.get_value("touch_stick_floating"),
		func(v): Settings.set_value("touch_stick_floating", v)))

	var footer := Kit.hbox(10)
	var reset := Kit.button("RESET DEFAULTS", 15)
	reset.pressed.connect(func():
		Settings.reset_to_defaults()
		for c in margin.get_children():
			c.queue_free()
		_build())
	footer.add_child(reset)
	var close := Kit.button("BACK", 16)
	close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close.pressed.connect(func(): closed.emit())
	footer.add_child(close)
	root.add_child(footer)
	close.call_deferred("grab_focus")

func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu_pause")):
		accept_event()
		closed.emit()
