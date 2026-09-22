extends Control
## The playing HUD. Health, Essence, the three action slots, the contextual
## prompt, status, the Echo's log and the boss bar. Nothing here is decorative.

var health_bar: ProgressBar
var health_text: Label
var essence_bar: ProgressBar
var essence_text: Label
var capacity_label: Label
var status_row: HBoxContainer
var prompt_panel: PanelContainer
var prompt_label: Label
var devour_bar: ProgressBar
var slot_nodes := {}
var echo_box: VBoxContainer
var toast_label: Label
var boss_panel: PanelContainer
var boss_bar: ProgressBar
var boss_name: Label
var vignette: ColorRect

var _echo_queue: Array = []
var _echo_timer := 0.0
var _toast_timer := 0.0
var _low_pulse := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	Sig.player_health_changed.connect(_on_health)
	Sig.essence_changed.connect(_on_essence)
	Sig.capacity_changed.connect(_on_capacity)
	Sig.prompt_changed.connect(_on_prompt)
	Sig.echo_analysis.connect(_on_echo)
	Sig.toast.connect(_on_toast)
	Sig.loadout_changed.connect(_refresh_slots)
	Sig.input_device_changed.connect(func(_d): _refresh_slots())
	Sig.boss_phase_changed.connect(_on_boss_phase)
	Sig.boss_defeated.connect(func(): boss_panel.visible = false)
	Sig.settings_changed.connect(_refresh_slots)
	_refresh_slots()

