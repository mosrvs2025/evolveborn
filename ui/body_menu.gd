extends Control
## BODY. Where the run is actually played: what fits in the Core, what that
## costs, and what falls out of the combination.
##
## Built as one navigable list rather than two columns, so arrow keys, a
## gamepad, a mouse and a thumb all work without special cases.

signal closed

var list: VBoxContainer
var detail: VBoxContainer
var capacity_label: Label
var capacity_bar: ProgressBar
var synergy_box: VBoxContainer
var build_row: HBoxContainer
var _rows: Array = []
var _selected := ""
var _allow_swap := true

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(Kit.dim(0.82))
	_build()
	refresh()

func open(allow_swap := true) -> void:
	_allow_swap = allow_swap
	visible = true
	refresh()
	if not _rows.is_empty():
		_rows[0].button.grab_focus()

func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, int(38 * Kit.scale()))
	add_child(margin)

	var root := Kit.vbox(12)
	margin.add_child(root)

	var header := Kit.hbox(16)
	header.add_child(Kit.title("BODY", 32))
	var cap_col := Kit.vbox(2)
	cap_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	capacity_label = Kit.label("CORE CAPACITY 0 / 8", 16, Palette.CORE, HORIZONTAL_ALIGNMENT_RIGHT)
	cap_col.add_child(capacity_label)
	capacity_bar = Kit.bar(Palette.CORE, 10)
	cap_col.add_child(capacity_bar)
	header.add_child(cap_col)
	root.add_child(header)

	var columns := Kit.hbox(16)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(columns)

	var left := Kit.vbox(6)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.25
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list = Kit.vbox(5)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	left.add_child(Kit.label("ADAPTATIONS", 14, Palette.UI_DIM))
	left.add_child(scroll)
	columns.add_child(left)

	var right := Kit.vbox(10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var detail_panel := Kit.panel()
	detail = Kit.vbox(6)
	detail_panel.add_child(detail)
	right.add_child(detail_panel)
	var syn_panel := Kit.panel(Color(0.06, 0.1, 0.12, 0.92), Color(0.4, 0.8, 0.75, 0.5))
	synergy_box = Kit.vbox(4)
	syn_panel.add_child(synergy_box)
	right.add_child(syn_panel)
	columns.add_child(right)

	var footer := Kit.vbox(8)
	footer.add_child(Kit.label("QUICK CONFIGURATIONS", 13, Palette.UI_DIM))
	build_row = Kit.hbox(8)
	footer.add_child(build_row)
	var close := Kit.button("CLOSE", 17)
	close.pressed.connect(func(): closed.emit())
	footer.add_child(close)
	root.add_child(footer)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("menu_body") or event.is_action_pressed("ui_cancel"):
		accept_event()
		closed.emit()

# --- content ------------------------------------------------------------------

func refresh() -> void:
	var lo := Game.loadout
	capacity_label.text = "CORE CAPACITY  %d / %d" % [lo.used_capacity(), lo.capacity()]
	capacity_bar.value = clampf(float(lo.used_capacity()) / float(maxi(lo.capacity(), 1)), 0.0, 1.0)
	_rebuild_list()
	_rebuild_synergies()
	_rebuild_builds()
	if _selected == "" and not lo.discovered.is_empty():
		_selected = lo.discovered[0]
	_show_detail(_selected)

func _rebuild_list() -> void:
	var focus_id := _selected
	for c in list.get_children():
		c.queue_free()
	_rows.clear()
	var lo := Game.loadout
	if lo.discovered.is_empty():
		list.add_child(Kit.label("NOTHING CATALOGUED YET.\nDEVOUR SOMETHING.", 15, Palette.UI_DIM))
		return
	var ordered: Array = lo.equipped.duplicate()
	for id in lo.discovered:
		if not ordered.has(id):
			ordered.append(id)
	for id in ordered:
		var t := DB.get_trait(String(id))
		if t == null:
			continue
		var equipped := lo.equipped.has(id)
		var row := Kit.hbox(8)
		var b := Kit.button("", 15)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.text = "%s   %s   ·   %d" % ["◆" if equipped else "◇", t.display_name.to_upper(), t.core_cost]
		b.add_theme_color_override("font_color", t.color if equipped else Palette.UI_DIM)
		if not equipped and not lo.can_equip(String(id)):
			b.add_theme_color_override("font_color", Color(0.45, 0.4, 0.4))
		b.pressed.connect(func(): _toggle(String(id)))
		b.focus_entered.connect(func(): _show_detail(String(id)))
		b.mouse_entered.connect(func(): _show_detail(String(id)))
		row.add_child(b)
		list.add_child(row)
		_rows.append({"id": String(id), "button": b})
		if String(id) == focus_id:
			b.call_deferred("grab_focus")

func _toggle(id: String) -> void:
	var lo := Game.loadout
	var was := lo.equipped.has(id)
	if was:
		lo.unequip(id)
		Audio.play("ui_back", -6.0)
	else:
		if not lo.equip(id):
			Audio.play("ui_deny", -4.0)
			Sig.toast.emit("CORE CAPACITY INSUFFICIENT", Palette.UI_WARN)
			return
		Audio.play("ui_select", -6.0)
	_selected = id
	Sig.loadout_changed.emit()
	Game.check_synergies()
	Game.write_save()
	refresh()

func _show_detail(id: String) -> void:
	_selected = id
	for c in detail.get_children():
		c.queue_free()
	var t := DB.get_trait(id)
	if t == null:
		detail.add_child(Kit.label("SELECT AN ADAPTATION", 15, Palette.UI_DIM))
		return
	var lo := Game.loadout
	detail.add_child(Kit.label(t.display_name.to_upper(), 22, t.color))
	detail.add_child(Kit.label("CORE COST %d" % t.core_cost, 13, Palette.UI_DIM))
	var desc := Kit.label(t.description, 14, Palette.UI_TEXT)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(0, 54 * Kit.scale())
	detail.add_child(desc)
	if t.active_ability != "":
		var a := DB.get_ability(t.active_ability)
		if a != null:
			detail.add_child(Kit.label("%s  ·  %s" % [String(t.ability_slot).to_upper(),
				a.display_name.to_upper()], 14, a.color))
			var ad := Kit.label(a.description, 13, Palette.UI_DIM)
			ad.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			detail.add_child(ad)
			# Say plainly when equipping this will take a control off something else.
			var current := String(lo.abilities().get(String(t.ability_slot), ""))
			if current != "" and current != t.active_ability and lo.equipped.has(id) == false:
				var cur_a := DB.get_ability(current)
				if cur_a != null:
					detail.add_child(Kit.label("REPLACES %s" % cur_a.display_name.to_upper(),
						12, Palette.UI_WARN))
	for k in t.stat_modifiers.keys():
		var v := float(t.stat_modifiers[k])
		detail.add_child(Kit.label(Corpse._describe_modifier(String(k), v), 13,
			Palette.UI_GOOD if v > 0.0 else Palette.UI_WARN))
	if t.echo_note != "":
		detail.add_child(Kit.label("> " + t.echo_note, 12, Palette.UI_ACCENT))

func _rebuild_synergies() -> void:
	for c in synergy_box.get_children():
		c.queue_free()
	synergy_box.add_child(Kit.label("SYNERGIES", 13, Palette.UI_DIM))
	var lo := Game.loadout
	var active := lo.active_synergies()
	for s in active:
		synergy_box.add_child(Kit.label("◆ " + String(s.display_name).to_upper(), 16, s.color))
		var d := Kit.label(String(s.description), 12, Palette.UI_TEXT)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		synergy_box.add_child(d)
	# Near-misses are the hook: one more organ and something new happens.
	var hints := 0
	for s in DB.SYNERGIES:
		if active.has(s):
			continue
		var have := 0
		var missing := ""
		for req in s.requires:
			if lo.equipped.has(req):
				have += 1
			else:
				missing = String(req)
		if have == s.requires.size() - 1 and lo.discovered.has(missing) and hints < 2:
			hints += 1
			var mt := DB.get_trait(missing)
			synergy_box.add_child(Kit.label("◇ ADD %s FOR SOMETHING" % mt.display_name.to_upper(),
				12, Palette.UI_DIM))
	if active.is_empty() and hints == 0:
		synergy_box.add_child(Kit.label("NONE ACTIVE. COMBINATIONS MATTER.", 12, Palette.UI_DIM))

func _rebuild_builds() -> void:
	for c in build_row.get_children():
		c.queue_free()
	var lo := Game.loadout
	for i in 3:
		var col := Kit.vbox(3)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var label_text := "SLOT %d" % (i + 1)
		if not lo.build_is_empty(i):
			label_text = "%s" % _build_summary(i)
		var load_b := Kit.button(label_text, 13)
		load_b.disabled = lo.build_is_empty(i) or not _allow_swap
		var idx := i
		load_b.pressed.connect(func():
			if Game.loadout.load_build(idx):
				Sig.loadout_changed.emit()
				Game.check_synergies()
				Game.write_save()
				Audio.play("ui_select", -6.0)
				refresh()
			else:
				Audio.play("ui_deny", -4.0)
				Sig.toast.emit("CONFIGURATION DOES NOT FIT", Palette.UI_WARN))
		col.add_child(load_b)
		var save_b := Kit.button("SAVE", 11)
		save_b.custom_minimum_size = Vector2(0, 28 * Kit.scale())
		save_b.pressed.connect(func():
			Game.loadout.save_build(idx)
			Game.write_save()
			Audio.play("ui_select", -8.0)
			refresh())
		col.add_child(save_b)
		build_row.add_child(col)

func _build_summary(slot: int) -> String:
	var b: Dictionary = Game.loadout.builds[slot]
	var names: Array[String] = []
	for id in b.get("traits", []):
		var t := DB.get_trait(String(id))
		if t != null:
			names.append(t.display_name.split(" ")[0].to_upper())
	return ", ".join(names) if not names.is_empty() else "SLOT %d" % (slot + 1)
