extends RefCounted
class_name Kit
## Shared UI construction. One place decides what a panel, a button and a bar
## look like, so every screen matches and UI scale only has to be applied once.

static func scale() -> float:
	return float(Settings.get_value("ui_scale"))

static func fs(size: int) -> int:
	return int(round(float(size) * scale()))

static func panel_style(bg := Palette.UI_PANEL, border := Palette.UI_LINE, width := 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(6)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 14
	s.content_margin_bottom = 14
	return s

static func panel(bg := Palette.UI_PANEL, border := Palette.UI_LINE) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_style(bg, border))
	return p

static func label(text: String, size := 16, color := Palette.UI_TEXT,
		align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs(size))
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	return l

static func title(text: String, size := 34, color := Palette.UI_ACCENT) -> Label:
	var l := label(text, size, color)
	l.add_theme_constant_override("outline_size", 0)
	return l

static func button(text: String, size := 18) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", fs(size))
	b.add_theme_color_override("font_color", Palette.UI_TEXT)
	b.add_theme_color_override("font_hover_color", Palette.UI_ACCENT)
	b.add_theme_color_override("font_focus_color", Palette.UI_ACCENT)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	var normal := panel_style(Color(0.10, 0.13, 0.17, 0.85), Color(0.28, 0.4, 0.5, 0.6), 1)
	var hover := panel_style(Color(0.15, 0.22, 0.27, 0.95), Palette.UI_ACCENT, 2)
	var focus := panel_style(Color(0.13, 0.2, 0.26, 0.95), Palette.UI_ACCENT, 2)
	var pressed := panel_style(Color(0.2, 0.3, 0.34, 1.0), Color.WHITE, 2)
	for pair in [["normal", normal], ["hover", hover], ["focus", focus], ["pressed", pressed],
			["disabled", panel_style(Color(0.08, 0.09, 0.1, 0.6), Color(0.2, 0.22, 0.25, 0.5), 1)]]:
		b.add_theme_stylebox_override(String(pair[0]), pair[1])
	b.custom_minimum_size = Vector2(0, 40 * scale())
	return b

## Horizontal meter. Carries a label as well as a colour, because critical
## information must never be colour alone.
static func bar(color: Color, height := 14) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(0, height * scale())
	pb.max_value = 1.0
	pb.value = 1.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.07, 0.09, 0.85)
	bg.set_corner_radius_all(3)
	bg.border_color = Color(0.3, 0.38, 0.45, 0.5)
	bg.set_border_width_all(1)
	var fg := StyleBoxFlat.new()
	fg.bg_color = color
	fg.set_corner_radius_all(3)
	pb.add_theme_stylebox_override("background", bg)
	pb.add_theme_stylebox_override("fill", fg)
	return pb

static func spacer(height := 10) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height * scale())
	return c

static func vbox(separation := 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(separation * scale()))
	return v

static func hbox(separation := 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", int(separation * scale()))
	return h

static func center(control: Control) -> CenterContainer:
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.add_child(control)
	return c

static func dim(alpha := 0.72) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0.02, 0.03, 0.05, alpha)
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_STOP
	return r

## A slider row with its value shown as text beside it.
static func slider_row(text: String, value: float, min_v: float, max_v: float, step: float,
		on_change: Callable, fmt_fn := Callable()) -> HBoxContainer:
	var formatter := fmt_fn
	if not formatter.is_valid():
		formatter = func(v: float) -> String: return "%d%%" % int(round(v * 100.0))
	var row := hbox(12)
	var name_label := label(text, 15, Palette.UI_DIM)
	name_label.custom_minimum_size = Vector2(230 * scale(), 0)
	row.add_child(name_label)
	var s := HSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(230 * scale(), 26 * scale())
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.focus_mode = Control.FOCUS_ALL
	row.add_child(s)
	var val := label(String(formatter.call(value)), 15, Palette.UI_TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	val.custom_minimum_size = Vector2(80 * scale(), 0)
	row.add_child(val)
	s.value_changed.connect(func(v: float):
		val.text = String(formatter.call(v))
		on_change.call(v))
	return row



static func toggle_row(text: String, value: bool, on_change: Callable) -> HBoxContainer:
	var row := hbox(12)
	var name_label := label(text, 15, Palette.UI_DIM)
	name_label.custom_minimum_size = Vector2(230 * scale(), 0)
	row.add_child(name_label)
	var b := button("ON" if value else "OFF", 15)
	b.custom_minimum_size = Vector2(110 * scale(), 34 * scale())
	b.pressed.connect(func():
		var nv := b.text == "OFF"
		b.text = "ON" if nv else "OFF"
		on_change.call(nv))
	row.add_child(b)
	return row

static func option_row(text: String, options: Array, current: String, on_change: Callable) -> HBoxContainer:
	var row := hbox(12)
	var name_label := label(text, 15, Palette.UI_DIM)
	name_label.custom_minimum_size = Vector2(230 * scale(), 0)
	row.add_child(name_label)
	var idx := maxi(0, options.find(current))
	var b := button(String(options[idx]).to_upper(), 15)
	b.custom_minimum_size = Vector2(160 * scale(), 34 * scale())
	b.pressed.connect(func():
		idx = (idx + 1) % options.size()
		b.text = String(options[idx]).to_upper()
		on_change.call(String(options[idx])))
	row.add_child(b)
	return row

## Places a control at an anchor point with an explicit size, in one call.
## Anchor is a 0..1 pair: (0,0) top-left, (1,0) top-right, (0.5,1) bottom-centre.
## Offsets are pixels from that anchor, so a right-anchored panel takes a
## negative x. Used for the HUD, where every element has a fixed home.
static func anchor_box(c: Control, anchor: Vector2, offset: Vector2, box: Vector2) -> void:
	c.anchor_left = anchor.x
	c.anchor_right = anchor.x
	c.anchor_top = anchor.y
	c.anchor_bottom = anchor.y
	c.offset_left = offset.x
	c.offset_right = offset.x + box.x
	c.offset_top = offset.y
	c.offset_bottom = offset.y + box.y
	c.grow_horizontal = Control.GROW_DIRECTION_END
	c.grow_vertical = Control.GROW_DIRECTION_END