func _build() -> void:
	vignette = ColorRect.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.color = Color(0.6, 0.1, 0.15, 0.0)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vignette)

	# --- vitals, top left
	var vitals := Kit.vbox(4)
	Kit.anchor_box(vitals, Vector2(0, 0), Vector2(24, 20), Vector2(320 * Kit.scale(), 132 * Kit.scale()))
	add_child(vitals)
	var hp_row := Kit.hbox(8)
	var hp_tag := Kit.label("VITALITY", 12, Palette.UI_DIM)
	hp_tag.custom_minimum_size = Vector2(88 * Kit.scale(), 0)
	hp_row.add_child(hp_tag)
	health_text = Kit.label("100 / 100", 13, Palette.UI_TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	health_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_row.add_child(health_text)
	vitals.add_child(hp_row)
	health_bar = Kit.bar(Palette.HEALTH, 16)
	health_bar.custom_minimum_size.x = 300 * Kit.scale()
	vitals.add_child(health_bar)
	var es_row := Kit.hbox(8)
	var es_tag := Kit.label("ESSENCE", 12, Palette.UI_DIM)
	es_tag.custom_minimum_size = Vector2(88 * Kit.scale(), 0)
	es_row.add_child(es_tag)
	essence_text = Kit.label("0 / %d" % DB.ESSENCE_TO_EVOLVE, 13, Palette.ESSENCE,
		HORIZONTAL_ALIGNMENT_RIGHT)
	essence_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	es_row.add_child(essence_text)
	vitals.add_child(es_row)
	essence_bar = Kit.bar(Palette.ESSENCE, 9)
	essence_bar.custom_minimum_size.x = 300 * Kit.scale()
	essence_bar.value = 0.0
	vitals.add_child(essence_bar)
	status_row = Kit.hbox(6)
	vitals.add_child(status_row)

	# --- core capacity, top right
	capacity_label = Kit.label("CORE  0 / 8", 15, Palette.CORE, HORIZONTAL_ALIGNMENT_RIGHT)
	Kit.anchor_box(capacity_label, Vector2(1, 0), Vector2(-224 * Kit.scale(), 22),
		Vector2(200 * Kit.scale(), 28 * Kit.scale()))
	add_child(capacity_label)

	# --- boss bar, top centre
	boss_panel = Kit.panel(Color(0.08, 0.04, 0.06, 0.88), Color(0.8, 0.3, 0.4, 0.7))
	Kit.anchor_box(boss_panel, Vector2(0.5, 0), Vector2(-300 * Kit.scale(), 16),
		Vector2(600 * Kit.scale(), 76 * Kit.scale()))
	boss_panel.visible = false
	var bv := Kit.vbox(4)
	boss_name = Kit.label("THE ROOT DEVOURER", 16, Color(1.0, 0.6, 0.65), HORIZONTAL_ALIGNMENT_CENTER)
	bv.add_child(boss_name)
	boss_bar = Kit.bar(Color(0.9, 0.3, 0.38), 14)
	bv.add_child(boss_bar)
	boss_panel.add_child(bv)
	add_child(boss_panel)

	# --- echo log, left
	echo_box = Kit.vbox(2)
	Kit.anchor_box(echo_box, Vector2(0, 0.5), Vector2(26, -70 * Kit.scale()),
		Vector2(440 * Kit.scale(), 150 * Kit.scale()))
	add_child(echo_box)

	# --- toast, upper centre
	toast_label = Kit.label("", 26, Palette.UI_ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	Kit.anchor_box(toast_label, Vector2(0.5, 0), Vector2(-400 * Kit.scale(), 104 * Kit.scale()),
		Vector2(800 * Kit.scale(), 40 * Kit.scale()))
	toast_label.modulate.a = 0.0
	add_child(toast_label)

	# --- prompt + devour meter, lower centre
	var prompt_wrap := Kit.vbox(4)
	Kit.anchor_box(prompt_wrap, Vector2(0.5, 1), Vector2(-170 * Kit.scale(), -186 * Kit.scale()),
		Vector2(340 * Kit.scale(), 72 * Kit.scale()))
	add_child(prompt_wrap)
	prompt_panel = Kit.panel(Color(0.05, 0.08, 0.1, 0.9), Palette.UI_ACCENT)
	prompt_label = Kit.label("", 18, Palette.UI_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	prompt_panel.add_child(prompt_label)
	prompt_panel.visible = false
	prompt_wrap.add_child(prompt_panel)
	devour_bar = Kit.bar(Palette.CORE, 8)
	devour_bar.value = 0.0
	devour_bar.visible = false
	prompt_wrap.add_child(devour_bar)

	# --- action slots, bottom centre
	var slots := Kit.hbox(10)
	Kit.anchor_box(slots, Vector2(0.5, 1), Vector2(-282 * Kit.scale(), -102 * Kit.scale()),
		Vector2(564 * Kit.scale(), 74 * Kit.scale()))
	add_child(slots)
	for key in ["primary", "secondary", "mobility"]:
		var card := Kit.panel(Color(0.06, 0.09, 0.12, 0.82), Color(0.3, 0.42, 0.5, 0.6))
		card.custom_minimum_size = Vector2(174 * Kit.scale(), 62 * Kit.scale())
		var v := Kit.vbox(1)
		var top := Kit.hbox(6)
		var tag := Kit.label(key.to_upper(), 10, Palette.UI_DIM)
		top.add_child(tag)
		var keycap := Kit.label("", 10, Palette.UI_ACCENT, HORIZONTAL_ALIGNMENT_RIGHT)
		keycap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(keycap)
		v.add_child(top)
		var name_label := Kit.label("-", 15, Palette.UI_TEXT)
		v.add_child(name_label)
		var cd := Kit.bar(Palette.UI_ACCENT, 5)
		cd.value = 0.0
		v.add_child(cd)
		card.add_child(v)
		slots.add_child(card)
		slot_nodes[key] = {"card": card, "name": name_label, "key": keycap, "cd": cd}

func _process(delta: float) -> void:
	var p := Game.player
	if p != null and is_instance_valid(p) and p.get("sys") != null:
		for key in slot_nodes.keys():
			var id := String(p.slots.get(key, ""))
			var bar: ProgressBar = slot_nodes[key].cd
			bar.value = p.sys.cooldown_fraction(id) if id != "" else 0.0
			slot_nodes[key].card.modulate.a = 1.0 if id != "" else 0.4
		devour_bar.visible = p.devour_progress() > 0.001
		devour_bar.value = p.devour_progress()
		_update_status(p)
		_update_vignette(p, delta)
	_tick_echo(delta)
	_tick_toast(delta)
	_update_boss()

func _update_status(p: Node) -> void:
	var names: Array = p.status.active_names()
	if status_row.get_child_count() != names.size():
		for c in status_row.get_children():
			c.queue_free()
		for n in names:
			var col: Color = Palette.STATUS.get(n, Color.WHITE)
			var glyph: String = Palette.STATUS_GLYPH.get(n, "*")
			var chip := Kit.panel(Color(col.r * 0.2, col.g * 0.2, col.b * 0.2, 0.85), col)
			var lab := Kit.label("%s %s" % [glyph, String(n).to_upper()], 11, col)
			chip.add_child(lab)
			status_row.add_child(chip)

func _update_vignette(p: Node, delta: float) -> void:
	var frac: float = p.health / maxf(p.max_health, 1.0)
	if frac < 0.3:
		_low_pulse += delta * 3.4
		var a := (0.3 - frac) / 0.3 * (0.18 + sin(_low_pulse) * 0.08)
		vignette.color.a = clampf(a, 0.0, 0.32)
	else:
		vignette.color.a = lerpf(vignette.color.a, 0.0, clampf(delta * 5.0, 0.0, 1.0))

func _update_boss() -> void:
	var bosses := get_tree().get_nodes_in_group("boss")
	if bosses.is_empty():
		boss_panel.visible = false
		return
	var b = bosses[0]
	if not is_instance_valid(b) or b.dead or not b._intro_done:
		boss_panel.visible = false
		return
	boss_panel.visible = true
	boss_bar.value = b.health_fraction()
	boss_name.text = "THE ROOT DEVOURER   ·   PHASE %d" % b.phase

# --- signal handlers ----------------------------------------------------------

func _on_health(current: float, maximum: float) -> void:
	health_bar.value = clampf(current / maxf(maximum, 1.0), 0.0, 1.0)
	health_text.text = "%d / %d" % [int(ceil(current)), int(round(maximum))]

func _on_essence(current: int, needed: int) -> void:
	if Game.loadout.evolution != "":
		essence_text.text = "%d" % current
		essence_bar.value = 1.0
		return
	essence_bar.value = clampf(float(current) / float(maxi(needed, 1)), 0.0, 1.0)
	if current >= needed:
		essence_text.text = "READY - FIND A MEMORY POOL"
	else:
		essence_text.text = "%d / %d" % [current, needed]

func _on_capacity(used: int, total: int) -> void:
	capacity_label.text = "CORE  %d / %d" % [used, total]
	capacity_label.add_theme_color_override("font_color",
		Palette.UI_WARN if used >= total else Palette.CORE)

func _on_prompt(text: String, action: String) -> void:
	if text == "":
		prompt_panel.visible = false
		return
	prompt_panel.visible = true
	var glyph := InputMgr.prompt_for(action)
	prompt_label.text = ("HOLD  %s" % text) if glyph == "" else "[%s]  %s" % [glyph, text]

func _on_echo(lines: Array) -> void:
	for l in lines:
		_echo_queue.append(String(l))

func _tick_echo(delta: float) -> void:
	_echo_timer -= delta
	if _echo_timer <= 0.0 and not _echo_queue.is_empty():
		_echo_timer = 0.55
		_push_echo(String(_echo_queue.pop_front()))

func _push_echo(text: String) -> void:
	if not bool(Settings.get_value("subtitles")):
		return
	var l := Kit.label("> " + text, 15, Palette.UI_ACCENT)
	echo_box.add_child(l)
	Audio.play("echo", -12.0, randf_range(0.98, 1.04))
	var t := create_tween()
	t.tween_interval(4.2)
	t.tween_property(l, "modulate:a", 0.0, 0.8)
	t.tween_callback(l.queue_free)
	while echo_box.get_child_count() > 5:
		echo_box.get_child(0).queue_free()
		await get_tree().process_frame

func _on_toast(text: String, color: Color) -> void:
	toast_label.text = text
	toast_label.add_theme_color_override("font_color", color)
	toast_label.modulate.a = 1.0
	_toast_timer = 2.8

func _tick_toast(delta: float) -> void:
	if _toast_timer <= 0.0:
		return
	_toast_timer -= delta
	if _toast_timer < 0.9:
		toast_label.modulate.a = clampf(_toast_timer / 0.9, 0.0, 1.0)

func _on_boss_phase(_phase: int) -> void:
	_update_boss()

func _refresh_slots() -> void:
	var lo := Game.loadout
	var abilities := lo.abilities()
	var action_for := {"primary": "act_primary", "secondary": "act_secondary", "mobility": "act_mobility"}
	for key in slot_nodes.keys():
		var id := String(abilities.get(key, ""))
		var a := DB.get_ability(id)
		slot_nodes[key].name.text = a.display_name if a != null else "—"
		var glyph := InputMgr.prompt_for(String(action_for[key]))
		slot_nodes[key].key.text = glyph
		if a != null:
			slot_nodes[key].name.add_theme_color_override("font_color", a.color)
	_on_capacity(lo.used_capacity(), lo.capacity())
