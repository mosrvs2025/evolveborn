extends Control
## The one irreversible choice in the run. Three shapes the same organism can
## take, described in what they change rather than in adjectives.

signal chosen(form_id: String)
signal cancelled

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(Kit.dim(0.9))
	var root := Kit.vbox(14)
	root.custom_minimum_size = Vector2(980 * Kit.scale(), 0)
	root.add_child(Kit.title("EVOLUTION AVAILABLE", 34))
	root.add_child(Kit.label("Sufficient essence. Choose what the Core becomes.",
		15, Palette.UI_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var cards := Kit.hbox(14)
	var first: Button = null
	for evo in DB.EVOLUTIONS:
		var card := Kit.panel(Color(0.06, 0.08, 0.11, 0.95), Color(evo.color).darkened(0.2))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(300 * Kit.scale(), 300 * Kit.scale())
		var v := Kit.vbox(6)
		v.add_child(Kit.label(String(evo.display_name).to_upper(), 21, evo.color))
		var tag := Kit.label(String(evo.tagline), 13, Palette.UI_TEXT)
		tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(tag)
		v.add_child(Kit.spacer(4))
		for k in evo.modifiers.keys():
			var val := float(evo.modifiers[k])
			if String(k) == "core_capacity":
				v.add_child(Kit.label("CORE CAPACITY +%d" % int(val), 13, Palette.CORE))
			else:
				v.add_child(Kit.label(Corpse._describe_modifier(String(k), val), 13,
					Palette.UI_GOOD if val > 0.0 else Palette.UI_WARN))
		v.add_child(Kit.spacer(6))
		var b := Kit.button("BECOME THIS", 16)
		var id := String(evo.id)
		b.pressed.connect(func(): chosen.emit(id))
		v.add_child(b)
		card.add_child(v)
		cards.add_child(card)
		if first == null:
			first = b
	root.add_child(cards)
	var later := Kit.button("DECIDE LATER", 15)
	later.pressed.connect(func(): cancelled.emit())
	root.add_child(later)
	add_child(Kit.center(root))
	if first != null:
		first.call_deferred("grab_focus")

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		accept_event()
		cancelled.emit()
